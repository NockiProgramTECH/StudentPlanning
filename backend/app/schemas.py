from datetime import date
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator


class Course(BaseModel):
    subject: str = Field(min_length=1, max_length=120)
    day: int = Field(ge=1, le=7, description="ISO weekday: Monday = 1")
    start: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    end: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    room: str | None = Field(default=None, max_length=100)
    teacher: str | None = Field(default=None, max_length=120)
    source_page: int | None = Field(default=None, ge=1)
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
