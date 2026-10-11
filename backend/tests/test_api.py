from datetime import date
import pymupdf
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.compare import compare
from app.schemas import Course, Schedule

client = TestClient(app)


def schedule(week, courses):
    return Schedule(class_name="L2 Info", week_start=date.fromisoformat(week), courses=courses)


def course(**kwargs):
    return Course(subject="Maths", day=1, start="08:00", end="10:00", **kwargs)


def test_comparison_detects_room_change_and_retains_previous():
    old = schedule("2026-10-05", [course(room="A10")])
    new = schedule("2026-10-12", [course(room="B12")])
    result = compare(old, new)
    assert [c.type for c in result] == ["room_changed"]
    assert old.courses[0].room == "A10"


def test_comparison_rejects_unrelated_weeks():
    with pytest.raises(ValueError):
        compare(schedule("2026-10-05", []), schedule("2026-10-19", []))


def test_comparison_repeated_courses_do_not_disappear():
    old = schedule("2026-10-05", [course(), Course(subject="Maths", day=3, start="08:00", end="10:00")])
    new = schedule("2026-10-12", [course()])
    assert [c.type for c in compare(old, new)] == ["removed"]


def test_pdf_validation():
    params = {"class_name": "L2 Info", "week_start": "2026-10-12"}
    invalid = client.post("/api/import", data=params, files={"file": ("test.pdf", b"not a pdf", "application/pdf")})
    assert invalid.status_code == 415
    doc = pymupdf.open()
    page = doc.new_page()
    page.insert_text((70, 70), "Maths L2 Info 08:00")
    pdf = doc.tobytes()
    doc.close()
    no_key = client.post("/api/import", data=params, files={"file": ("test.pdf", pdf, "application/pdf")})
    assert no_key.status_code == 503
    assert "OPENROUTER_API_KEY" in no_key.json()["detail"]


def test_health_and_openapi_available_without_ai_key(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert client.get("/openapi.json").status_code == 200


def test_compare_endpoint():
    body = {"previous": schedule("2026-10-05", [course()]).model_dump(mode="json"),
            "current": schedule("2026-10-12", [Course(subject="Maths", day=1, start="09:00", end="10:00")]).model_dump(mode="json")}
    response = client.post("/api/compare", json=body)
    assert response.status_code == 200
    assert response.json()["changes"][0]["type"] == "time_changed"


def test_import_happy_path_never_persists_before_review(monkeypatch):
    import app.main as main

    async def fake_interpret(pages, class_name, week_start):
        assert pages[0]["blocks"][0]["text"].startswith("Maths")
        assert class_name == "L2 Info"
        return schedule(week_start, [course(room="B12", source_page=1)])

    monkeypatch.setattr(main, "interpret", fake_interpret)
    doc = pymupdf.open()
    doc.new_page().insert_text((70, 70), "Maths L2 Info 08:00")
    pdf = doc.tobytes()
    doc.close()
    old = schedule("2026-10-05", [course(room="A10")])
    response = client.post("/api/import", data={
        "class_name": "L2 Info", "week_start": "2026-10-12",
        "previous": old.model_dump_json(),
    }, files={"file": ("semaine.pdf", pdf, "application/pdf")})
    assert response.status_code == 200
    assert response.json()["schedule"]["courses"][0]["source_page"] == 1
    assert response.json()["changes_from_previous_week"][0]["type"] == "room_changed"


def test_scanned_pdf_is_rejected():
    doc = pymupdf.open()
    doc.new_page()
    pdf = doc.tobytes()
    doc.close()
    response = client.post("/api/import", data={"class_name": "L2 Info", "week_start": "2026-10-12"},
                           files={"file": ("scan.pdf", pdf, "application/pdf")})
    assert response.status_code == 422
    assert "OCR" in response.json()["detail"]


def test_distant_course_with_same_subject_is_uncertain_not_added_and_removed():
    old = schedule("2026-10-05", [course()])
    new = schedule("2026-10-12", [Course(subject="Maths", day=5, start="16:00", end="18:00")])
    assert [c.type for c in compare(old, new)] == ["uncertain"]


def test_comparison_detects_change_from_course_to_assessment():
    old = schedule("2026-10-05", [course(kind="course")])
    new = schedule("2026-10-12", [course(kind="assessment")])
    assert [change.type for change in compare(old, new)] == ["details_changed"]
