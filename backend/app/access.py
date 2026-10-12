"""Server-owned access policy. No pilot-token bypass in controlled mode."""
import os
from urllib.parse import urlsplit

from fastapi import HTTPException

DEFAULT_PRODUCT_ID = "prd_mrrhb8h2"
DEFAULT_STORE_DOMAIN = "https://camfbzgd.mychariow.co"


def free_access_enabled() -> bool:
    # Fail closed for absent or misspelled values.
    return os.getenv("STUDIA_FREE_ACCESS", "false").strip().lower() == "true"


def product_id() -> str:
    return os.getenv("CHARIOW_PRODUCT_ID", "").strip() or DEFAULT_PRODUCT_ID


def require_chariow_config() -> None:
    if not all(os.getenv(name, "").strip() for name in ("CHARIOW_API_KEY", "CHARIOW_PULSE_SECRET")):
        raise HTTPException(503, "Espace étudiant temporairement indisponible.")


def portal_url() -> str:
    domain = os.getenv("CHARIOW_STORE_DOMAIN", DEFAULT_STORE_DOMAIN).strip().rstrip("/")
    parsed = urlsplit(domain)
    product = product_id()
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password
            or parsed.query or parsed.fragment or parsed.path
            or not all(c.isalnum() or c in "_-" for c in product)):
        raise HTTPException(503, "Portail étudiant non configuré.")
    return f"{domain}/{product}"
