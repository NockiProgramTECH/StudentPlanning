"""Extract selectable text from course materials (supports de cours) by sections.

Course materials are distinct from weekly timetable PDFs:
- Strictly bounded size (10 MB), pages (30) and total text (80 000 chars);
- Rejects weekly timetable grids so users do not mix timetables and course notes;
- Segments text into bounded sections with exact page references ([Page N]).
"""
from __future__ import annotations

import re
import statistics
import pymupdf

from .layout import weekly_cells
from .schemas import CourseSection

MAX_COURSE_PDF_BYTES = 10 * 1024 * 1024
MAX_COURSE_PAGES = 30
MAX_COURSE_TEXT_CHARS = 80_000
MAX_SECTION_CHARS = 4_000
MAX_SECTIONS = 25

HEADING_PATTERN = re.compile(
    r"^(?:"
    r"(?:chapitre|section|partie|module|cours|leçon|td|tp)\s+[\wIVX]+(?:\s*[:.–-]\s*.+)?"
    r"|"
    r"(?:[IVX]{1,5}|\d{1,2}(?:\.\d{1,2}){0,2})\s*[.)–-]\s+[A-ZÀ-ÖØ-Þ].{2,100}"
    r")$",
    re.IGNORECASE,
)


class CourseExtractionError(ValueError):
    pass


def _is_heading(line_text: str, max_font_size: float, body_size: float, is_bold: bool) -> bool:
    cleaned = " ".join(line_text.split())
    if len(cleaned) < 3 or len(cleaned) > 110:
        return False
    if cleaned.endswith((".", ",", ";")) and not HEADING_PATTERN.match(cleaned):
        return False
    if HEADING_PATTERN.match(cleaned):
        return True
    if max_font_size >= body_size * 1.18 and any(ch.isalpha() for ch in cleaned):
        return True
    if is_bold and max_font_size >= body_size * 1.05 and len(cleaned) <= 75 and cleaned[0].isupper():
        return True
    return False


def extract_course_pdf(data: bytes) -> tuple[int, int, list[CourseSection]]:
    """Return (page_count, total_chars, sections) from a course material PDF."""
    try:
        doc = pymupdf.open(stream=data, filetype="pdf")
    except Exception as exc:
        raise CourseExtractionError("Impossible de lire ce PDF de cours") from exc

    try:
        if doc.is_encrypted:
            raise CourseExtractionError("PDF protégé par mot de passe non pris en charge")
        page_count = len(doc)
        if not 1 <= page_count <= MAX_COURSE_PAGES:
            raise CourseExtractionError(
                f"Le support de cours doit contenir entre 1 et {MAX_COURSE_PAGES} pages"
            )

        font_sizes: list[float] = []
        raw_items: list[tuple[int, str, float, bool]] = []
        total_chars = 0

        for page_num, page in enumerate(doc, start=1):
            if weekly_cells(page):
                raise CourseExtractionError(
                    "Ce document est un emploi du temps hebdomadaire. "
                    "Utilisez l'import de planning pour les emplois du temps, ou choisissez un support de cours."
                )
            page_dict = page.get_text("dict", sort=True)
            for block in page_dict.get("blocks", []):
                if "lines" not in block:
                    continue
                for line in block["lines"]:
                    spans = [s for s in line.get("spans", []) if s.get("text", "").strip()]
                    if not spans:
                        continue
                    text = " ".join(" ".join(s["text"] for s in spans).split())
                    if not text:
                        continue
                    total_chars += len(text)
                    if total_chars > MAX_COURSE_TEXT_CHARS:
                        raise CourseExtractionError(
                            f"Le texte du support dépasse la limite autorisée ({MAX_COURSE_TEXT_CHARS} caractères)"
                        )
                    max_size = max(float(s.get("size", 11.0)) for s in spans)
                    bold = any(bool(int(s.get("flags", 0)) & 16) or "bold" in str(s.get("font", "")).lower() for s in spans)
                    font_sizes.extend(float(s.get("size", 11.0)) for s in spans)
                    raw_items.append((page_num, text, max_size, bold))

        if not raw_items:
            raise CourseExtractionError(
                "Aucun texte sélectionnable : les supports scannés nécessitent un OCR"
            )

        body_size = statistics.median(font_sizes) if font_sizes else 11.0

        # Group lines into logical sections by detected headings.
        draft_sections: list[dict] = []
        current_title = "Introduction / Section 1"
        current_lines: list[tuple[int, str]] = []

        for page_num, text, max_size, bold in raw_items:
            if _is_heading(text, max_size, body_size, bold):
                if current_lines:
                    draft_sections.append({"title": current_title, "lines": current_lines})
                    current_lines = []
                current_title = text[:140]
            else:
                current_lines.append((page_num, text))

        if current_lines:
            draft_sections.append({"title": current_title, "lines": current_lines})
        elif not draft_sections and raw_items:
            # Edge case: every line looked like a heading (e.g. slide titles only).
            draft_sections.append({
                "title": raw_items[0][1][:140],
                "lines": [(p, t) for p, t, _, _ in raw_items],
            })

        # Split any oversized section into bounded chunks while preserving exact page provenance.
        sections: list[CourseSection] = []
        for draft in draft_sections:
            base_title = draft["title"]
            chunk_lines: list[tuple[int, str]] = []
            chunk_chars = 0
            part = 1

            def flush_chunk(title_base: str, items: list[tuple[int, str]], part_no: int, split: bool):
                if not items or len(sections) >= MAX_SECTIONS:
                    return
                pages = sorted({p for p, _ in items})
                by_page: dict[int, list[str]] = {}
                for p, line_txt in items:
                    by_page.setdefault(p, []).append(line_txt)
                formatted = "\n\n".join(
                    f"[Page {p}]\n" + "\n".join(by_page[p]) for p in pages
                )
                label = f"{title_base} (partie {part_no})" if split else title_base
                sections.append(
                    CourseSection(
                        index=len(sections),
                        title=label[:160],
                        page_start=pages[0],
                        page_end=pages[-1],
                        pages=pages,
                        content=formatted,
                        char_count=len(formatted),
                    )
                )

            total_draft_chars = sum(len(t) + 1 for _, t in draft["lines"])
            needs_split = total_draft_chars > MAX_SECTION_CHARS
            for page_num, line_txt in draft["lines"]:
                if chunk_lines and chunk_chars + len(line_txt) + 12 > MAX_SECTION_CHARS:
                    flush_chunk(base_title, chunk_lines, part, True)
                    chunk_lines = []
                    chunk_chars = 0
                    part += 1
                chunk_lines.append((page_num, line_txt))
                chunk_chars += len(line_txt) + 1
            if chunk_lines:
                flush_chunk(base_title, chunk_lines, part, needs_split and part > 1)

        if not sections:
            raise CourseExtractionError("Impossible de découper ce support de cours en sections")

        return page_count, total_chars, sections
    finally:
        doc.close()
