"""Access policy: public config, server portal, free quotas, signed email lookup."""
import hashlib
import hmac
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app.chariow import normalize_chariow_license_data
from app.course_quiz import CourseStore
from app.main import app
from test_course_materials import make_course_pdf

client = TestClient(app)
DEVICE = {"X-Device-Identifier": "installation_l2_sir_123456"}
PRODUCT = "prd_mrrhb8h2"
KEY = "TEST-STUDENT-ACCESS-0001"


@pytest.fixture(autouse=True)
def isolated_database(monkeypatch, tmp_path):
    monkeypatch.setenv("STUDIA_DB_PATH", str(tmp_path / "access.sqlite3"))


@pytest.mark.parametrize("value,expected", [(None, False), ("false", False), ("true", True),
                                           (" TRUE ", True), ("typo", False)])
def test_public_config(monkeypatch, value, expected):
    if value is not None:
        monkeypatch.setenv("STUDIA_FREE_ACCESS", value)
    response = client.get("/api/access/config")
    assert response.status_code == 200
    assert response.json() == {"free_access": expected, "portal_url": "/api/access/portal"}
    assert response.headers["cache-control"] == "no-store"


def test_portal_default_custom_and_invalid_configuration(monkeypatch):
    response = client.get("/api/access/portal", follow_redirects=False)
    assert response.status_code == 302
    assert response.headers["location"] == f"https://camfbzgd.mychariow.co/{PRODUCT}"
    monkeypatch.setenv("CHARIOW_STORE_DOMAIN", "https://school.mychariow.co/")
    monkeypatch.setenv("CHARIOW_PRODUCT_ID", "prd_school")
    response = client.get("/api/access/portal?next=https://attacker.example", follow_redirects=False)
    assert response.status_code == 302
    assert response.headers["location"] == "https://school.mychariow.co/prd_school"
    for bad in ("http://school.example", "javascript:alert(1)", "https://user:secret@school.example",
                "https://school.example?next=bad", "https://school.example/path"):
        monkeypatch.setenv("CHARIOW_STORE_DOMAIN", bad)
        assert client.get("/api/access/portal", follow_redirects=False).status_code == 503


@pytest.mark.parametrize("device", [None, "", "short", "a" * 256, "invalid identifier !!"])
def test_free_access_requires_valid_device_not_a_secret(monkeypatch, device):
    monkeypatch.setenv("STUDIA_FREE_ACCESS", "true")
    headers = {} if device is None else {"X-Device-Identifier": device}
    assert client.get("/api/courses/quota", headers=headers).status_code == 422


def import_document(headers=DEVICE):
    pdf = make_course_pdf([("Chapitre 1 : Signaux", ["Un signal analogique varie de façon continue."])])
    return client.post("/api/courses/import", headers=headers, data={"subject": "L2 SIR"},
                       files={"file": ("signaux.pdf", pdf, "application/pdf")})


def test_free_access_has_stable_device_quotas_and_isolated_documents(monkeypatch):
    monkeypatch.setenv("STUDIA_FREE_ACCESS", "true")
    monkeypatch.setenv("STUDIA_MAX_DOCS_PER_DAY", "1")

    async def no_external_call(*args, **kwargs):
        pytest.fail("Free access must never call the external access provider")
    monkeypatch.setattr("app.main.validate_or_activate_chariow_key", no_external_call)
    imported = import_document()
    assert imported.status_code == 200
    doc = imported.json()["id"]
    quota = client.get("/api/courses/quota", headers=DEVICE).json()
    assert quota["documents_today"] == 1
    assert quota["student_id"].startswith("device_")
    assert import_document({**DEVICE, "Authorization": "Bearer ignored"}).status_code == 429
    other = {"X-Device-Identifier": "another_installation_l2_sir"}
    assert client.get("/api/courses/quota", headers=other).json()["documents_today"] == 0
    assert client.get(f"/api/courses/{doc}", headers=other).status_code == 404
    # No free access once the server policy changes, even on the same installation.
    monkeypatch.setenv("STUDIA_FREE_ACCESS", "false")
    monkeypatch.setenv("CHARIOW_API_KEY", "server-test")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "pulse-test")
    assert client.get(f"/api/courses/{doc}", headers=DEVICE).status_code == 401


@pytest.mark.parametrize("limit", ["monthly", "daily_tokens"])
def test_free_quiz_budget_checked_before_openrouter(monkeypatch, limit):
    monkeypatch.setenv("STUDIA_FREE_ACCESS", "true")
    doc = import_document().json()["id"]
    student = client.get("/api/courses/quota", headers=DEVICE).json()["student_id"]
    if limit == "monthly":
        monkeypatch.setenv("STUDIA_MAX_COST_USD_PER_MONTH", "0.05")
        monkeypatch.setenv("STUDIA_MAX_TOKENS_PER_DAY", "1000000")
        CourseStore().record_usage(student, "quiz", 400000, 0)
    else:
        monkeypatch.setenv("STUDIA_MAX_TOKENS_PER_DAY", "500")
        CourseStore().record_usage(student, "quiz", 400, 0)

    async def no_openrouter(**kwargs):
        pytest.fail("Budget exhaustion must block before spending")
    monkeypatch.setattr("app.main.generate_section_questions_openrouter", no_openrouter)
    response = client.post(f"/api/courses/{doc}/sections/0/questions", headers=DEVICE, json={"count": 1})
    assert response.status_code == 429
    assert ("mensuel" if limit == "monthly" else "journalier") in response.json()["detail"]


