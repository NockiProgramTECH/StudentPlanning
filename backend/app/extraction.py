"""Extract selectable text, positions and visual cues (no OCR, no PDF upload to AI)."""
import pymupdf

MAX_PAGES = 20
MAX_TEXT_CHARS = 40000


class ExtractionError(ValueError):
    pass


def _color_cue(rgb: tuple[float, float, float]) -> str | None:
    red, green, blue = rgb
    if red >= 0.60 and red > green * 1.35 and red > blue * 1.35:
        return "red"
    if red >= 0.75 and green >= 0.70 and blue <= 0.70 and min(red, green) > blue + 0.20:
        return "yellow"
    return None


def _span_rgb(color: int) -> tuple[float, float, float]:
    return ((color >> 16 & 255) / 255, (color >> 8 & 255) / 255, (color & 255) / 255)


def _filled_areas(page) -> list[tuple[pymupdf.Rect, str]]:
    areas = []
    for drawing in page.get_drawings():
        fill = drawing.get("fill")
        if not fill:
            continue
        hue = _color_cue(fill)
        rect = pymupdf.Rect(drawing["rect"])
        # Ignore full-page tints: a fill is evidence only when local to a cell.
        if hue and 0 < rect.get_area() < page.rect.get_area() * 0.35:
            areas.append((rect, hue))
    return areas


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
            areas = _filled_areas(page)
            blocks = []
            for block in page.get_text("dict", sort=True)["blocks"]:
                if "lines" not in block:
                    continue  # Images do not contain selectable text.
                spans = [span for line in block["lines"] for span in line["spans"] if span["text"].strip()]
                text = " ".join(" ".join(span["text"] for span in line["spans"]).strip()
                                for line in block["lines"])
                text = " ".join(text.split())
                if not text:
                    continue
                count += len(text)
                if count > MAX_TEXT_CHARS:
                    raise ExtractionError("Le texte du PDF dépasse la limite autorisée")
                bbox = pymupdf.Rect(block["bbox"])
                cues = set()
                for span in spans:
                    hue = _color_cue(_span_rgb(span["color"]))
                    if hue:
                        cues.add(f"{hue}_text")
                for rect, hue in areas:
                    # The PDF text must overlap the filled cell, not just share its row.
                    intersection = bbox & rect
                    if intersection.get_area() >= bbox.get_area() * 0.55:
                        cues.add(f"{hue}_fill")
                blocks.append({"text": text, "bbox": [round(v, 1) for v in bbox],
                               "visual_cues": sorted(cues)})
            from .layout import class_header, weekly_cells
            pages.append({"page": number, "class_name": class_header(page),
                          "cells": weekly_cells(page), "blocks": blocks})
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
