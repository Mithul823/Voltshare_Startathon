"""One transaction for each financial operation, with post-commit events."""
from contextlib import contextmanager
from contextvars import ContextVar
from copy import deepcopy
from functools import wraps
from threading import RLock
import logging
from app.core.config import get_settings
from app.repositories.financial_store import connection

_lock = RLock()
_events = ContextVar("financial_events", default=None)


def defer(callback):
    pending = _events.get()
    if pending is None:
        return False
    pending.append(callback)
    return True


@contextmanager
def transaction():
    if _events.get() is not None:
        yield
        return
    settings = get_settings()
    live = settings.financial_database_url or settings.is_production or (settings.supabase_url and settings.supabase_service_role_key)
    pending = []
    token = _events.set(pending)
    try:
        if live:
            with connection():
                yield
        else:
            from app.repositories.state import state
            with _lock:
                snapshot = deepcopy(state.__dict__)
                try:
                    yield
                except BaseException:
                    state.__dict__.clear()
                    state.__dict__.update(snapshot)
                    raise
    except BaseException:
        _events.reset(token)
        raise
    _events.reset(token)
    for callback in pending:
        try:
            callback()
        except Exception:
            logging.getLogger(__name__).exception("Post-commit notification failed")


def atomic(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        with transaction():
            return function(*args, **kwargs)
    return wrapped
