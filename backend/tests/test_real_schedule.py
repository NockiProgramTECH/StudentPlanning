"""Regression tests on the school's weekly PDF, committed by the project owner."""
from pathlib import Path
import pymupdf
from fastapi.testclient import TestClient
from app.extraction import extract_pdf
from app.main import app
from app.layout import normalize_class

PDF = Path(__file__).with_name("Emploi_temps_12 -17-oct 2026.pdf")
client = TestClient(app)


def upload(klass: str, week: str = "2026-10-12", pdf: bytes | None = None):
    return client.post("/api/import", data={"class_name": klass, "week_start": week},
                       files={"file": ("emploi.pdf", pdf or PDF.read_bytes(), "application/pdf")})


def test_l2_sir_page_and_merged_slots_are_not_confused_with_l3_sir():
    pages = extract_pdf(PDF.read_bytes())
    assert len(pages) == 13
    selected = [p for p in pages if p["class_name"] and normalize_class(p["class_name"]) == "L2SIR"]
    assert [p["page"] for p in selected] == [6]
    assert len(selected[0]["cells"]) == 7
    assert {(c["day"], c["start"], c["end"]) for c in selected[0]["cells"]} == {
        (2, "07:30", "12:30"), (3, "07:30", "12:30"), (3, "14:00", "18:00"),
        (4, "07:30", "12:30"), (5, "07:30", "12:30"), (5, "14:00", "18:00"),
        (6, "07:30", "12:30"),
    }
    # Red/yellow in this PDF are on headings/footer, not inside L2 SIR lessons.
    assert all(not cell["visual_cues"] for cell in selected[0]["cells"])
    assert any("red_text" in b["visual_cues"] for b in selected[0]["blocks"])


def test_import_l2_sir_without_ai_key_returns_real_week_courses(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    response = upload("L2 SIR")
    assert response.status_code == 200, response.text
    courses = response.json()["schedule"]["courses"]
    assert len(courses) == 7
    assert all(c["source_page"] == 6 and c["kind"] == "course" and c["delivery_mode"] == "unknown"
               for c in courses)
    assert courses[0]["subject"] == "Transmission des signaux analogiques"
    assert courses[3]["subject"] == "TEEO"


def test_selected_class_and_week_are_checked_before_import():
    assert upload("L4 SIR").status_code == 422
    assert upload("L2 SIR", "2026-10-19").status_code == 422
    assert upload("L3 SIR").json()["schedule"]["courses"][0]["source_page"] == 12


def test_yellow_fill_inside_a_course_is_a_reviewable_online_hint():
    doc = pymupdf.open(PDF)
    page = doc[5]
    # Add a new background behind the Wednesday afternoon course (not footer).
    page.draw_rect(pymupdf.Rect(373.1, 288.0, 493.1, 343.3), fill=(1, 0.9, 0.6), overlay=False)
    response = upload("L2 SIR", pdf=doc.tobytes())
    doc.close()
    assert response.status_code == 200, response.text
    affected = [c for c in response.json()["schedule"]["courses"] if c["day"] == 3 and c["start"] == "14:00"]
    assert len(affected) == 1
    assert affected[0]["delivery_mode"] == "online"
    assert affected[0]["needs_review"] is True


def test_unlabeled_multipage_document_is_rejected_before_ai():
    doc = pymupdf.open()
    for _ in range(2):
        doc.new_page().insert_text((50, 50), "Texte sans classe")
    response = upload("L2 SIR", pdf=doc.tobytes())
    doc.close()
    assert response.status_code == 422
    assert "En-têtes" in response.json()["detail"]


def test_red_cue_inside_a_course_only_marks_that_course_for_review():
    from datetime import date
    from app.template import parse_template
    pages = extract_pdf(PDF.read_bytes())
    target = next(p for p in pages if p["class_name"] == "L2 SIR")
    target["cells"][0]["visual_cues"] = ["red_text"]
    schedule = parse_template([target], "L2 SIR", date(2026, 10, 12))
    assert schedule is not None
    assert schedule.courses[0].kind == "assessment"
    assert schedule.courses[0].needs_review is True
    assert all(course.kind == "course" for course in schedule.courses[1:])
