"""Server-controlled course access and AI cost/usage quotas."""
from __future__ import annotations

import hashlib
import os
import re
from fastapi import Header, HTTPException

from .chariow import ChariowLicenseError
from .access import free_access_enabled, require_chariow_config


class QuotaExceededError(Exception):
    pass


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
    x_device_identifier: str | None = Header(default=None),
) -> str:
    from .course_quiz import CourseStore

    if free_access_enabled():
        device = (x_device_identifier or "").strip()
        if not re.fullmatch(r"[A-Za-z0-9_-]{16,255}", device):
            raise HTTPException(422, "Identifiant appareil requis (16 à 255 caractères).")
        # The same installation keeps the same document ownership and all quotas.
        return "device_" + hashlib.sha256(device.encode()).hexdigest()

    require_chariow_config()
    candidate = extract_bearer_token(authorization, x_studia_token)
    if not candidate:
        raise HTTPException(401, "Accès étudiant requis.", headers={"WWW-Authenticate": "Bearer"})
    try:
        student = CourseStore().resolve_license_or_token(candidate)
        if student is not None:
            return student
    except ChariowLicenseError as exc:
        raise HTTPException(exc.status_code, "Accès étudiant inactif. Finalisez votre accès.") from exc
    # Unknown credentials must go through the server activation endpoint, never a pilot bypass.
    raise HTTPException(401, "Accès étudiant invalide.", headers={"WWW-Authenticate": "Bearer"})


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
