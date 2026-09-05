from concurrent.futures import ThreadPoolExecutor
from threading import Event
from app.core.idempotency import IdempotencyStore
from app.core.config import get_settings


def test_concurrent_retries_execute_once():
    store = IdempotencyStore()
    calls = []
    ready = Event()
    def handler():
        calls.append(1)
        return 201, {"id": "purchase"}
    def run():
        ready.wait()
        return store.run(key="key", user_id="buyer", operation="purchase", payload={}, handler=handler)
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(run) for _ in range(8)]
        ready.set()
        results = [future.result() for future in futures]
    assert len(calls) == 1
    assert all(result == (201, {"id": "purchase"}) for result in results)


def test_database_replay_survives_new_store(tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), "financial_database_url", "sqlite:///" + str(tmp_path / "idempotency.db"))
    calls = []
    def handler():
        calls.append(1)
        return 201, {"id": "saved"}
    for _ in range(2):
        assert IdempotencyStore().run(key="same", user_id="buyer", operation="purchase", payload={}, handler=handler) == (201, {"id": "saved"})
    assert len(calls) == 1


def test_independent_processes_share_idempotency(tmp_path):
    import subprocess
    import sys
    script = """
import sys
from app.core.config import get_settings
from app.core.idempotency import IdempotencyStore
from app.repositories.financial_store import RecordMap
settings = get_settings()
settings.app_env = 'test'
settings.financial_database_url = 'sqlite:///' + sys.argv[1]
def handler():
    records = RecordMap('effects', dict)
    previous = records.get('count', {'value': 0})
    previous['value'] += 1
    records['count'] = previous
    return 201, previous
print(IdempotencyStore().run(key='shared', user_id='buyer', operation='buy', payload={}, handler=handler)[1]['value'])
"""
    commands = [subprocess.Popen([sys.executable, "-c", script, str(tmp_path / "shared.db")], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(2)]
    for process in commands:
        stdout, stderr = process.communicate(timeout=30)
        assert process.returncode == 0, stderr
        assert stdout.strip() == "1"


def test_failed_database_handler_does_not_save_effect_or_replay(tmp_path, monkeypatch):
    import pytest
    from app.repositories.financial_store import RecordMap
    monkeypatch.setattr(get_settings(), "financial_database_url", "sqlite:///" + str(tmp_path / "failed.db"))
    def fail():
        RecordMap("effects", dict)["charge"] = {"amount": 840}
        raise RuntimeError("failure after debit")
    with pytest.raises(RuntimeError):
        IdempotencyStore().run(key="failed", user_id="buyer", operation="buy", payload={}, handler=fail)
    assert not RecordMap("effects", dict)
    assert not RecordMap("idempotency", dict)
