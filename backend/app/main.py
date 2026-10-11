from datetime import date
import json
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import RedirectResponse
from pydantic import ValidationError
from .compare import compare
from .extraction import ExtractionError, extract_pdf
from .interpret import InterpretationError, interpret
from .schemas import ComparisonRequest, ImportResult, Schedule
from .layout import normalize_class
from .template import document_week, parse_template

app = FastAPI(title="StudentPlanning API", version="0.1.0")
MAX_PDF_BYTES = 10 * 1024 * 1024


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse("/docs")


@app.get("/health")
def health():
    return {"status": "ok"}


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
