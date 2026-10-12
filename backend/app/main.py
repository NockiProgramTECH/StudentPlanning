from datetime import date
import json
from fastapi import Body, Depends, FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse, RedirectResponse
from pydantic import ValidationError
from .auth_quota import QuotaExceededError, require_student_id
from .access import free_access_enabled, portal_url, require_chariow_config
from .chariow import (
    ChariowConfigError,
    ChariowLicenseError,
    validate_or_activate_chariow_key,
    verify_chariow_pulse_signature,
)
from .compare import compare
from .course_materials import CourseExtractionError, MAX_COURSE_PDF_BYTES, extract_course_pdf
from .course_quiz import CourseStore, generate_section_questions_openrouter
from .extraction import ExtractionError, extract_pdf
from .interpret import InterpretationError, interpret
from .schemas import (
    AnswerEvaluation,
    ComparisonRequest,
    CourseDocumentDetail,
    CourseDocumentSummary,
    GenerateQuestionsRequest,
    ImportResult,
    LicenseActivationRequest,
    LicenseActivationResponse,
    QuotaStatus,
    Schedule,
    SectionQuestionsResponse,
    SubmitAnswerRequest,
)
from .layout import normalize_class
from .template import document_week, parse_template

app = FastAPI(title="StudentPlanning API", version="0.2.0")
MAX_PDF_BYTES = 10 * 1024 * 1024


def get_course_store() -> CourseStore:
    return CourseStore()


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse("/docs")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/access/config")
def access_config():
    return JSONResponse(
        {"free_access": free_access_enabled(), "portal_url": "/api/access/portal"},
        headers={"Cache-Control": "no-store"},
    )


@app.get("/api/access/portal")
def access_portal():
    return RedirectResponse(portal_url(), status_code=302, headers={"Cache-Control": "no-store"})


