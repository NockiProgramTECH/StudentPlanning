"""Validate public build settings without reading or printing server secrets."""
import ipaddress
import os
import re
from urllib.parse import urlsplit


def validate_api_base_url(value: str) -> None:
    if not value or value != value.strip() or any(c.isspace() for c in value):
        raise ValueError("API_BASE_URL est obligatoire, sans espace.")
    try:
        url = urlsplit(value)
        host = url.hostname
        port = url.port
    except ValueError as exc:
        raise ValueError("API_BASE_URL est invalide.") from exc
    if (url.scheme != "https" or not host or url.username is not None
            or url.password is not None or url.query or url.fragment
            or port == 0 or "<" in value or ">" in value):
        raise ValueError("API_BASE_URL doit être une URL HTTPS publique, sans identifiants, paramètres ni fragment.")
    if (host == "localhost" or host.endswith((".localhost", ".local", ".internal", ".invalid", ".example"))
            or host in ("example.com", "example.org", "example.net")
            or host.endswith((".example.com", ".example.org", ".example.net"))):
        raise ValueError("Remplacer l'adresse locale ou d'exemple par le vrai domaine de l'API.")
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ValueError("API_BASE_URL ne doit pas utiliser une adresse IP privée ou locale.")
    if url.path.rstrip("/").endswith(("/docs", "/health", "/api")):
        raise ValueError("Utiliser la base de l'API, pas /docs, /health ou /api.")


def validate_build_number(value: str) -> None:
    if not re.fullmatch(r"[0-9]+", value or "") or not 0 <= int(value) < 2_100_000_000:
        raise ValueError("BUILD_NUMBER doit être un compteur entier Codemagic valide.")


if __name__ == "__main__":
    try:
        validate_api_base_url(os.environ.get("API_BASE_URL", ""))
        validate_build_number(os.environ.get("BUILD_NUMBER", ""))
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print("Configuration publique valide. La disponibilité réelle de l'API reste à vérifier.")
