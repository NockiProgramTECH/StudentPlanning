"""Extract selectable text with page provenance. Scans are explicitly unsupported."""
import pymupdf

MAX_PAGES = 20
MAX_TEXT_CHARS = 40000


class ExtractionError(ValueError):
    pass


def extract_pdf(data: bytes) -> list[dict]:
    try:
        doc = pymupdf.open(stream=data, filetype="pdf")
        if doc.is_encrypted:
            raise ExtractionError("PDF protégé par mot de passe non pris en charge")
        if not 1 <= len(doc) <= MAX_PAGES:
            raise ExtractionError(f"Le PDF doit contenir entre 1 et {MAX_PAGES} pages")
        pages = []
        count = 0
        for number, page in enumerate(doc, 1):
            lines = []
            for block in page.get_text("blocks", sort=True):
                text = " ".join(block[4].split())
                if text:
                    count += len(text)
                    if count > MAX_TEXT_CHARS:
                        raise ExtractionError("Le texte du PDF dépasse la limite autorisée")
                    lines.append({"text": text, "bbox": [round(v, 1) for v in block[:4]]})
            pages.append({"page": number, "blocks": lines})
        if not any(p["blocks"] for p in pages):
            raise ExtractionError("Aucun texte sélectionnable : les PDF scannés nécessitent un OCR")
        return pages
    except ExtractionError:
        raise
    except Exception as exc:
        raise ExtractionError("Impossible de lire ce PDF") from exc
    finally:
        if "doc" in locals():
            doc.close()
