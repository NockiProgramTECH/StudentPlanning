from datetime import date
from typing import Literal

from pydantic import AliasChoices, BaseModel, Field, field_validator, model_validator


class Course(BaseModel):
    subject: str = Field(min_length=1, max_length=120)
    day: int = Field(ge=1, le=7, description="ISO weekday: Monday = 1")
    start: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    end: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    room: str | None = Field(default=None, max_length=100)
    teacher: str | None = Field(default=None, max_length=120)
    source_page: int | None = Field(default=None, ge=1)
    # Unknown is intentional: absence of a color never proves in-person teaching.
    kind: Literal["course", "assessment", "unknown"] = "unknown"
    delivery_mode: Literal["online", "in_person", "unknown"] = "unknown"
    needs_review: bool = False

    @model_validator(mode="after")
    def check_times(self):
        if self.start >= self.end:
            raise ValueError("L'heure de fin doit être après l'heure de début")
        return self


class Schedule(BaseModel):
    class_name: str = Field(min_length=1, max_length=100)
    week_start: date
    courses: list[Course] = Field(max_length=200)
    warnings: list[str] = Field(default_factory=list)

    @field_validator("week_start")
    @classmethod
    def monday(cls, value: date) -> date:
        if value.weekday() != 0:
            raise ValueError("week_start doit être un lundi")
        return value


class Change(BaseModel):
    type: Literal["added", "removed", "time_changed", "room_changed", "details_changed", "uncertain"]
    subject: str
    previous: Course | None = None
    current: Course | None = None
    needs_review: bool = True


class ComparisonRequest(BaseModel):
    previous: Schedule
    current: Schedule


class ImportResult(BaseModel):
    schedule: Schedule
    changes_from_previous_week: list[Change] = Field(default_factory=list)


class CourseSection(BaseModel):
    index: int = Field(ge=0)
    title: str = Field(min_length=1, max_length=160)
    page_start: int = Field(ge=1)
    page_end: int = Field(ge=1)
    pages: list[int] = Field(min_length=1)
    content: str = Field(min_length=1)
    char_count: int = Field(ge=1)
    questions_generated: int = Field(default=0, ge=0)
    questions_answered: int = Field(default=0, ge=0)
    correct_answers: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def check_pages(self):
        if self.page_start > self.page_end:
            raise ValueError("page_start doit être inférieur ou égal à page_end")
        if any(p < self.page_start or p > self.page_end for p in self.pages):
            raise ValueError("Les pages de la section doivent être comprises entre page_start et page_end")
        return self


class CourseQuestion(BaseModel):
    id: int = Field(ge=1)
    section_index: int = Field(ge=0)
    prompt: str = Field(min_length=5, max_length=500)
    choices: list[str] = Field(min_length=2, max_length=5)
    correct_index: int = Field(ge=0)
    explanation: str = Field(min_length=5, max_length=1200)
    source_page: int = Field(ge=1)
    selected_index: int | None = None
    is_correct: bool | None = None

    @model_validator(mode="after")
    def check_choice_bounds(self):
        if any(not c.strip() for c in self.choices):
            raise ValueError("Chaque proposition de réponse doit être non vide")
        if self.correct_index >= len(self.choices):
            raise ValueError("correct_index dépasse le nombre de choix")
        if self.selected_index is not None and not 0 <= self.selected_index < len(self.choices):
            raise ValueError("selected_index dépasse le nombre de choix")
        return self


class CourseProgress(BaseModel):
    total_sections: int = Field(ge=1)
    generated_sections: int = Field(default=0, ge=0)
    completed_sections: int = Field(default=0, ge=0)
    next_section_index: int | None = Field(default=0, ge=0)
    total_questions: int = Field(default=0, ge=0)
    answered_questions: int = Field(default=0, ge=0)
    correct_answers: int = Field(default=0, ge=0)
    score_percent: int = Field(default=0, ge=0, le=100)


class CourseDocumentSummary(BaseModel):
    id: str = Field(min_length=1, max_length=64)
    subject: str = Field(min_length=1, max_length=120)
    title: str = Field(min_length=1, max_length=160)
    filename: str = Field(min_length=1, max_length=200)
    page_count: int = Field(ge=1)
    total_chars: int = Field(ge=1)
    sections: list[CourseSection] = Field(min_length=1)
    progress: CourseProgress


class CourseDocumentDetail(CourseDocumentSummary):
    questions: list[CourseQuestion] = Field(default_factory=list)


class GenerateQuestionsRequest(BaseModel):
    count: int = Field(default=3, ge=1, le=5)
    regenerate: bool = False


class SectionQuestionsResponse(BaseModel):
    document_id: str
    section: CourseSection
    questions: list[CourseQuestion]
    progress: CourseProgress


class SubmitAnswerRequest(BaseModel):
    question_id: int = Field(ge=1)
    selected_index: int = Field(ge=0, le=4)


class AnswerEvaluation(BaseModel):
    document_id: str
    question_id: int
    section_index: int
    selected_index: int
    correct_index: int
    is_correct: bool
    explanation: str
    source_page: int
    progress: CourseProgress


class QuotaStatus(BaseModel):
    student_id: str
    documents_today: int = Field(ge=0)
    max_documents_per_day: int = Field(ge=1)
    quiz_requests_today: int = Field(ge=0)
    max_quiz_requests_per_day: int = Field(ge=1)
    tokens_today: int = Field(ge=0)
    max_tokens_per_day: int = Field(ge=1)
    estimated_cost_usd_month: float = Field(ge=0.0)
    max_cost_usd_per_month: float = Field(gt=0.0)


class LicenseActivationRequest(BaseModel):
    license_key: str = Field(min_length=6, max_length=254,
                             validation_alias=AliasChoices("access_code", "license_key", "email"))
    device_identifier: str | None = Field(default=None, max_length=255)


class LicenseActivationResponse(BaseModel):
    valid: bool = True
    student_id: str
    access_token: str
    masked_key: str
    status: str
    expires_at: str | None = None
    activation_count: int = 0
    max_activations: int | None = None
    activations_remaining: int | None = None
    product_name: str | None = None
    quota: QuotaStatus


class FeedbackCreateRequest(BaseModel):
    feedback_type: str = Field(default="suggestion", max_length=50)
    category: str = Field(default="autre", max_length=50)
    title: str = Field(min_length=2, max_length=200)
    description: str = Field(min_length=5, max_length=5000)
    device_context: str | None = Field(default=None, max_length=200)


class FeedbackResponse(BaseModel):
    id: int
    feedback_type: str
    category: str
    title: str
    description: str
    device_context: str | None = None
    created_at: str



