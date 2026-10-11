"""Conservative one-to-one matching; differences are suggestions, not facts."""
import unicodedata
from .schemas import Change, Course, Schedule


def _norm(value: str | None) -> str:
    text = unicodedata.normalize("NFKD", value or "")
    return " ".join("".join(c for c in text if not unicodedata.combining(c)).casefold().split())


def _minutes(value: str) -> int:
    hour, minute = map(int, value.split(":"))
    return hour * 60 + minute


def _score(old: Course, new: Course) -> int:
    if _norm(old.subject) != _norm(new.subject):
        return -1
    score = 4
    if old.day == new.day:
        score += 3
    if old.teacher and new.teacher and _norm(old.teacher) == _norm(new.teacher):
        score += 2
    if old.room and new.room and _norm(old.room) == _norm(new.room):
        score += 1
    if abs(_minutes(old.start) - _minutes(new.start)) <= 60:
        score += 2
    return score


def compare(previous: Schedule, current: Schedule) -> list[Change]:
    if _norm(previous.class_name) != _norm(current.class_name):
        raise ValueError("Les classes des deux plannings sont différentes")
    if (current.week_start - previous.week_start).days != 7:
        raise ValueError("La comparaison nécessite deux semaines consécutives")

    # Match globally by best score rather than greedily consuming repeated subjects.
    pairs = sorted(
        [(_score(old, new), i, j) for i, old in enumerate(previous.courses)
         for j, new in enumerate(current.courses)], reverse=True
    )
    old_used: set[int] = set()
    new_used: set[int] = set()
    changes: list[Change] = []
    for score, i, j in pairs:
        if score < 6 or i in old_used or j in new_used:
            continue
        old_used.add(i)
        new_used.add(j)
        old, new = previous.courses[i], current.courses[j]
        # Low confidence or ambiguous matches should not be described as definitive moves.
        tied = sum(1 for s, x, y in pairs if s == score and (x == i or y == j)) > 1
        if tied or old.needs_review or new.needs_review:
            changes.append(Change(type="uncertain", subject=new.subject, previous=old, current=new))
            continue
        if old.day != new.day or old.start != new.start or old.end != new.end:
            kind = "time_changed"
        elif old.room and new.room and _norm(old.room) != _norm(new.room):
            kind = "room_changed"
        elif old.teacher and new.teacher and _norm(old.teacher) != _norm(new.teacher):
            kind = "details_changed"
        elif old.kind != "unknown" and new.kind != "unknown" and old.kind != new.kind:
            kind = "details_changed"
        elif old.delivery_mode != "unknown" and new.delivery_mode != "unknown" and old.delivery_mode != new.delivery_mode:
            kind = "details_changed"
        else:
            continue
        changes.append(Change(type=kind, subject=new.subject, previous=old, current=new))
    # An unmatched course with the same subject on both sides could be a move;
    # do not claim a deletion + addition without enough evidence.
    for i, old in enumerate(previous.courses):
        if i in old_used:
            continue
        candidates = [j for j, new in enumerate(current.courses)
                      if j not in new_used and _norm(old.subject) == _norm(new.subject)]
        if candidates:
            j = max(candidates, key=lambda j: _score(old, current.courses[j]))
            old_used.add(i)
            new_used.add(j)
            changes.append(Change(type="uncertain", subject=old.subject,
                                  previous=old, current=current.courses[j]))
    for i, old in enumerate(previous.courses):
        if i not in old_used:
            changes.append(Change(type="removed", subject=old.subject, previous=old))
    for j, new in enumerate(current.courses):
        if j not in new_used:
            changes.append(Change(type="added", subject=new.subject, current=new))
    return changes
