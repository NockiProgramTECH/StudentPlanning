"""Tests for the remote/local deployment verification helper."""
from fastapi.testclient import TestClient
import pytest
from app.main import app
from app.verify_remote import RemoteVerificationError, normalize_base_url, verify_api


def test_normalize_base_url_enforces_https_by_default():
    assert normalize_base_url("https://api.studia.org/") == "https://api.studia.org"
    with pytest.raises(RemoteVerificationError):
        normalize_base_url("http://api.studia.org")
    assert normalize_base_url("http://127.0.0.1:8000/", allow_http=True) == "http://127.0.0.1:8000"
    for invalid in ("", "ftp://api.studia.org", "https://user:pass@api.studia.org", "https://api.studia.org?key=1"):
        with pytest.raises(RemoteVerificationError):
            normalize_base_url(invalid)


def test_verify_api_end_to_end_with_real_l2_sir_pdf(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    with TestClient(app, base_url="https://api.studia.example") as client:
        summary = verify_api("https://api.studia.example", client=client)
    assert summary["health"] == {"status": "ok"}
    assert summary["class_name"] == "L2 SIR"
    assert summary["week_start"] == "2026-10-12"
    assert summary["courses_count"] == 7
    assert summary["source_pages"] == [6]
