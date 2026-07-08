"""Extract EFE/SSU offerings from UP PDF + SSU Excel files.

The 2026-II EFE PDFs use a compact table format where the third column is
either a weekday, an exact date, or INICIO/FIN for SSU and travel-style
experiences. This script keeps the raw EFE structure and enriches SSU sections
with the dated activities from the Excel workbook.
"""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from datetime import date, datetime, time
from pathlib import Path
from typing import Any

BASE_DIR = Path(__file__).resolve().parent.parent.parent
DEFAULT_CYCLE = "2026-2"
DEFAULT_EFE_DIR = BASE_DIR / "pdfs" / "matricula" / DEFAULT_CYCLE / "EFEs"
DEFAULT_PDF = DEFAULT_EFE_DIR / "Horarios-ofertados-matricula-2026-II-planes-antiguos.pdf"
DEFAULT_XLSX = DEFAULT_EFE_DIR / "Sesiones SSU 2026-II.xlsx"
DEFAULT_OUT = DEFAULT_EFE_DIR / "efe_ssu_2026-2_v1.json"

COURSE_CODE_RE = re.compile(r"^(\d{5,7}[A-Z_]*)\s*[-\u2013]\s*(.+)", re.DOTALL)
SECTION_RE = re.compile(r"^[A-Z]\d?$")
TIME_RE = re.compile(r"^\d{1,2}:\d{2}")

MONTH_ES = {
    "ENE": 1,
    "FEB": 2,
    "MAR": 3,
    "ABR": 4,
    "MAY": 5,
    "JUN": 6,
    "JUL": 7,
    "AGO": 8,
    "SEP": 9,
    "OCT": 10,
    "NOV": 11,
    "DIC": 12,
}
WEEKDAY_ES = ["LUN", "MAR", "MIE", "JUE", "VIE", "SAB", "DOM"]
WEEKDAY_SET = set(WEEKDAY_ES)


def _strip_accents(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def _norm(value: Any) -> str:
    return _strip_accents(str(value or "")).upper().strip()


def _cell(value: Any) -> str:
    if value is None:
        return ""
    return str(value).replace("\r", "\n").strip()


def _text(value: Any) -> str:
    return re.sub(r"\s+", " ", _cell(value)).strip()


def _clean_detail(value: str) -> str:
    if not value:
        return ""
    cleaned = re.sub(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]", "", value)
    return _text(cleaned)


def _split_people(value: str) -> list[str]:
    people: list[str] = []
    for part in re.split(r"\n+", value or ""):
        person = _text(part)
        if person:
            people.append(person)
    return people


def _parse_cycle_year(cycle: str) -> int:
    match = re.match(r"^(\d{4})-", cycle)
    return int(match.group(1)) if match else date.today().year


def _parse_cupos(value: Any) -> int | None:
    raw = _text(value)
    if not raw:
        return None
    match = re.search(r"\d+", raw)
    return int(match.group(0)) if match else None


def _parse_time(value: Any) -> str | None:
    if value is None:
        return None
    if isinstance(value, time):
        return value.strftime("%H:%M")
    if isinstance(value, datetime):
        return value.strftime("%H:%M")
    raw = _text(value)
    match = TIME_RE.match(raw)
    if not match:
        return None
    hour, minute = match.group(0).split(":")
    return f"{int(hour):02d}:{minute}"


def _parse_date(value: Any, year: int) -> str | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, date):
        return value.isoformat()

    raw = _text(value)
    if not raw:
        return None

    for fmt in ("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d"):
        try:
            return datetime.strptime(raw, fmt).date().isoformat()
        except ValueError:
            pass

    match = re.match(r"^(\d{1,2})[-/ ]([A-Za-z\u00C0-\u017F]{3})$", raw)
    if match:
        day = int(match.group(1))
        month = MONTH_ES.get(_norm(match.group(2))[:3])
        if month:
            return date(year, month, day).isoformat()
    return None


def _weekday_for_date(iso_date: str) -> str:
    parsed = datetime.strptime(iso_date, "%Y-%m-%d").date()
    return WEEKDAY_ES[parsed.weekday()]


def _parse_creditos(heading: str, default: str = "1") -> str:
    norm = _norm(heading)
    if "SIN CREDITO" in norm:
        return "0"
    if "DOS CREDIT" in norm:
        return "2"
    if "UN CREDIT" in norm:
        return "1"
    return default


def _heading_text(value: str) -> str:
    for line in value.splitlines():
        if "CREDITO" in _norm(line):
            return _text(line)
    return _text(value)


