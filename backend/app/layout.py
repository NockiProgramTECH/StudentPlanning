"""Read the weekly grid used in ESUPEX PDFs from PDF geometry, not text order.

When the layout cannot be reconstructed, return no cells so the normal AI flow
can interpret the extracted text instead. Never manufacture empty timetable rows.
"""
import re
import unicodedata
import pymupdf

DAYS = ("lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi")
HOUR = re.compile(r"^(\d{1,2})[Hh](\d{0,2})-(\d{1,2})[Hh](\d{0,2})$")
HEADER = re.compile(r"^L[1-9]\s*[-–]?\s*[A-Z]{2,5}$", re.I)


def normalize_class(value: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", value).upper() if c.isalnum())


def class_header(page) -> str | None:
    for line in page.get_text("text", sort=True).splitlines()[:5]:
        label = line.strip()
        if HEADER.fullmatch(label):
            return label
    return None


def _time(text: str) -> tuple[str, str] | None:
    match = HOUR.fullmatch(text.strip())
    if match is None:
        return None
    h1, m1, h2, m2 = match.groups()
    return f"{int(h1):02}:{int(m1 or 0):02}", f"{int(h2):02}:{int(m2 or 0):02}"


def _horizontal_boundaries(drawings, left, right, low, high) -> list[float]:
    values = set()
    for draw in drawings:
        rect = draw["rect"]
        if (draw.get("fill") == (0.0, 0.0, 0.0)
                and abs(rect.x0 - left) < 2 and abs(rect.x1 - right) < 2
                and rect.height < 1.2 and low - 1 <= rect.y0 <= high + 1):
            values.add(round(rect.y0, 1))
    return sorted(values)


def _line_text(words: list[tuple]) -> str:
    lines: dict[tuple[int, int], list[tuple]] = {}
    for word in words:
        lines.setdefault((word[5], word[6]), []).append(word)
    ordered = sorted(lines.values(), key=lambda line: (min(w[1] for w in line), min(w[0] for w in line)))
    return " ".join(" ".join(w[4] for w in sorted(line, key=lambda w: w[0])) for line in ordered)


def weekly_cells(page) -> list[dict]:
    """Return occupied day cells with merged-row hours, or [] if unsupported."""
    words = page.get_text("words")
    headers = {w[4].casefold(): w for w in words if w[4].casefold() in (*DAYS, "horaires")}
    if any(day not in headers for day in DAYS) or "horaires" not in headers:
        return []
    header_y = headers["horaires"][1]
    drawings = page.get_drawings()
    # This PDF draws a distinct light-grey rectangle behind each weekday label.
    header_rects = sorted((pymupdf.Rect(d["rect"]) for d in drawings
                           if d.get("fill") and d["rect"].width > 70
                           and 18 < d["rect"].height < 40
                           and abs(d["rect"].y0 - header_y) < 8
                           and abs(d["fill"][0] - d["fill"][2]) < 0.02),
                          key=lambda r: r.x0)
    if len(header_rects) != 7:
        return []
    if any(not (rect.x0 <= headers[day][0] <= rect.x1) for rect, day in zip(header_rects[1:], DAYS)):
        return []
    hours = header_rects[0]
    time_words = [(w, _time(w[4])) for w in words if hours.x0 <= (w[0]+w[2])/2 <= hours.x1]
    time_words = [(w, t) for w, t in time_words if t and w[1] > hours.y1]
    if not time_words:
        return []
    limit = max(w[3] for w, _ in time_words) + 25
    times = _horizontal_boundaries(drawings, hours.x0, hours.x1, hours.y1, limit)
    if len(times) != len(time_words) + 1:
        return []
    slots = []
    for y0, y1 in zip(times, times[1:]):
        labels = [t for w, t in time_words if y0 < (w[1] + w[3]) / 2 < y1]
        if len(labels) != 1:
            return []
        slots.append((y0, y1, *labels[0]))
    cells = []
    for day, rect in enumerate(header_rects[1:], start=1):
        bounds = _horizontal_boundaries(drawings, rect.x0, rect.x1, times[0], times[-1])
        if len(bounds) < 2 or abs(bounds[0] - times[0]) > 1 or abs(bounds[-1] - times[-1]) > 1:
            return []
        for top, bottom in zip(bounds, bounds[1:]):
            cell_words = [w for w in words if rect.x0 < (w[0]+w[2])/2 < rect.x1
                          and top < (w[1]+w[3])/2 < bottom]
            if not cell_words:
                continue
            covered = [slot for slot in slots if top <= (slot[0]+slot[1])/2 <= bottom]
            if not covered:
                return []
            cues = set()
            for block in page.get_text("dict")["blocks"]:
                for line in block.get("lines", []):
                    for span in line["spans"]:
                        bbox = pymupdf.Rect(span["bbox"])
                        if rect.x0 < (bbox.x0+bbox.x1)/2 < rect.x1 and top < (bbox.y0+bbox.y1)/2 < bottom:
                            from .extraction import _color_cue, _span_rgb
                            hue = _color_cue(_span_rgb(span["color"]))
                            if hue and span["text"].strip():
                                cues.add(f"{hue}_text")
            from .extraction import _color_cue
            for draw in drawings:
                if draw.get("fill") and (hue := _color_cue(draw["fill"])):
                    area = pymupdf.Rect(draw["rect"])
                    if area.get_area() <= pymupdf.Rect(rect.x0, top, rect.x1, bottom).get_area() * 1.1 and any(
                        area.contains(pymupdf.Point((w[0]+w[2])/2, (w[1]+w[3])/2)) for w in cell_words):
                        cues.add(f"{hue}_fill")
            cells.append({"day": day, "start": covered[0][2], "end": covered[-1][3],
                          "text": _line_text(cell_words),
                          "bbox": [round(v, 1) for v in (rect.x0, top, rect.x1, bottom)],
                          "visual_cues": sorted(cues)})
    return cells
