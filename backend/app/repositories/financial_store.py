"""Database records shared by financial repositories. No live memory fallback."""
import json
import sqlite3
from collections.abc import MutableMapping
from contextlib import contextmanager
from contextvars import ContextVar
from pathlib import Path
from pydantic import TypeAdapter
from app.core.config import get_settings
from app.core.exceptions import ApiError, ErrorCode

_connection = ContextVar("financial_connection", default=None)


def database_url():
    url = get_settings().financial_database_url
    if not url:
        if not get_settings().is_production:
            return "sqlite:///data/financial_records.db"
        raise ApiError(503, ErrorCode.CONFIGURATION_ERROR, "FINANCIAL_DATABASE_URL is required for persistent financial operations.")
    if get_settings().is_production and not url.startswith(("postgresql://", "postgres://")):
        raise ApiError(503, ErrorCode.CONFIGURATION_ERROR, "Production financial storage requires PostgreSQL.")
    return url


@contextmanager
def connection():
    existing = _connection.get()
    if existing is not None:
        yield existing
        return
    url = database_url()
    if url.startswith("sqlite:///"):
        path = url[len("sqlite:///"):]
        db_path = Path(path)
        if not db_path.is_absolute():
            backend_root = Path(__file__).resolve().parent.parent.parent
            db_path = backend_root / path
        db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(db_path), timeout=30)
        conn.execute("CREATE TABLE IF NOT EXISTS financial_records (namespace TEXT NOT NULL, key TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(namespace, key))")
        conn.commit()
        conn.execute("BEGIN IMMEDIATE")
    else:
        import psycopg
        conn = psycopg.connect(url, connect_timeout=10, prepare_threshold=None)
        # One shared lock also serializes operations involving different accounts.
        conn.execute("SELECT pg_advisory_xact_lock(867530964)")
    token = _connection.set(conn)
    try:
        yield conn
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        _connection.reset(token)
        conn.close()


def execute(conn, statement, args=()):
    if isinstance(conn, sqlite3.Connection):
        statement = statement.replace("%s", "?")
    return conn.execute(statement, args)


class RecordMap(MutableMapping):
    def __init__(self, namespace, model):
        self.namespace = namespace
        self.adapter = TypeAdapter(model)

    def __getitem__(self, key):
        with connection() as conn:
            row = execute(conn, "SELECT payload FROM financial_records WHERE namespace=%s AND key=%s", (self.namespace, key)).fetchone()
        if row is None:
            raise KeyError(key)
        return self.adapter.validate_json(row[0])

    def __setitem__(self, key, value):
        payload = self.adapter.dump_json(value).decode()
        with connection() as conn:
            execute(conn, "INSERT INTO financial_records(namespace,key,payload) VALUES (%s,%s,%s) ON CONFLICT(namespace,key) DO UPDATE SET payload=excluded.payload", (self.namespace, key, payload))

    def __delitem__(self, key):
        with connection() as conn:
            cursor = execute(conn, "DELETE FROM financial_records WHERE namespace=%s AND key=%s", (self.namespace, key))
            if not cursor.rowcount:
                raise KeyError(key)

    def __iter__(self):
        with connection() as conn:
            rows = execute(conn, "SELECT key FROM financial_records WHERE namespace=%s ORDER BY key", (self.namespace,)).fetchall()
        return iter(row[0] for row in rows)

    def __len__(self):
        with connection() as conn:
            return execute(conn, "SELECT count(*) FROM financial_records WHERE namespace=%s", (self.namespace,)).fetchone()[0]

    def values(self):
        with connection() as conn:
            rows = execute(conn, "SELECT payload FROM financial_records WHERE namespace=%s ORDER BY key", (self.namespace,)).fetchall()
        return [self.adapter.validate_json(row[0]) for row in rows]


class RecordList:
    def __init__(self, namespace, model):
        self.records = RecordMap(namespace, model)
    def append(self, value):
        from uuid import uuid4
        self.records[str(uuid4())] = value
    def __iter__(self):
        return iter(self.records.values())


class FinancialState:
    """Routes and services read the same store as the live repositories."""
    def __getattr__(self, name):
        from app.repositories.state import state
        settings = get_settings()
        if not settings.financial_database_url and not (settings.supabase_url and settings.supabase_service_role_key) and not settings.is_production:
            return getattr(state, name)
        from app.schemas.purchase import EnergyPurchase
        from app.schemas.escrow import EscrowAgreement, Dispute
        from app.schemas.wallet import WalletTransaction, LedgerEntry, EscrowAccount, Settlement, Deposit, Withdrawal, Refund, TransactionAudit
        models = dict(purchases=EnergyPurchase, escrows=EscrowAgreement, disputes=Dispute,
            transactions=list[WalletTransaction], ledger_entries=LedgerEntry, ledger_by_transaction=list[str],
            escrow_accounts=EscrowAccount, settlements=Settlement, deposits=Deposit, withdrawals=Withdrawal, refunds=Refund,
            default_cases=dict)
        if name == "transaction_audit":
            return RecordList(name, TransactionAudit)
        if name in models:
            return RecordMap(name, models[name])
        return getattr(state, name)


financial_state = FinancialState()