@app.post("/api/compare")
def compare_weeks(body: ComparisonRequest):
    try:
        return {"changes": compare(body.previous, body.current)}
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/api/import", response_model=ImportResult)
async def import_schedule(
    file: UploadFile = File(...),
    class_name: str = Form(...),
    week_start: date = Form(...),
    previous: str | None = Form(default=None),
):
    class_name = class_name.strip()
    if not 1 <= len(class_name) <= 100 or week_start.weekday() != 0:
        raise HTTPException(status_code=422, detail="Classe obligatoire (100 caractères max) et lundi requis")
    if file.content_type not in ("application/pdf", "application/octet-stream") or not (file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(status_code=415, detail="Un fichier PDF est requis")
    try:
        data = await file.read(MAX_PDF_BYTES + 1)
    finally:
        await file.close()
    if len(data) > MAX_PDF_BYTES:
        raise HTTPException(status_code=413, detail="PDF trop volumineux (10 Mo maximum)")
    if not data.startswith(b"%PDF-"):
        raise HTTPException(status_code=415, detail="Signature PDF invalide")
    try:
        old = Schedule.model_validate(json.loads(previous)) if previous else None
        if old and (old.class_name.casefold().strip() != class_name.casefold() or (week_start - old.week_start).days != 7):
            raise HTTPException(status_code=422, detail="Planning N-1 : classe ou semaine incompatible")
    except (json.JSONDecodeError, ValidationError) as exc:
        raise HTTPException(status_code=422, detail="Planning N-1 invalide") from exc
    try:
        pages = extract_pdf(data)
        labeled = [page for page in pages if page["class_name"]]
        selected = [page for page in labeled if normalize_class(page["class_name"]) == normalize_class(class_name)]
        if labeled and not selected:
            raise HTTPException(status_code=422, detail=f"Classe {class_name} introuvable dans le PDF")
        # A multipage PDF with unknown class headers must not leak other classes to AI.
        if not labeled and len(pages) > 1:
            raise HTTPException(status_code=422, detail="En-têtes des classes introuvables dans ce PDF multipage")
        selected = selected or pages
        pdf_week = document_week(selected)
        if pdf_week is not None and pdf_week != week_start:
            raise HTTPException(status_code=422, detail=f"Semaine du PDF : {pdf_week} ; semaine choisie : {week_start}")
        schedule = parse_template(selected, class_name, week_start) if labeled else None
        if schedule is None:
            # Only selected pages (or a single unlabeled page) are sent to OpenRouter.
            model_pages = [{"page": p["page"], "class_name": p["class_name"], "cells": p["cells"],
                            "blocks": [] if p["cells"] else p["blocks"]} for p in selected]
            schedule = await interpret(model_pages, class_name, str(week_start))
        return ImportResult(schedule=schedule, changes_from_previous_week=compare(old, schedule) if old else [])
    except ExtractionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except InterpretationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/api/courses/quota", response_model=QuotaStatus)
def get_course_quota(
    student_id: str = Depends(require_student_id),
    store: CourseStore = Depends(get_course_store),
):
    return store.quota_status(student_id)


@app.get("/api/courses", response_model=list[CourseDocumentSummary])
def list_course_documents(
    student_id: str = Depends(require_student_id),
    store: CourseStore = Depends(get_course_store),
):
    return store.list_documents(student_id)


@app.post("/api/courses/import", response_model=CourseDocumentSummary)
async def import_course_material(
    file: UploadFile = File(...),
    subject: str = Form(...),
    title: str | None = Form(default=None),
    student_id: str = Depends(require_student_id),
    store: CourseStore = Depends(get_course_store),
):
    subject = subject.strip()
    if not 1 <= len(subject) <= 120:
        raise HTTPException(status_code=422, detail="Matière obligatoire (120 caractères max)")
    filename = (file.filename or "").strip()
    if file.content_type not in ("application/pdf", "application/octet-stream") or not filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=415, detail="Un support de cours au format PDF est requis")
    try:
        data = await file.read(MAX_COURSE_PDF_BYTES + 1)
    finally:
        await file.close()
    if len(data) > MAX_COURSE_PDF_BYTES:
        raise HTTPException(status_code=413, detail="Support PDF trop volumineux (10 Mo maximum)")
    if not data.startswith(b"%PDF-"):
        raise HTTPException(status_code=415, detail="Signature PDF invalide")

    try:
        store.check_import_quota(student_id)
        page_count, total_chars, sections = extract_course_pdf(data)
        doc_title = (title or "").strip() or filename[:-4].replace("_", " ").strip() or subject
        return store.create_document(
            student_id=student_id,
            subject=subject,
            title=doc_title[:160],
            filename=filename[:200],
            page_count=page_count,
            total_chars=total_chars,
            sections=sections,
        )
    except QuotaExceededError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except CourseExtractionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.get("/api/courses/{doc_id}", response_model=CourseDocumentDetail)
def get_course_document(
    doc_id: str,
    student_id: str = Depends(require_student_id),
    store: CourseStore = Depends(get_course_store),
):
    try:
        return store.get_document(student_id, doc_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc.args[0])) from exc


@app.post(
    "/api/courses/{doc_id}/sections/{section_index}/questions",
    response_model=SectionQuestionsResponse,
)
async def generate_section_questions(
    doc_id: str,
    section_index: int,
    body: GenerateQuestionsRequest = Body(default_factory=GenerateQuestionsRequest),
    student_id: str = Depends(require_student_id),
    store: CourseStore = Depends(get_course_store),
):
    try:
        detail = store.get_document(student_id, doc_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc.args[0])) from exc

    section = next((s for s in detail.sections if s.index == section_index), None)
    if section is None:
        raise HTTPException(status_code=404, detail="Section introuvable dans ce support de cours")

    existing = [q for q in detail.questions if q.section_index == section_index]
    if existing and not body.regenerate:
        return SectionQuestionsResponse(
            document_id=doc_id,
            section=section,
            questions=existing,
            progress=detail.progress,
        )

    try:
        store.check_quiz_quota(student_id, section.char_count)
        generated, prompt_tokens, completion_tokens = await generate_section_questions_openrouter(
            subject=detail.subject,
            document_title=detail.title,
            section=section,
            count=body.count,
        )
        return store.save_section_questions(
            student_id=student_id,
            doc_id=doc_id,
            section_index=section_index,
            items=generated,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            replace=True,
        )
    except QuotaExceededError as exc:
        raise HTTPException(status_code=429, detail=str(exc)) from exc
    except InterpretationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.post("/api/courses/{doc_id}/answers", response_model=AnswerEvaluation)
