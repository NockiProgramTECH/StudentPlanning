"""Tests for paid course-material import, section extraction, progressive OpenRouter quiz,
grading with explanations and page references, authentication and cost quotas."""
from pathlib import Path
import json
import pymupdf
import pytest
from fastapi.testclient import TestClient

from app.course_materials import MAX_COURSE_PAGES, extract_course_pdf
from app.course_quiz import CourseStore, _LLMQuestionItem
from app.chariow import normalize_chariow_license_data
from app.main import app

client = TestClient(app)
TIMETABLE_PDF = Path(__file__).with_name("Emploi_temps_12 -17-oct 2026.pdf")
VALID_TOKEN = "verified_course_test_key"
DEVICE_ID = "device_course_test_123456"
AUTH_HEADER = {"Authorization": f"Bearer {VALID_TOKEN}", "X-Device-Identifier": DEVICE_ID}


def make_course_pdf(chapters: list[tuple[str, list[str]]]) -> bytes:
    """Create a multi-page selectable-text course PDF with headings and body paragraphs."""
    doc = pymupdf.open()
    for title, paragraphs in chapters:
        page = doc.new_page()
        page.insert_text((50, 60), title, fontsize=16)
        y = 100
        for paragraph in paragraphs:
            page.insert_text((50, y), paragraph, fontsize=11)
            y += 28
    data = doc.tobytes()
    doc.close()
    return data


@pytest.fixture(params=["false", "true"], ids=["controlled", "free"])
def configured_course_env(monkeypatch, tmp_path, request):
    db_file = tmp_path / "test_courses.sqlite3"
    monkeypatch.setenv("STUDIA_DB_PATH", str(db_file))
    monkeypatch.setenv("STUDIA_FREE_ACCESS", request.param)
    monkeypatch.setenv("CHARIOW_API_KEY", "server_test_key")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "server_test_secret")
    CourseStore().upsert_chariow_license(normalize_chariow_license_data({
        "status": "active", "product": {"id": "prd_mrrhb8h2"},
    }, VALID_TOKEN))
    monkeypatch.setenv("STUDIA_MAX_DOCS_PER_DAY", "3")
    monkeypatch.setenv("STUDIA_MAX_QUIZ_REQUESTS_PER_DAY", "4")
    monkeypatch.setenv("STUDIA_MAX_TOKENS_PER_DAY", "10000")
    monkeypatch.setenv("STUDIA_MAX_COST_USD_PER_MONTH", "1.00")
    return db_file


def test_course_endpoints_require_server_configuration_and_valid_bearer_token(monkeypatch, tmp_path):
    monkeypatch.setenv("STUDIA_DB_PATH", str(tmp_path / "unauth.sqlite3"))
    monkeypatch.delenv("STUDIA_ACCESS_TOKENS", raising=False)
    unconfigured = client.get("/api/courses/quota")
    assert unconfigured.status_code == 503

    monkeypatch.setenv("CHARIOW_API_KEY", "server_test_key")
    monkeypatch.setenv("CHARIOW_PULSE_SECRET", "server_test_secret")
    # Legacy pilot credentials can no longer bypass the mandatory verification.
    monkeypatch.setenv("STUDIA_ACCESS_TOKENS", f"etudiant_l2sir:{VALID_TOKEN}")
    missing = client.get("/api/courses/quota")
    assert missing.status_code == 401
    wrong = client.get("/api/courses/quota", headers=AUTH_HEADER)
    assert wrong.status_code == 401
    record = CourseStore().upsert_chariow_license(normalize_chariow_license_data({
        "status": "active", "product": {"id": "prd_mrrhb8h2"},
    }, VALID_TOKEN))
    ok = client.get("/api/courses/quota", headers={"Authorization": f"Bearer {record['access_token']}"})
    assert ok.status_code == 200
    assert ok.json()["student_id"] == record["student_id"]


def test_timetable_pdf_is_rejected_by_course_material_importer(configured_course_env):
    response = client.post(
        "/api/courses/import",
        headers=AUTH_HEADER,
        data={"subject": "Transmission des signaux analogiques"},
        files={"file": ("emploi.pdf", TIMETABLE_PDF.read_bytes(), "application/pdf")},
    )
    assert response.status_code == 422
    assert "emploi du temps" in response.json()["detail"].lower()


