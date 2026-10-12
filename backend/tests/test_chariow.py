import hashlib
import hmac
import json
from fastapi.testclient import TestClient
import httpx
from app.main import app


def _sign_pulse(raw_body: bytes, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    return f"sha256={digest}"


def test_chariow_license_activation_and_course_access(monkeypatch, tmp_path):
    monkeypatch.setenv("STUDIA_DB_PATH", str(tmp_path / "chariow.sqlite3"))
    monkeypatch.setenv("CHARIOW_API_KEY", "sk_live_server_secret_test")
    monkeypatch.setenv("CHARIOW_PRODUCT_ID", "prd_studia_l2_sir")
    monkeypatch.delenv("STUDIA_ACCESS_TOKENS", raising=False)

    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "server_pulse_test")

    calls: list[tuple[str, str]] = []

    class FakeAsyncClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def get(self, url, headers=None):
            calls.append(("GET", url))
            assert headers["Authorization"] == "Bearer sk_live_server_secret_test"
            return httpx.Response(
                200,
                json={
                    "message": "License retrieved successfully",
                    "data": {
                        "id": "lic_abc123",
                        "license_key": "CHRW-L2SIR-2026-0001",
                        "status": "pending_activation",
                        "is_active": False,
                        "is_expired": False,
                        "can_activate": True,
                        "activation_count": 0,
                        "max_activations": 2,
                        "activations_remaining": 2,
                        "expires_at": "2027-06-30T23:59:59+00:00",
                        "product": {"id": "prd_studia_l2_sir", "name": "Pass Semestre Studia L2 SIR"},
                    },
                    "errors": [],
                },
            )

        async def post(self, url, headers=None, json=None):
            calls.append(("POST", url))
            assert headers["Authorization"] == "Bearer sk_live_server_secret_test"
            assert json == {"device_identifier": "android-pixel-l2sir"}
            return httpx.Response(
                200,
                json={
                    "message": "License activated successfully",
                    "data": {
                        "id": "lic_abc123",
                        "license_key": "CHRW-L2SIR-2026-0001",
                        "status": "active",
                        "is_active": True,
                        "is_expired": False,
                        "can_activate": True,
                        "activation_count": 1,
                        "max_activations": 2,
                        "activations_remaining": 1,
                        "activated_at": "2026-10-12T08:30:00+00:00",
                        "expires_at": "2027-06-30T23:59:59+00:00",
                        "product": {"id": "prd_studia_l2_sir", "name": "Pass Semestre Studia L2 SIR"},
                    },
                    "errors": [],
                },
            )

    monkeypatch.setattr("app.chariow.httpx.AsyncClient", FakeAsyncClient)

    client = TestClient(app)
    res = client.post(
        "/api/licenses/activate",
        json={
            "license_key": "CHRW-L2SIR-2026-0001",
            "device_identifier": "android-pixel-l2sir",
        },
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["valid"] is True
    assert body["status"] == "active"
    assert body["masked_key"] == "CHR-***-001"
    assert body["activations_remaining"] == 1
    assert body["product_name"] == "Pass Semestre Studia L2 SIR"
    assert body["access_token"].startswith("studia_lic_")
    assert len(calls) == 2

    # Subsequent calls to /api/courses/quota with the issued access_token succeed from SQLite cache
    quota_res = client.get(
        "/api/courses/quota",
        headers={"Authorization": f"Bearer {body['access_token']}"},
    )
    assert quota_res.status_code == 200
    assert quota_res.json()["student_id"] == body["student_id"]


def test_chariow_pulse_webhook_signature_idempotency_and_revocation(monkeypatch, tmp_path):
    monkeypatch.setenv("STUDIA_DB_PATH", str(tmp_path / "pulse.sqlite3"))
    monkeypatch.setenv("CHARIOW_PRODUCT_ID", "prd_1")
    pulse_secret = "whsec_test_chariow_pulse_signing_secret"
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", pulse_secret)
    monkeypatch.setenv("CHARIOW_API_KEY", "sk_live_server_secret_test")

    client = TestClient(app)

    # 1. Activated event via Pulse with escaped slashes in raw body (as documented by Chariow)
    raw_activated = (
        b'{"event":"license.activated","license":{"id":"lic_999","key":"CHRW-PULSE-KEY-9999",'
        b'"status":"active","activation_count":1,"max_activations":2,'
        b'"expires_at":"2027-07-01T00:00:00+00:00"},'
        b'"product":{"id":"prd_1","name":"Studia L2 SIR","url":"https:\\/\\/chariow.com\\/studia"}}'
    )
    bad_res = client.post(
        "/api/webhooks/chariow",
        content=raw_activated,
        headers={
            "Content-Type": "application/json",
            "x-chariow-signature": "sha256=" + ("0" * 64),
            "x-pulse-delivery-id": "deliv_001",
            "x-pulse-event": "license.activated",
        },
    )
    assert bad_res.status_code == 401

    good_sig = _sign_pulse(raw_activated, pulse_secret)
    ok_res = client.post(
        "/api/webhooks/chariow",
        content=raw_activated,
        headers={
            "Content-Type": "application/json",
            "x-chariow-signature": good_sig,
            "x-pulse-id": "pulse_studia_1",
            "x-pulse-delivery-id": "deliv_001",
            "x-pulse-event": "license.activated",
        },
    )
    assert ok_res.status_code == 200
    assert ok_res.json()["status"] == "processed"

    # Retry with the same x-pulse-delivery-id is deduplicated
    dup_res = client.post(
        "/api/webhooks/chariow",
        content=raw_activated,
        headers={
            "Content-Type": "application/json",
            "x-chariow-signature": good_sig,
            "x-pulse-id": "pulse_studia_1",
            "x-pulse-delivery-id": "deliv_001",
            "x-pulse-event": "license.activated",
        },
    )
    assert dup_res.status_code == 200
    assert dup_res.json()["status"] == "duplicate"

    # License is now usable on /api/courses/quota
    q_ok = client.get(
        "/api/courses/quota",
        headers={"Authorization": "Bearer CHRW-PULSE-KEY-9999"},
    )
    assert q_ok.status_code == 200

    # 2. Revocation Pulse event immediately blocks access
    raw_revoked = json.dumps(
        {
            "event": "license.revoked",
            "license": {
                "id": "lic_999",
                "key": "CHRW-PULSE-KEY-9999",
                "status": "revoked",
                "revoked_at": "2026-10-12T12:00:00+00:00",
            },
        }
    ).encode("utf-8")
    rev_res = client.post(
        "/api/webhooks/chariow",
        content=raw_revoked,
        headers={
            "Content-Type": "application/json",
            "x-chariow-signature": _sign_pulse(raw_revoked, pulse_secret),
            "x-pulse-delivery-id": "deliv_002",
            "x-pulse-event": "license.revoked",
        },
    )
    assert rev_res.status_code == 200

    q_revoked = client.get(
        "/api/courses/quota",
        headers={"Authorization": "Bearer CHRW-PULSE-KEY-9999"},
    )
    assert q_revoked.status_code == 403
    assert "inactif" in q_revoked.json()["detail"]