def pulse(payload, secret="pulse-test", delivery="delivery-1", valid=True):
    raw = json.dumps(payload).encode()
    signature = hmac.new(secret.encode(), raw, hashlib.sha256).hexdigest()
    return client.post("/api/webhooks/chariow", content=raw, headers={
        "x-chariow-signature": "sha256=" + (signature if valid else "0" * 64),
        "x-pulse-delivery-id": delivery,
    })


def test_email_activation_requires_signed_pulse_and_fresh_product_verification(monkeypatch):
    monkeypatch.setenv("CHARIOW_API_KEY", "server-test")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "pulse-test")
    body = {"access_code": " Student@Example.edu ", "device_identifier": DEVICE["X-Device-Identifier"]}
    assert client.post("/api/access/activate", json=body).status_code == 403
    payload = {"event": "license.issued", "license": {"key": KEY, "status": "pending_activation"},
               "customer": {"email": "student@example.edu"}, "product": {"id": PRODUCT}}
    assert pulse(payload, valid=False).status_code == 401
    assert client.post("/api/access/activate", json=body).status_code == 403
    assert pulse(payload).status_code == 200
    assert pulse(payload).json()["status"] == "duplicate"
    calls = []

    async def get(self, url, **kwargs):
        calls.append("get")
        assert url.endswith(KEY)
        assert kwargs["headers"]["Authorization"] == "Bearer server-test"
        return httpx.Response(200, json={"data": {"status": "pending_activation", "can_activate": True,
                                                "product": {"id": PRODUCT}}})

    async def post(self, url, **kwargs):
        calls.append("post")
        assert kwargs["json"] == {"device_identifier": DEVICE["X-Device-Identifier"]}
        return httpx.Response(200, json={"data": {"status": "active", "product": {"id": PRODUCT}}})
    monkeypatch.setattr(httpx.AsyncClient, "get", get)
    monkeypatch.setattr(httpx.AsyncClient, "post", post)
    activated = client.post("/api/access/activate", json=body)
    assert activated.status_code == 200, activated.text
    assert calls == ["get", "post"]
    token = activated.json()["access_token"]
    assert token != KEY
    assert client.get("/api/courses/quota", headers={"Authorization": f"Bearer {token}"}).status_code == 200
    assert calls == ["get", "post"]  # persisted token, no credential requested again
    # Compatible legacy route and explicit email field use the same server validation.
    again = client.post("/api/licenses/activate", json={"email": "student@example.edu", "device_identifier": DEVICE["X-Device-Identifier"]})
    assert again.status_code == 200
    assert again.json()["access_token"] == token
    assert pulse({"event": "license.revoked", "license": {"key": KEY}}, delivery="revoked").status_code == 200
    assert client.get("/api/courses/quota", headers={"Authorization": f"Bearer {token}"}).status_code in (401, 403)
    assert client.post("/api/access/activate", json=body).status_code == 403


@pytest.mark.parametrize("status,product", [("active", "other-product"), ("expired", PRODUCT), ("revoked", PRODUCT)])
def test_cached_ineligible_access_is_rejected(monkeypatch, status, product):
    monkeypatch.setenv("CHARIOW_API_KEY", "server-test")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "pulse-test")
    record = CourseStore().upsert_chariow_license(normalize_chariow_license_data(
        {"status": status, "product": {"id": product}}, KEY))
    assert client.get("/api/courses/quota", headers={"Authorization": f"Bearer {record['access_token']}"}).status_code == 403


def test_pilot_token_never_short_circuits_activation(monkeypatch):
    monkeypatch.setenv("CHARIOW_API_KEY", "server-test")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "pulse-test")
    monkeypatch.setenv("STUDIA_ACCESS_TOKENS", "student:pilot-token")
    calls = []

    async def get(self, url, **kwargs):
        calls.append(url)
        return httpx.Response(404)
    monkeypatch.setattr(httpx.AsyncClient, "get", get)
    assert client.post("/api/access/activate", json={"access_code": "pilot-token"}).status_code == 404
    assert len(calls) == 1


def test_no_new_device_when_activation_limit_reached(monkeypatch):
    monkeypatch.setenv("CHARIOW_API_KEY", "server-test")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "pulse-test")

    async def get(self, url, **kwargs):
        return httpx.Response(200, json={"data": {
            "status": "active", "can_activate": False, "activations_remaining": 0,
            "product": {"id": PRODUCT},
        }})
    monkeypatch.setattr(httpx.AsyncClient, "get", get)
    response = client.post("/api/access/activate", json={"access_code": KEY, "device_identifier": "new-device"})
    assert response.status_code == 403