def test_course_material_page_and_scan_limits(configured_course_env):
    # Scanned/empty PDF
    empty_doc = pymupdf.open()
    empty_doc.new_page()
    empty_bytes = empty_doc.tobytes()
    empty_doc.close()
    res_scan = client.post(
        "/api/courses/import",
        headers=AUTH_HEADER,
        data={"subject": "TEEO"},
        files={"file": ("scan.pdf", empty_bytes, "application/pdf")},
    )
    assert res_scan.status_code == 422
    assert "OCR" in res_scan.json()["detail"]

    # Too many pages (> 30)
    big_doc = pymupdf.open()
    for i in range(MAX_COURSE_PAGES + 1):
        big_doc.new_page().insert_text((50, 50), f"Page {i + 1} contenu de cours")
    big_bytes = big_doc.tobytes()
    big_doc.close()
    res_pages = client.post(
        "/api/courses/import",
        headers=AUTH_HEADER,
        data={"subject": "TEEO"},
        files={"file": ("trop_long.pdf", big_bytes, "application/pdf")},
    )
    assert res_pages.status_code == 422
    assert str(MAX_COURSE_PAGES) in res_pages.json()["detail"]


def test_extract_sections_progressive_quiz_grading_and_page_references(configured_course_env, monkeypatch):
    pdf = make_course_pdf([
        (
            "Chapitre 1 : Modulation d'amplitude",
            [
                "La modulation d'amplitude (AM) consiste à faire varier l'amplitude d'une porteuse.",
                "L'indice de modulation m doit rester inférieur ou égal à 1 pour éviter la surmodulation.",
            ],
        ),
        (
            "Chapitre 2 : Modulation de fréquence",
            [
                "La modulation de fréquence (FM) fait varier la fréquence instantanée de la porteuse.",
                "La bande occupée est estimée par la règle de Carson : B = 2(delta_f + f_m).",
            ],
        ),
    ])

    page_count, _, sections = extract_course_pdf(pdf)
    assert page_count == 2
    assert len(sections) == 2
    assert sections[0].title == "Chapitre 1 : Modulation d'amplitude"
    assert sections[0].pages == [1]
    assert "[Page 1]" in sections[0].content
    assert sections[1].title == "Chapitre 2 : Modulation de fréquence"
    assert sections[1].pages == [2]
    assert "[Page 2]" in sections[1].content

    imported = client.post(
        "/api/courses/import",
        headers=AUTH_HEADER,
        data={"subject": "Transmission des signaux analogiques", "title": "Polycopié Modulations"},
        files={"file": ("modulations.pdf", pdf, "application/pdf")},
    )
    assert imported.status_code == 200, imported.text
    doc_data = imported.json()
    doc_id = doc_data["id"]
    assert doc_data["progress"]["total_sections"] == 2
    assert doc_data["progress"]["generated_sections"] == 0
    assert doc_data["progress"]["next_section_index"] == 0

    sent_sections: list[int] = []

    async def fake_openrouter(*, subject: str, document_title: str, section, count: int = 3):
        # Verify progressive generation: only ONE section is sent per request.
        sent_sections.append(section.index)
        page_no = section.pages[0]
        return (
            [
                _LLMQuestionItem(
                    prompt=f"Question sur {section.title} ?",
                    choices=[
                        "Indice m <= 1 pour éviter la surmodulation",
                        "Indice m > 10 obligatoire",
                        "Fréquence nulle",
                        "Aucune porteuse",
                    ],
                    correct_index=0,
                    explanation=f"Explication détaillée issue de {section.title} (voir page {page_no}).",
                    source_page=page_no,
                )
            ],
            220,
            140,
        )

    import app.main as main_mod
    monkeypatch.setattr(main_mod, "generate_section_questions_openrouter", fake_openrouter)

    # Generate questions ONLY for section 0
    gen0 = client.post(
        f"/api/courses/{doc_id}/sections/0/questions",
        headers=AUTH_HEADER,
        json={"count": 1, "regenerate": False},
    )
    assert gen0.status_code == 200, gen0.text
    assert sent_sections == [0]
    questions0 = gen0.json()["questions"]
    assert len(questions0) == 1
    q0_id = questions0[0]["id"]
    assert questions0[0]["source_page"] == 1

    # Re-fetching section 0 without regenerate=True does NOT call OpenRouter again
    gen0_cached = client.post(
        f"/api/courses/{doc_id}/sections/0/questions",
        headers=AUTH_HEADER,
        json={"count": 1, "regenerate": False},
    )
    assert gen0_cached.status_code == 200
    assert sent_sections == [0]

    # Submit wrong answer first, then correct answer, checking explanation and page reference
    wrong_eval = client.post(
        f"/api/courses/{doc_id}/answers",
        headers=AUTH_HEADER,
        json={"question_id": q0_id, "selected_index": 2},
    )
    assert wrong_eval.status_code == 200
    w_body = wrong_eval.json()
    assert w_body["is_correct"] is False
    assert w_body["correct_index"] == 0
    assert w_body["source_page"] == 1
    assert "page 1" in w_body["explanation"].lower()
    assert w_body["progress"]["completed_sections"] == 1
    assert w_body["progress"]["score_percent"] == 0
    assert w_body["progress"]["next_section_index"] == 1

    right_eval = client.post(
        f"/api/courses/{doc_id}/answers",
        headers=AUTH_HEADER,
        json={"question_id": q0_id, "selected_index": 0},
    )
    assert right_eval.status_code == 200
    r_body = right_eval.json()
    assert r_body["is_correct"] is True
    assert r_body["progress"]["score_percent"] == 100

    # Verify progression is persisted when reloading the document
    reloaded = client.get(f"/api/courses/{doc_id}", headers=AUTH_HEADER)
    assert reloaded.status_code == 200
    detail = reloaded.json()
    assert detail["progress"]["completed_sections"] == 1
    assert detail["progress"]["next_section_index"] == 1
    assert detail["questions"][0]["selected_index"] == 0
    assert detail["questions"][0]["is_correct"] is True