def submit_course_answer(
    doc_id: str,
    body: SubmitAnswerRequest,
    student_id: str = Depends(require_student_id),
    store: CourseStore = Depends(get_course_store),
):
    try:
        return store.submit_answer(
            student_id=student_id,
            doc_id=doc_id,
            question_id=body.question_id,
            selected_index=body.selected_index,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc.args[0])) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/api/access/activate", response_model=LicenseActivationResponse)
@app.post("/api/licenses/activate", response_model=LicenseActivationResponse)
async def activate_license(
    body: LicenseActivationRequest,
    store: CourseStore = Depends(get_course_store),
):
    require_chariow_config()
    key = body.license_key.strip()
    device = (body.device_identifier or "").strip() or None
    if "@" in key:
        key = store.license_key_for_email(key)
        if not key:
            raise HTTPException(403, "Accès non reconnu. Utilisez le code reçu ou réessayez plus tard.")

    cached = store.get_cached_license(key)
    if cached and (int(cached["is_revoked"]) == 1 or cached["status"] == "revoked"):
        raise HTTPException(status_code=403, detail="Cette licence Chariow a été révoquée.")

    try:
        already_on_device = store.has_device_activation(key, device)
        info = await validate_or_activate_chariow_key(
            key,
            device,
            already_activated_on_device=already_on_device,
        )
        record = store.upsert_chariow_license(info, device_identifier=device)
        student_id = str(record["student_id"])
        return LicenseActivationResponse(
            valid=True,
            student_id=student_id,
            access_token=str(record["access_token"]),
            masked_key=str(record["masked_key"]),
            status=str(record["status"]),
            expires_at=record.get("expires_at"),
            activation_count=int(record.get("activation_count") or 0),
            max_activations=record.get("max_activations"),
            activations_remaining=record.get("activations_remaining"),
            product_name=record.get("product_name"),
            quota=store.quota_status(student_id),
        )
    except ChariowConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ChariowLicenseError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.detail) from exc


@app.post("/api/webhooks/chariow")
async def chariow_pulse_webhook(
    request: Request,
    x_chariow_signature: str | None = Header(default=None),
    x_pulse_id: str | None = Header(default=None),
    x_pulse_delivery_id: str | None = Header(default=None),
    x_pulse_event: str | None = Header(default=None),
    store: CourseStore = Depends(get_course_store),
):
    raw_body = await request.body()
    try:
        valid_sig = verify_chariow_pulse_signature(raw_body, x_chariow_signature)
    except ChariowConfigError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    if not valid_sig:
        raise HTTPException(status_code=401, detail="Signature Chariow Pulse invalide")

    try:
        payload = json.loads(raw_body.decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("Payload JSON objet attendu")
    except Exception as exc:
        raise HTTPException(status_code=422, detail="Corps JSON Pulse invalide") from exc

    event = (x_pulse_event or str(payload.get("event") or "")).strip()
    if not event:
        raise HTTPException(status_code=422, detail="Événement Pulse manquant")

    return store.process_chariow_pulse(
        delivery_id=x_pulse_delivery_id,
        pulse_id=x_pulse_id,
        event=event,
        payload=payload,
    )


