from app.core.exceptions import ApiError, ErrorCode
from app.repositories.state import state
from app.schemas.common import new_id, now_utc
from app.schemas.wallet import LedgerEntry, LedgerTransaction


class LedgerService:
    def record(
        self,
        *,
        transaction_id: str,
        entries: list[LedgerEntry],
    ) -> LedgerTransaction:
        if len(entries) < 2:
            raise ApiError(409, ErrorCode.VALIDATION_FAILED, "Ledger transaction requires at least two entries.")
        total_debit = sum(item.debitPaise for item in entries)
        total_credit = sum(item.creditPaise for item in entries)
        if total_debit <= 0 or total_debit != total_credit:
            raise ApiError(409, ErrorCode.VALIDATION_FAILED, "Ledger debits and credits must balance.")
        if transaction_id in state.ledger_by_transaction:
            return self.transaction(transaction_id)

        ids: list[str] = []
        for entry in entries:
            stored = entry.model_copy(
                update={
                    "entryId": entry.entryId or new_id("LED"),
                    "transactionId": transaction_id,
                    "createdAt": now_utc(),
                },
            )
            state.ledger_entries[stored.entryId] = stored
            ids.append(stored.entryId)
        state.ledger_by_transaction[transaction_id] = ids
        return self.transaction(transaction_id)

    def transaction(self, transaction_id: str) -> LedgerTransaction:
        ids = state.ledger_by_transaction.get(transaction_id)
        if not ids:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Ledger transaction not found.")
        entries = [state.ledger_entries[entry_id] for entry_id in ids]
        return LedgerTransaction(transactionId=transaction_id, entries=entries)

    def entry(self, entry_id: str) -> LedgerEntry:
        entry = state.ledger_entries.get(entry_id)
        if not entry:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Ledger entry not found.")
        return entry

    def list_for_user(self, user_id: str | None = None) -> list[LedgerEntry]:
        entries = list(state.ledger_entries.values())
        if user_id is not None:
            entries = [item for item in entries if item.userId == user_id]
        entries.sort(key=lambda item: item.createdAt, reverse=True)
        return entries


ledger_service = LedgerService()
