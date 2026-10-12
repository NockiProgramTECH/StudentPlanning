"""Chariow License API & Pulse webhook integration (server-side only).

Official Chariow documentation implemented:
- Base URL: https://api.chariow.com/v1
- Get License: GET /v1/licenses/{licenseKey}
- Activate License: POST /v1/licenses/{licenseKey}/activate {"device_identifier": "..."}
- Pulse Webhooks: HMAC-SHA256 on raw request body with CHARIOW_PULSE_SECRET (whsec_...)
  in header `x-chariow-signature: sha256=<hex>`, deduplicated on `x-pulse-delivery-id`.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import hmac
import os
from urllib.parse import quote

import httpx

DEFAULT_CHARIOW_BASE_URL = "https://api.chariow.com/v1"


class ChariowLicenseError(Exception):
    def __init__(self, detail: str, status_code: int = 403):
        super().__init__(detail)
        self.detail = detail
        self.status_code = status_code


class ChariowConfigError(Exception):
    pass


def chariow_base_url() -> str:
    return os.getenv("CHARIOW_BASE_URL", DEFAULT_CHARIOW_BASE_URL).strip().rstrip("/")


def chariow_api_key() -> str:
    key = os.getenv("CHARIOW_API_KEY", "").strip()
    if not key:
        raise ChariowConfigError("CHARIOW_API_KEY non configurée sur le serveur")
    return key


def mask_license_key(key: str) -> str:
    cleaned = key.strip()
    if len(cleaned) <= 6:
        return "***"
    return f"{cleaned[:3]}-***-{cleaned[-3:]}"


def _extract_activations(data: dict) -> tuple[int, int | None, int | None]:
    if isinstance(data.get("activations"), dict):
        act = data["activations"]
        count = int(act.get("count") or 0)
        max_act = int(act["max"]) if act.get("max") is not None else None
        rem = int(act["remaining"]) if act.get("remaining") is not None else None
        return count, max_act, rem
    count = int(data.get("activation_count") or data.get("activations") or 0)
    max_act = int(data["max_activations"]) if data.get("max_activations") is not None else None
    rem = int(data["activations_remaining"]) if data.get("activations_remaining") is not None else (
        max(0, max_act - count) if max_act is not None else None
    )
    return count, max_act, rem


def _extract_license_key(data: dict, fallback: str) -> str:
    if isinstance(data.get("license"), dict) and data["license"].get("key"):
        return str(data["license"]["key"])
    return str(data.get("license_key") or data.get("licence_key") or fallback)


def _check_product_restriction(data: dict) -> None:
    expected_product = os.getenv("CHARIOW_PRODUCT_ID", "").strip()
    if not expected_product:
        return
    product = data.get("product") or {}
    prod_id = str(product.get("id") or "")
    prod_slug = str(product.get("slug") or "")
    if expected_product not in (prod_id, prod_slug):
        raise ChariowLicenseError(
            "Cette clé de licence n'appartient pas à l'offre Studia configurée.",
            status_code=403,
        )


async def fetch_chariow_license(license_key: str) -> dict:
    """Call `GET /v1/licenses/{licenseKey}` on Chariow."""
    key = chariow_api_key()
    encoded_key = quote(license_key.strip(), safe="")
    url = f"{chariow_base_url()}/licenses/{encoded_key}"
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(
                url,
                headers={
                    "Authorization": f"Bearer {key}",
                    "Accept": "application/json",
                },
            )
    except httpx.HTTPError as exc:
        raise ChariowLicenseError(
            "Service de licence Chariow temporairement injoignable.",
            status_code=503,
        ) from exc

    if response.status_code == 404:
        raise ChariowLicenseError("Clé de licence introuvable.", status_code=404)
    if response.status_code in (401, 403):
        raise ChariowLicenseError(
            "Configuration Chariow invalide côté serveur (clé API refusée).",
            status_code=503,
        )
    if response.status_code >= 400:
        raise ChariowLicenseError(
            "Impossible de vérifier la licence auprès de Chariow.",
            status_code=503,
        )
    try:
        payload = response.json()
        data = payload.get("data")
        if not isinstance(data, dict):
            raise ValueError("Invalid data object")
        return data
    except Exception as exc:
        raise ChariowLicenseError(
            "Réponse Chariow illisible lors de la vérification de licence.",
            status_code=503,
        ) from exc


async def activate_chariow_license(
    license_key: str,
    device_identifier: str | None = None,
) -> dict:
    """Call `POST /v1/licenses/{licenseKey}/activate` on Chariow."""
    key = chariow_api_key()
    encoded_key = quote(license_key.strip(), safe="")
    url = f"{chariow_base_url()}/licenses/{encoded_key}/activate"
    body: dict[str, str] = {}
    if device_identifier and device_identifier.strip():
        body["device_identifier"] = device_identifier.strip()[:255]

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                json=body,
            )
    except httpx.HTTPError as exc:
        raise ChariowLicenseError(
            "Service d'activation Chariow temporairement injoignable.",
            status_code=503,
        ) from exc

    if response.status_code == 404:
        raise ChariowLicenseError("Clé de licence introuvable.", status_code=404)

    if response.status_code == 400:
        msg = ""
        try:
            msg = str(response.json().get("message") or "")
        except Exception:
            msg = response.text
        lower = msg.lower()
        # Documented by Chariow: products with requires_activation=false return 400
        # "This license does not require activation and is already active."
        if "already active" in lower or "does not require activation" in lower:
            return await fetch_chariow_license(license_key)
        if "revoked" in lower:
            raise ChariowLicenseError("Cette licence a été révoquée.", status_code=403)
        if "expired" in lower:
            raise ChariowLicenseError("Cette licence a expiré.", status_code=403)
        if "limit" in lower or "maximum" in lower:
            raise ChariowLicenseError(
                "Le nombre maximal d'appareils autorisés pour cette licence est atteint.",
                status_code=403,
            )
        raise ChariowLicenseError(
            f"Activation refusée par Chariow : {msg or 'requête invalide'}",
            status_code=403,
        )

    if response.status_code >= 400:
        raise ChariowLicenseError(
            "Erreur du service Chariow lors de l'activation.",
            status_code=503,
        )

    try:
        payload = response.json()
        data = payload.get("data")
        if not isinstance(data, dict):
            raise ValueError("Missing data")
        return data
    except Exception as exc:
        raise ChariowLicenseError(
            "Réponse Chariow illisible lors de l'activation.",
            status_code=503,
        ) from exc


def normalize_chariow_license_data(data: dict, fallback_key: str) -> dict:
    """Normalize a Chariow license object from GET/POST or Pulse webhook."""
    lic_key = _extract_license_key(data, fallback_key)
    status = str(data.get("status") or "unknown").lower()
    revoked_at = data.get("revoked_at")
    expired_at = data.get("expired_at")
    expires_at = data.get("expires_at")

    is_expired = bool(data.get("is_expired")) or status == "expired" or expired_at is not None
    if not is_expired and isinstance(expires_at, str) and expires_at.strip():
        try:
            exp_dt = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
            if exp_dt.tzinfo is None:
                exp_dt = exp_dt.replace(tzinfo=timezone.utc)
            if exp_dt <= datetime.now(timezone.utc):
                is_expired = True
        except ValueError:
            pass

    is_revoked = status == "revoked" or revoked_at is not None
    is_active_flag = data.get("is_active")
    if is_active_flag is None:
        is_active = status == "active" and not is_expired and not is_revoked
    else:
        is_active = bool(is_active_flag) and not is_expired and not is_revoked

    can_activate = bool(data.get("can_activate", True))
    count, max_act, rem = _extract_activations(data)

    customer_id = data.get("customer_id")
    if customer_id is None and isinstance(data.get("customer"), dict):
        customer_id = data["customer"].get("id") or data["customer"].get("email")

    product = data.get("product") if isinstance(data.get("product"), dict) else {}
    return {
        "license_id": str(data.get("id") or ""),
        "license_key": lic_key,
        "masked_key": mask_license_key(lic_key),
        "status": "revoked" if is_revoked else ("expired" if is_expired else status),
        "is_active": is_active,
        "is_expired": is_expired,
        "is_revoked": is_revoked,
        "can_activate": can_activate,
        "activation_count": count,
        "max_activations": max_act,
        "activations_remaining": rem,
        "activated_at": data.get("activated_at"),
        "expires_at": expires_at,
        "revoked_at": revoked_at,
        "customer_id": str(customer_id) if customer_id is not None else None,
        "product_id": str(product.get("id") or "") or None,
        "product_name": str(product.get("name") or "") or None,
    }


async def validate_or_activate_chariow_key(
    license_key: str,
    device_identifier: str | None = None,
    *,
    already_activated_on_device: bool = False,
) -> dict:
    """Validate a license key with Chariow and activate it if needed."""
    raw_data = await fetch_chariow_license(license_key)
    _check_product_restriction(raw_data)
    info = normalize_chariow_license_data(raw_data, license_key)

    if info["is_revoked"]:
        raise ChariowLicenseError("Cette licence a été révoquée.", status_code=403)
    if info["is_expired"]:
        raise ChariowLicenseError("Cette licence a expiré.", status_code=403)

    if info["status"] == "pending_activation" or (
        device_identifier and not already_activated_on_device and info["can_activate"]
    ):
        if info["status"] == "pending_activation" and not info["can_activate"]:
            raise ChariowLicenseError(
                "Le nombre maximal d'activations pour cette licence est atteint.",
                status_code=403,
            )
        activated_raw = await activate_chariow_license(license_key, device_identifier)
        _check_product_restriction(activated_raw)
        info = normalize_chariow_license_data(activated_raw, license_key)

    if not info["is_active"] or info["is_expired"] or info["is_revoked"]:
        raise ChariowLicenseError("Cette licence Chariow n'est pas active.", status_code=403)

    return info


def verify_chariow_pulse_signature(
    raw_body: bytes,
    signature_header: str | None,
    pulse_secret: str | None = None,
) -> bool:
    """Verify `x-chariow-signature: sha256=<hex>` over raw HTTP body bytes in constant time."""
    secret = (pulse_secret if pulse_secret is not None else os.getenv("CHARIOW_PULSE_SECRET", "")).strip()
    if not secret:
        raise ChariowConfigError("CHARIOW_PULSE_SECRET non configuré sur le serveur")
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    expected_hex = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    expected = f"sha256={expected_hex}"
    received = signature_header.strip()
    if len(expected) != len(received):
        return False
    return hmac.compare_digest(expected.encode("ascii"), received.encode("utf-8"))
