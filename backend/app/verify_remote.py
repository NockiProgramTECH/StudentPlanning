"""End-to-end verification of a deployed or local Studia FastAPI instance.

Usage from backend/:
    python -m app.verify_remote https://votre-api-publique.tld
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
from urllib.parse import urlparse

import httpx

DEFAULT_PDF = Path(__file__).resolve().parents[1] / "tests" / "Emploi_temps_12 -17-oct 2026.pdf"
EXPECTED_SLOTS = {
    (2, "07:30", "12:30", "Transmission des signaux analogiques"),
    (3, "07:30", "12:30", "Electronique analogique"),
    (3, "14:00", "18:00", "Electronique analogique"),
    (4, "07:30", "12:30", "TEEO"),
    (5, "07:30", "12:30", "Electronique analogique"),
    (5, "14:00", "18:00", "Electronique analogique"),
    (6, "07:30", "12:30", "Electronique analogique"),
}


class RemoteVerificationError(RuntimeError):
    pass


def normalize_base_url(base_url: str, *, allow_http: bool = False) -> str:
    cleaned = base_url.strip().rstrip("/")
    parsed = urlparse(cleaned)
    if not parsed.scheme or not parsed.netloc or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise RemoteVerificationError(
            "URL API invalide : fournissez uniquement le domaine (ex. https://api.studia.tld)."
        )
    if parsed.scheme not in ("https", "http"):
        raise RemoteVerificationError("Le schéma de l'URL doit être https (ou http en local).")
    if parsed.scheme != "https" and not allow_http:
        raise RemoteVerificationError(
            "L'URL publique doit utiliser HTTPS (utilisez --allow-http uniquement pour un test local)."
        )
    return cleaned


def verify_api(
    base_url: str,
    *,
    pdf_path: Path = DEFAULT_PDF,
    allow_http: bool = False,
    client: httpx.Client | None = None,
) -> dict:
    base = normalize_base_url(base_url, allow_http=allow_http)
    if not pdf_path.is_file():
        raise RemoteVerificationError(f"PDF L2 SIR introuvable : {pdf_path}")
    pdf_bytes = pdf_path.read_bytes()

    own_client = client is None
    http = client or httpx.Client(timeout=35.0, follow_redirects=True)
    try:
        health = http.get(f"{base}/health")
        if health.status_code != 200 or health.json().get("status") != "ok":
            raise RemoteVerificationError(
                f"GET /health inattendu ({health.status_code}) : {health.text[:200]}"
            )

        openapi = http.get(f"{base}/openapi.json")
        if openapi.status_code != 200 or "/api/import" not in openapi.json().get("paths", {}):
            raise RemoteVerificationError(
                f"GET /openapi.json invalide ({openapi.status_code})"
            )

        imported = http.post(
            f"{base}/api/import",
            data={"class_name": "L2 SIR", "week_start": "2026-10-12"},
            files={"file": (pdf_path.name, pdf_bytes, "application/pdf")},
        )
        if imported.status_code != 200:
            raise RemoteVerificationError(
                f"POST /api/import a échoué ({imported.status_code}) : {imported.text[:300]}"
            )
        payload = imported.json()
        schedule = payload.get("schedule", {})
        courses = schedule.get("courses", [])
        if schedule.get("class_name") != "L2 SIR" or schedule.get("week_start") != "2026-10-12":
            raise RemoteVerificationError(f"En-tête de planning inattendu : {schedule}")
        if len(courses) != 7:
            raise RemoteVerificationError(f"7 cours L2 SIR attendus, {len(courses)} reçus")
        actual_slots = {
            (c["day"], c["start"], c["end"], c["subject"]) for c in courses
        }
        if actual_slots != EXPECTED_SLOTS:
            raise RemoteVerificationError(f"Créneaux L2 SIR inattendus : {actual_slots}")
        if any(c.get("source_page") != 6 for c in courses):
            raise RemoteVerificationError("Tous les cours L2 SIR doivent provenir de la page 6")

        wrong_week = http.post(
            f"{base}/api/import",
            data={"class_name": "L2 SIR", "week_start": "2026-10-19"},
            files={"file": (pdf_path.name, pdf_bytes, "application/pdf")},
        )
        if wrong_week.status_code != 422:
            raise RemoteVerificationError(
                f"Une semaine incohérente doit renvoyer 422 (reçu {wrong_week.status_code})"
            )

        return {
            "base_url": base,
            "health": health.json(),
            "class_name": schedule["class_name"],
            "week_start": schedule["week_start"],
            "courses_count": len(courses),
            "source_pages": sorted({c["source_page"] for c in courses}),
            "courses": courses,
        }
    finally:
        if own_client:
            http.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Vérifie GET /health et POST /api/import (PDF L2 SIR) sur l'API Studia."
    )
    parser.add_argument("base_url", help="URL de base de l'API (ex. https://api.studia.tld)")
    parser.add_argument("--pdf", type=Path, default=DEFAULT_PDF, help="Chemin du PDF L2 SIR")
    parser.add_argument(
        "--allow-http",
        action="store_true",
        help="Autoriser http:// uniquement pour un essai local",
    )
    args = parser.parse_args(argv)
    try:
        summary = verify_api(args.base_url, pdf_path=args.pdf, allow_http=args.allow_http)
    except Exception as exc:
        print(f"ÉCHEC : {exc}", file=sys.stderr)
        return 1
    print(
        f"OK : {summary['base_url']} · santé={summary['health']['status']} · "
        f"{summary['class_name']} ({summary['week_start']}) · "
        f"{summary['courses_count']} cours extraits (page {summary['source_pages'][0]})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
