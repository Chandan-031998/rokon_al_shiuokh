from __future__ import annotations

import time
from threading import Lock
from typing import Any
from collections.abc import Callable


class RuntimeTtlCache:
    def __init__(self) -> None:
        self._values: dict[str, tuple[float, Any]] = {}
        self._lock = Lock()

    def get(self, key: str) -> Any | None:
        now = time.time()
        with self._lock:
            cached = self._values.get(key)
            if cached is None:
                return None
            expires_at, value = cached
            if expires_at <= now:
                self._values.pop(key, None)
                return None
            return value

    def set(self, key: str, value: Any, ttl_seconds: int) -> Any:
        expires_at = time.time() + max(ttl_seconds, 1)
        with self._lock:
            self._values[key] = (expires_at, value)
        return value

    def get_or_set(self, key: str, ttl_seconds: int, builder: Callable[[], Any]) -> Any:
        cached = self.get(key)
        if cached is not None:
            return cached
        value = builder()
        return self.set(key, value, ttl_seconds)

    def invalidate(self, prefix: str | None = None) -> None:
        with self._lock:
            if prefix is None:
                self._values.clear()
                return
            for key in list(self._values.keys()):
                if key.startswith(prefix):
                    self._values.pop(key, None)


runtime_ttl_cache = RuntimeTtlCache()
