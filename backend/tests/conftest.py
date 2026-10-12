import pytest


@pytest.fixture(autouse=True)
def isolated_access_settings(monkeypatch):
    for name in ("STUDIA_FREE_ACCESS", "STUDIA_ACCESS_TOKENS", "CHARIOW_API_KEY",
                 "CHARIOW_PULSE_SECRET", "CHARIOW_PRODUCT_ID", "CHARIOW_STORE_DOMAIN"):
        monkeypatch.delenv(name, raising=False)
