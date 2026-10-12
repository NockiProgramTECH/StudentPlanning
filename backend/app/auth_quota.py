"""Authentication and AI cost/usage quotas for paid course-material features.

Supports both:
- Chariow License API (`CHARIOW_API_KEY`, `GET /v1/licenses/{key}`, `POST /v1/licenses/{key}/activate`)
  and signed Pulse webhooks (`CHARIOW_PULSE_SECRET`);
- Server pilot access tokens (`STUDIA_ACCESS_TOKENS`) for controlled university testing.
"""
from __future__ import annotations

import hashlib
import hmac
import os
from fastapi import Header, HTTPException

from .chariow import ChariowLicenseError, validate_or_activate_chariow_key

MIN_TOKEN_LENGTH = 8


class QuotaExceededError(Exception):
    pass


def configured_pilot_tokens() -> list[tuple[str, str]]:
    """Parse `STUDIA_ACCESS_TOKENS` (`student_id:secret_token,student2:secret2` or `secret_token`)."""
    raw = os.getenv("STUDIA_ACCESS_TOKENS", "").strip()
    if not raw:
        return []
    entries: list[tuple[str, str]] = []
    for item in raw.split(","):
        part = item.strip()
        if not part:
            continue
        if ":" in part:
            student_id, token = part.split(":", 1)
            student_id = student_id.strip()
            token = token.strip()
        else:
            token = part
            digest = hashlib.sha256(token.encode("utf-8")).hexdigest()[:12]
            student_id = f"stu_{digest}"
        if student_id and len(token) >= MIN_TOKEN_LENGTH:
            entries.append((student_id, token))
    return entries


def match_pilot_token(candidate: str) -> str | None:
    if not candidate:
        return None
    matched: str | None = None
    for student_id, valid_token in configured_pilot_tokens():
        if hmac.compare_digest(candidate.encode("utf-8"), valid_token.encode("utf-8")):
            matched = student_id
    return matched


def extract_bearer_token(
    authorization: str | None = Header(default=None),
    x_studia_token: str | None = Header(default=None),
) -> str:
    if authorization and authorization.lower().startswith("bearer "):
        return authorization[7:].strip()
    if x_studia_token:
        return x_studia_token.strip()
    return ""


async def require_student_id(
    authorization: str | None = Header(default=None),
    x_studia_token: str | None = Header(default=None),
) -> str:
    """FastAPI dependency returning the authenticated student_id or raising 401/403/503."""
    from .course_quiz import CourseStore

    store = CourseStore()
    pilot_entries = configured_pilot_tokens()
    has_chariow = bool(os.getenv("CHARIOW_API_KEY", "").strip())

    if not pilot_entries and not has_chariow and not store.has_any_license_records():
        raise HTTPException(
            status_code=503,
            detail=(
                "Fonctionnalité supports de cours non activée sur ce serveur "
                "(CHARIOW_API_KEY et STUDIA_ACCESS_TOKENS non configurés)."
            ),
        )

    candidate = extract_bearer_token(authorization, x_studia_token)
    if not candidate:
        raise HTTPException(
            status_code=401,
            detail="Authentification requise : fournissez une licence Chariow ou un jeton Bearer valide.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    pilot_student = match_pilot_token(candidate)
    if pilot_student is not None:
        return pilot_student

    try:
        cached_student = store.resolve_license_or_token(candidate)
        if cached_student is not None:
            return cached_student

        if has_chariow:
            info = await validate_or_activate_chariow_key(candidate)
            record = store.upsert_chariow_license(info)
            return str(record["student_id"])
    except ChariowLicenseError as exc:
        status = 401 if exc.status_code == 404 else exc.status_code
        raise HTTPException(status_code=status, detail=exc.detail) from exc

    raise HTTPException(
        status_code=401,
        detail="Jeton d'accès ou clé de licence Studia invalide.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def quota_limits() -> dict[str, int | float]:
    return {
        "max_documents_per_day": max(1, int(os.getenv("STUDIA_MAX_DOCS_PER_DAY", "5"))),
        "max_quiz_requests_per_day": max(1, int(os.getenv("STUDIA_MAX_QUIZ_REQUESTS_PER_DAY", "20"))),
        "max_tokens_per_day": max(500, int(os.getenv("STUDIA_MAX_TOKENS_PER_DAY", "25000"))),
        "max_cost_usd_per_month": max(0.05, float(os.getenv("STUDIA_MAX_COST_USD_PER_MONTH", "1.50"))),
        "input_cost_per_1m_usd": max(0.01, float(os.getenv("STUDIA_INPUT_COST_PER_1M_USD", "0.15"))),
        "output_cost_per_1m_usd": max(0.01, float(os.getenv("STUDIA_OUTPUT_COST_PER_1M_USD", "0.60"))),
    }


def estimate_cost_usd(prompt_tokens: int, completion_tokens: int) -> float:
    limits = quota_limits()
    in_rate = float(limits["input_cost_per_1m_usd"])
    out_rate = float(limits["output_cost_per_1m_usd"])
    return round((prompt_tokens * in_rate + completion_tokens * out_rate) / 1_000_000.0, 6)
