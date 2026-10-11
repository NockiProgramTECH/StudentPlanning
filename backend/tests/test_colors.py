"""Synthetic color tests; replace with real timetable tests when an accessible PDF is available."""
import pymupdf
from app.extraction import extract_pdf
from app.schemas import Course


def test_red_text_and_yellow_cell_are_separate_visual_cues():
    doc = pymupdf.open()
    page = doc.new_page()
    page.draw_rect(pymupdf.Rect(50, 120, 280, 175), fill=(1, 0.95, 0.05), color=(0, 0, 0))
    page.insert_text((60, 70), "DEVOIR RESEAUX", color=(0.9, 0.05, 0.05))
    page.insert_text((60, 145), "Bases de donnees en ligne", color=(0, 0, 0))
    pdf = doc.tobytes()
    doc.close()
    blocks = extract_pdf(pdf)[0]["blocks"]
    assert "red_text" in next(b for b in blocks if "DEVOIR" in b["text"])["visual_cues"]
    assert "yellow_fill" in next(b for b in blocks if "Bases" in b["text"])["visual_cues"]
    assert "yellow_fill" not in next(b for b in blocks if "DEVOIR" in b["text"])["visual_cues"]


def test_unknown_semantics_are_not_inferred_when_color_missing():
    course = Course(subject="Maths", day=1, start="08:00", end="10:00")
    assert course.kind == "unknown"
    assert course.delivery_mode == "unknown"


def test_colored_cell_is_not_automatically_classified_as_a_devoir():
    # Extraction returns evidence; Pydantic never assigns semantics from color alone.
    doc = pymupdf.open()
    page = doc.new_page()
    page.draw_rect(pymupdf.Rect(50, 50, 260, 110), fill=(0.95, 0.08, 0.08))
    page.insert_text((60, 75), "Controle continu")
    blocks = extract_pdf(doc.tobytes())[0]["blocks"]
    doc.close()
    assert "red_fill" in blocks[0]["visual_cues"]
    assert Course(subject=blocks[0]["text"], day=1, start="08:00", end="10:00").kind == "unknown"