def _parse_course_cell(value: str) -> tuple[str, str, str | None] | None:
    lines = [_text(line) for line in value.splitlines() if _text(line)]
    for idx, line in enumerate(lines):
        match = COURSE_CODE_RE.match(line)
        if not match:
            continue
        name_parts = [_text(match.group(2))]
        prereq_parts = lines[:idx]
        for extra in lines[idx + 1 :]:
            norm = _norm(extra)
            if "REQUISITO" in norm or ("CREDITO" in norm and "ACUMULAD" in norm):
                prereq_parts.append(extra)
            else:
                name_parts.append(extra)
        prereq = " ".join(prereq_parts).strip() or None
        return match.group(1), _text(" ".join(name_parts)), prereq
    return None


def _is_table_header(cells: list[str]) -> bool:
    first = _norm(cells[0] if cells else "")
    return first in {"SECC", "SECC."} or first.startswith("FACILITADOR")


def _is_heading(cells: list[str]) -> bool:
    non_empty = [_text(c) for c in cells if _text(c)]
    if len(non_empty) != 1:
        return False
    raw = non_empty[0]
    norm = _norm(raw)
    if COURSE_CODE_RE.match(raw) or SECTION_RE.match(raw):
        return False
    if "ACUMULAD" in norm or norm.startswith("IMPORTANTE"):
        return False
    if "CREDITO" not in norm:
        return False
    return norm.startswith("EFE ") or "ARTE" in norm or "COMPETENCIAS" in norm


def _is_prereq_row(cells: list[str]) -> bool:
    non_empty = [_text(c) for c in cells if _text(c)]
    if len(non_empty) != 1:
        return False
    norm = _norm(non_empty[0])
    return "REQUISITO" in norm or "CREDITO" in norm and "ACUMULAD" in norm


def _parse_session_marker(value: Any, year: int) -> tuple[str, str | None]:
    raw = _text(value)
    norm = _norm(raw)
    if norm in WEEKDAY_SET:
        return norm, None
    iso_date = _parse_date(raw, year)
    if iso_date:
        return _weekday_for_date(iso_date), iso_date
    return raw, None


def _load_excel(xlsx_path: Path) -> dict[str, dict[str, list[dict[str, Any]]]]:
    """Return {codigo: {seccion: [{fecha, dia, tipo, hora_inicio, hora_fin}]}}."""
    import openpyxl

    wb = openpyxl.load_workbook(str(xlsx_path), data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))

    header_idx = None
    for idx, row in enumerate(rows):
        if any("COD" in _norm(cell) for cell in row):
            header_idx = idx
            break
    if header_idx is None:
        print("[Excel] WARNING: header row not found; Excel skipped.")
        return {}

    header = [_norm(cell) for cell in rows[header_idx]]

    def col(*patterns: str) -> int:
        for pattern in patterns:
            regex = re.compile(pattern)
            for idx, name in enumerate(header):
                if regex.search(name):
                    return idx
        raise KeyError(patterns)

    try:
        i_cod = col(r"COD")
        i_sec = col(r"SECC")
        i_fecha = col(r"FECHA")
        i_tipo = col(r"ACTIVIDAD", r"SESION", r"TIPO")
        i_inicio = col(r"INICIO", r"H.*INI")
        i_fin = col(r"FIN", r"H.*FIN")
    except KeyError as exc:
        print(f"[Excel] WARNING: missing column {exc}; Excel skipped.")
        return {}

    result: dict[str, dict[str, list[dict[str, Any]]]] = defaultdict(lambda: defaultdict(list))
    total = skipped = 0
    for row in rows[header_idx + 1 :]:
        codigo = _text(row[i_cod] if i_cod < len(row) else "")
        if not re.match(r"^\d{5,7}$", codigo):
            continue
        fecha = _parse_date(row[i_fecha] if i_fecha < len(row) else None, date.today().year)
        if not fecha:
            skipped += 1
            continue
        seccion = _text(row[i_sec] if i_sec < len(row) else "")
        total += 1
        result[codigo][seccion].append(
            {
                "fecha": fecha,
                "dia": _weekday_for_date(fecha),
                "tipo": _text(row[i_tipo] if i_tipo < len(row) else ""),
                "hora_inicio": _parse_time(row[i_inicio] if i_inicio < len(row) else None) or "",
                "hora_fin": _parse_time(row[i_fin] if i_fin < len(row) else None) or "",
            }
        )

    for by_section in result.values():
        for sessions in by_section.values():
            sessions.sort(key=lambda item: (item["fecha"], item["hora_inicio"], item["hora_fin"]))

    print(f"[Excel] {total} session rows | {len(result)} cursos | {skipped} skipped")
    return {codigo: dict(sections) for codigo, sections in result.items()}


