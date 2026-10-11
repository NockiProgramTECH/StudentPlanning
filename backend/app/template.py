"""Conservative parser for the observed weekly grid format.

A complete, unambiguous cell can be converted without sending its text to AI.
If any occupied cell cannot be parsed, return None and defer to the model.
"""
from datetime import date
import re
from .schemas import Course, Schedule

CELL = re.compile(r"^(?P<subject>.+?)\s*\((?P<teacher>[^()]+)\)\s*(?P<room>Salle\s+.+)?$", re.I)
DATES = re.compile(r"EMPLOI DU TEMPS DU\s+(\d{1,2})\s+au\s+(\d{1,2})[-/](\d{1,2})[-/](\d{4})", re.I)


def document_week(pages: list[dict]) -> date | None:
    for page in pages:
        for block in page["blocks"]:
            match = DATES.search(block["text"])
            if match:
                start_day, end_day, month, year = map(int, match.groups())
                try:
                    result = date(year, month, start_day)
                    if (date(year, month, end_day) - result).days == 5:
                        return result
                except ValueError:
                    pass
    return None


def parse_template(pages: list[dict], class_name: str, week_start: date) -> Schedule | None:
    if not pages or any(not page.get("cells") for page in pages):
        return None
    courses = []
    for page in pages:
        for cell in page["cells"]:
            match = CELL.fullmatch(" ".join(cell["text"].split()))
            if not match:
                return None
            subject = match["subject"].strip()
            teacher = match["teacher"].strip()
            room = match["room"].strip() if match["room"] else None
            if not subject or not teacher:
                return None
            cues = cell.get("visual_cues", [])
            explicit_exam = bool(re.search(r"\b(devoir|examen|contrôle)\b", subject, re.I))
            explicit_online = bool(re.search(r"\b(en ligne|distanciel)\b", cell["text"], re.I))
            color_exam = bool({"red_text", "red_fill"} & set(cues))
            color_online = bool({"yellow_text", "yellow_fill"} & set(cues))
            try:
                courses.append(Course(subject=subject, day=cell["day"], start=cell["start"],
                                      end=cell["end"], teacher=teacher, room=room,
                                      source_page=page["page"],
                                      kind="assessment" if explicit_exam or color_exam else "course",
                                      delivery_mode="online" if explicit_online or color_online else "unknown",
                                      needs_review=(color_exam and not explicit_exam) or (color_online and not explicit_online)))
            except ValueError:
                return None
    if not courses:
        return None
    return Schedule(class_name=class_name, week_start=week_start, courses=courses)