def test_openrouter_invalid_page_reference_is_rejected(configured_course_env, monkeypatch):
    from app.course_quiz import generate_section_questions_openrouter
    from app.interpret import InterpretationError
    from app.schemas import CourseSection
    import httpx

    monkeypatch.setenv("OPENROUTER_API_KEY", "test-server-key-never-committed")
    section = CourseSection(
        index=0,
        title="Chapitre 1",
        page_start=2,
        page_end=2,
        pages=[2],
        content="[Page 2]\nTexte du chapitre.",
        char_count=28,
    )

    class FakeResponse:
        status_code = 200

        def raise_for_status(self):
            pass

        def json(self):
            return {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps({
                                "questions": [
                                    {
                                        "prompt": "Quelle est la formule ?",
                                        "choices": ["A", "B", "C", "D"],
                                        "correct_index": 0,
                                        "explanation": "Explication du cours.",
                                        "source_page": 99,  # Hallucinated page outside [2]
                                    }
                                ]
                            })
                        }
                    }
                ],
                "usage": {"prompt_tokens": 100, "completion_tokens": 50},
            }

    async def fake_post(self, url, **kwargs):
        return FakeResponse()

    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)
    with pytest.raises(InterpretationError, match="page"):
        import asyncio
        asyncio.run(
            generate_section_questions_openrouter(
                subject="Electronique analogique",
                document_title="Support",
                section=section,
                count=1,
            )
        )


def test_quotas_block_excessive_imports_and_ai_cost(configured_course_env, monkeypatch):
    monkeypatch.setenv("STUDIA_MAX_DOCS_PER_DAY", "1")
    pdf = make_course_pdf([("Chapitre 1 : Filtrage", ["Un filtre passe-bas atténue les hautes fréquences."])])

    first = client.post(
        "/api/courses/import",
        headers=AUTH_HEADER,
        data={"subject": "Electronique analogique"},
        files={"file": ("cours1.pdf", pdf, "application/pdf")},
    )
    assert first.status_code == 200
    doc_id = first.json()["id"]

    second = client.post(
        "/api/courses/import",
        headers=AUTH_HEADER,
        data={"subject": "Electronique analogique"},
        files={"file": ("cours2.pdf", pdf, "application/pdf")},
    )
    assert second.status_code == 429
    assert "Quota journalier" in second.json()["detail"]

    monkeypatch.setenv("STUDIA_MAX_QUIZ_REQUESTS_PER_DAY", "1")

    async def fake_openrouter(*, subject: str, document_title: str, section, count: int = 3):
        return (
            [
                _LLMQuestionItem(
                    prompt="Que fait un filtre passe-bas ?",
                    choices=["Atténue les hautes fréquences", "Amplifie tout", "Rien", "Oscille"],
                    correct_index=0,
                    explanation="Il laisse passer les basses fréquences (page 1).",
                    source_page=1,
                )
            ],
            300,
            150,
        )

    import app.main as main_mod
    monkeypatch.setattr(main_mod, "generate_section_questions_openrouter", fake_openrouter)

    q1 = client.post(
        f"/api/courses/{doc_id}/sections/0/questions",
        headers=AUTH_HEADER,
        json={"count": 1, "regenerate": True},
    )
    assert q1.status_code == 200

    q2 = client.post(
        f"/api/courses/{doc_id}/sections/0/questions",
        headers=AUTH_HEADER,
        json={"count": 1, "regenerate": True},
    )
    assert q2.status_code == 429
    assert "Quota" in q2.json()["detail"]