def _new_section(cells: list[str], year: int) -> dict[str, Any] | None:
    seccion = _text(cells[0] if len(cells) > 0 else "")
    facilitadores = _split_people(cells[1] if len(cells) > 1 else "")
    marker = _text(cells[2] if len(cells) > 2 else "")
    marker_norm = _norm(marker)

    if marker_norm in {"INICIO", "FIN"}:
        fecha = _parse_date(cells[3] if len(cells) > 3 else "", year)
        section = {
            "seccion": seccion,
            "facilitadores": facilitadores,
            "cupos": _parse_cupos(cells[5] if len(cells) > 5 else None),
            "tipo_sesion": "INICIO_FIN",
            "fecha_inicio": fecha if marker_norm == "INICIO" else None,
            "fecha_fin": fecha if marker_norm == "FIN" else None,
            "detalle": _clean_detail(cells[6] if len(cells) > 6 else ""),
            "sesiones_por_dia": [],
        }
        return section

    dia, fecha = _parse_session_marker(marker, year)
    hora_inicio = _parse_time(cells[3] if len(cells) > 3 else None)
    hora_fin = _parse_time(cells[4] if len(cells) > 4 else None)
    section = {
        "seccion": seccion,
        "facilitadores": facilitadores,
        "cupos": _parse_cupos(cells[5] if len(cells) > 5 else None),
        "tipo_sesion": "CLASE",
        "detalle": _clean_detail(cells[6] if len(cells) > 6 else ""),
        "sesiones": [],
    }
    if dia and hora_inicio and hora_fin:
        session = {"dia": dia, "hora_inicio": hora_inicio, "hora_fin": hora_fin}
        if fecha:
            session["fecha"] = fecha
        section["sesiones"].append(session)
    return section


def _append_continuation(section: dict[str, Any], cells: list[str], year: int) -> None:
    marker = _text(cells[2] if len(cells) > 2 else "")
    marker_norm = _norm(marker)
    if not marker:
        return

    if marker_norm == "FIN" and section.get("tipo_sesion") == "INICIO_FIN":
        section["fecha_fin"] = _parse_date(cells[3] if len(cells) > 3 else "", year)
        return
    if marker_norm == "INICIO" and section.get("tipo_sesion") == "INICIO_FIN":
        section["fecha_inicio"] = _parse_date(cells[3] if len(cells) > 3 else "", year)
        return

    if section.get("tipo_sesion") != "CLASE":
        return

    dia, fecha = _parse_session_marker(marker, year)
    hora_inicio = _parse_time(cells[3] if len(cells) > 3 else None)
    hora_fin = _parse_time(cells[4] if len(cells) > 4 else None)
    if dia and hora_inicio and hora_fin:
        session = {"dia": dia, "hora_inicio": hora_inicio, "hora_fin": hora_fin}
        if fecha:
            session["fecha"] = fecha
        section.setdefault("sesiones", []).append(session)


def _load_pdf(pdf_path: Path, cycle: str) -> list[dict[str, Any]]:
    import pdfplumber

    year = _parse_cycle_year(cycle)
    courses: list[dict[str, Any]] = []
    current_type = ""
    current_creditos = "1"
    current_prereq: str | None = None
    current_course: dict[str, Any] | None = None
    current_section: dict[str, Any] | None = None

    with pdfplumber.open(str(pdf_path)) as pdf:
        for page in pdf.pages:
            for table in page.find_tables():
                for row in table.extract():
                    cells = [_cell(value) for value in row]
                    while cells and not _text(cells[-1]):
                        cells.pop()
                    if not cells or not any(_text(c) for c in cells):
                        continue

                    if _is_table_header(cells):
                        continue
                    if _is_heading(cells):
                        current_type = _heading_text(cells[0])
                        current_creditos = _parse_creditos(current_type, current_creditos)
                        current_prereq = None
                        current_course = None
                        current_section = None
                        continue

                    col0 = _text(cells[0])
                    parsed_course = _parse_course_cell(cells[0])
                    if parsed_course:
                        codigo, nombre, inline_prereq = parsed_course
                        current_course = {
                            "codigo": codigo,
                            "nombre": nombre,
                            "tipo_efe": current_type,
                            "creditos": current_creditos,
                            "prerequisitos": inline_prereq or current_prereq,
                            "secciones": [],
                        }
                        courses.append(current_course)
                        current_prereq = None
                        current_section = None
                        continue

                    if _is_prereq_row(cells):
                        current_prereq = _text(cells[0])
                        continue

                    if current_course is None:
                        continue

                    if SECTION_RE.match(col0):
                        section = _new_section(cells, year)
                        if section is None:
                            continue
                        existing = next(
                            (
                                item
                                for item in current_course["secciones"]
                                if item["seccion"] == section["seccion"]
                            ),
                            None,
                        )
                        if existing is None:
                            current_course["secciones"].append(section)
                            current_section = section
                        else:
                            if section.get("facilitadores"):
                                known = set(existing.get("facilitadores", []))
                                for person in section["facilitadores"]:
                                    if person not in known:
                                        existing.setdefault("facilitadores", []).append(person)
                            if section.get("tipo_sesion") == "CLASE":
                                existing.setdefault("sesiones", []).extend(section.get("sesiones", []))
                            if section.get("fecha_inicio"):
                                existing["fecha_inicio"] = section["fecha_inicio"]
                            if section.get("fecha_fin"):
                                existing["fecha_fin"] = section["fecha_fin"]
                            current_section = existing
                        continue

                    if not col0 and current_section is not None:
                        _append_continuation(current_section, cells, year)

    print(f"[PDF] {len(courses)} cursos extraidos.")
    by_type: dict[str, int] = defaultdict(int)
    for course in courses:
        by_type[course["tipo_efe"]] += 1
    for heading, count in by_type.items():
        print(f"  {count:3d}  {heading}")
    return courses


def _merge_excel(courses: list[dict[str, Any]], excel: dict[str, dict[str, list[dict[str, Any]]]]) -> None:
    for course in courses:
        by_section = excel.get(course["codigo"])
        if not by_section:
            continue
        for section in course.get("secciones", []):
            if section.get("tipo_sesion") != "INICIO_FIN":
                continue
            flat_sessions = by_section.get(section["seccion"], [])
            if not flat_sessions and len(by_section) == 1:
                flat_sessions = next(iter(by_section.values()))
            if not flat_sessions:
                continue

            grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
            for item in flat_sessions:
                grouped[item["fecha"]].append(
                    {
                        "tipo": item["tipo"],
                        "hora_inicio": item["hora_inicio"],
                        "hora_fin": item["hora_fin"],
                    }
                )
            section["sesiones_por_dia"] = [
                {"fecha": fecha, "dia": _weekday_for_date(fecha), "sesiones": grouped[fecha]}
                for fecha in sorted(grouped)
            ]


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Extract EFE/SSU data from PDF and Excel.")
    parser.add_argument("--cycle", default=DEFAULT_CYCLE)
    parser.add_argument("--pdf", type=Path, default=DEFAULT_PDF)
    parser.add_argument("--xlsx", type=Path, default=DEFAULT_XLSX)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--version", default="v1")
    parser.add_argument("--fecha-version", default="07/07/2026")
    parser.add_argument("--descripcion", default=None)
    return parser


def main() -> None:
    args = _build_parser().parse_args()
    descripcion = args.descripcion
    if descripcion is None:
        plan = "Planes Antiguos" if "antiguos" in args.pdf.name.lower() else "Planes Actuales"
        descripcion = f"Experiencias Formativas Estudiantiles - {plan} {args.cycle}"

    print("=== EFE/SSU Extractor ===")
    print(f"PDF:   {args.pdf}")
    print(f"Excel: {args.xlsx}")
    print(f"Out:   {args.out}")
    print()

    print("[1/3] Parsing Excel (SSU sessions)...")
    excel = _load_excel(args.xlsx)

    print("\n[2/3] Parsing PDF (EFE offerings)...")
    courses = _load_pdf(args.pdf, args.cycle)

    print("\n[3/3] Merging Excel SSU sessions...")
    _merge_excel(courses, excel)

    data = {
        "metadata": {
            "ciclo": args.cycle,
            "version": args.version,
            "fecha_version": args.fecha_version,
            "descripcion": descripcion,
            "fecha_extraccion": date.today().isoformat(),
            "fuente_pdf": args.pdf.name,
            "fuente_excel": args.xlsx.name,
            "total_cursos": len(courses),
        },
        "cursos": courses,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as output:
        json.dump(data, output, ensure_ascii=False, indent=2)

    total_sections = sum(len(course["secciones"]) for course in courses)
    clase_sections = sum(
        1
        for course in courses
        for section in course["secciones"]
        if section.get("tipo_sesion") == "CLASE"
    )
    inicio_fin_sections = total_sections - clase_sections
    excel_days = sum(
        len(section.get("sesiones_por_dia", []))
        for course in courses
        for section in course["secciones"]
    )

    print(f"\n[OK] {args.out.name}")
    print(f"     Cursos:    {len(courses)}")
    print(f"     Secciones: {total_sections} (CLASE={clase_sections}, INICIO_FIN={inicio_fin_sections})")
    print(f"     Dias SSU desde Excel: {excel_days}")


if __name__ == "__main__":
    main()
