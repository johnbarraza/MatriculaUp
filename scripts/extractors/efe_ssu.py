"""
efe_extractor.py — Extractor completo de EFEs (Experiencias Formativas Estudiantiles)

Extrae TODOS los cursos EFE del PDF de oferta 2026-I (planes antiguos) y los combina
con el Excel de sesiones SSU cuando corresponde.

Tipos de EFE en el PDF:
  - EFE INTRAPERSONAL        → sesiones CLASE (DIA + hora fija semanal)
  - EFE INTERPERSONAL        → sesiones CLASE
  - EFE SERVICIO SOCIAL      → sesiones INICIO/FIN (fechas exactas en Excel)
  - EFE INNOVACIÓN/INVEST.   → sesiones CLASE
  - EFE LIDERAZGO            → sesiones CLASE
  - EFE COMPETENCIAS PROF.   → sesiones CLASE

Salida: efe_ssu_2026-1_v1.json (mismo nombre que el usuario solicitó)

Formato JSON:
{
  "metadata": {...},
  "cursos": [
    {
      "codigo": "900XXX",
      "nombre": "...",
      "tipo_efe": "EFE ... (UN CRÉDITO)",
      "creditos": "1",
      "prerequisitos": "...",           # texto crudo del PDF si existe
      "secciones": [
        {
          "seccion": "A1",
          "facilitadores": ["APELLIDO, Nombre"],
          "cupos": 16,
          "tipo_sesion": "CLASE" | "INICIO_FIN",

          # Para tipo CLASE (cursos regulares):
          "sesiones": [
            {"dia": "LUN", "hora_inicio": "09:30", "hora_fin": "11:20"}
          ],

          # Para tipo INICIO_FIN (SSU y similares):
          "fecha_inicio": "2026-03-17",
          "fecha_fin":    "2026-06-09",
          "detalle":      "4 CLASES PRESENCIALES ...",
          "sesiones_por_dia": [          # solo si hay datos en el Excel
            {
              "fecha":    "2026-03-21",
              "dia":      "SAB",
              "sesiones": [
                {"tipo": "IDA",            "hora_inicio": "09:00", "hora_fin": "09:30"},
                {"tipo": "TRABAJO DE CAMPO","hora_inicio": "09:30", "hora_fin": "12:20"},
                {"tipo": "REGRESO",         "hora_inicio": "12:30", "hora_fin": "12:50"}
              ]
            }
          ]
        }
      ]
    }
  ]
}
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from datetime import date, datetime, time
from pathlib import Path

# ── Paths ────────────────────────────────────────────────────────────────────

BASE_DIR = Path(__file__).resolve().parent.parent.parent
EFE_DIR  = BASE_DIR / "pdfs" / "matricula" / "2026-1" / "EFEs"
PDF_PATH  = EFE_DIR / "Horarios-ofertados-en-matricula-2026-I_planes-antiguos.pdf"
XLSX_PATH = EFE_DIR / "Sesiones SSU_2026-I(1).xlsx"
OUT_PATH  = EFE_DIR / "efe_ssu_2026-1_v1.json"
CICLO     = "2026-1"

# ── Constants ────────────────────────────────────────────────────────────────

COURSE_CODE_RE = re.compile(r"^(\d{5,7}[_A-Z]*)\s*[-–]\s*(.+)", re.DOTALL)
SECTION_RE     = re.compile(r"^([A-Z]\d?)$")

_MONTH_ES = {
    "ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6,
    "jul": 7, "ago": 8, "sep": 9, "oct": 10, "nov": 11, "dic": 12,
}
_WEEKDAY_ES = ["LUN", "MAR", "MIE", "JUE", "VIE", "SAB", "DOM"]

# Rows to skip (table headers / preamble)
_SKIP_PATTERNS = [
    re.compile(r"^SECC\.?\s*$", re.IGNORECASE),
    re.compile(r"^PREREQUISITO", re.IGNORECASE),
    re.compile(r"^REQUISITO", re.IGNORECASE),
    re.compile(r"^TALLERES\s+DE", re.IGNORECASE),
]

# EFE type heading keywords
_EFE_HEADING_RE = re.compile(r"EFE\s+\w", re.IGNORECASE)


# ── Helpers ──────────────────────────────────────────────────────────────────

def _parse_pdf_date(raw: str) -> str | None:
    """Parse 'DD-Mon' (Spanish) → ISO date 2026."""
    if not raw:
        return None
    raw = raw.strip()
    m = re.match(r"(\d{1,2})[-/](\w{3})", raw, re.IGNORECASE)
    if m:
        day = int(m.group(1))
        mon = _MONTH_ES.get(m.group(2).lower())
        if mon:
            return date(2026, mon, day).isoformat()
    return None


def _parse_excel_date(val) -> str | None:
    """Parse Excel date cell → ISO string."""
    if val is None:
        return None
    if isinstance(val, datetime):
        return val.date().isoformat()
    if isinstance(val, date):
        return val.isoformat()
    s = str(val).strip()
    for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def _parse_time(val) -> str | None:
    """Parse time value → 'HH:MM'."""
    if val is None:
        return None
    if isinstance(val, time):
        return val.strftime("%H:%M")
    if isinstance(val, datetime):
        return val.strftime("%H:%M")
    s = str(val).strip()
    m = re.match(r"(\d{1,2}):(\d{2})", s)
    if m:
        return f"{int(m.group(1)):02d}:{m.group(2)}"
    return None


def _clean(s) -> str:
    """Strip and normalize a cell value to a clean string."""
    if s is None:
        return ""
    return str(s).strip()


def _is_skip_row(col0: str) -> bool:
    return any(p.match(col0) for p in _SKIP_PATTERNS)


# ── Step 1: Parse Excel ──────────────────────────────────────────────────────

def _load_excel() -> dict[str, dict[str, list[dict]]]:
    """Returns {codigo: {seccion: [{fecha, dia, tipo, hora_inicio, hora_fin}]}}"""
    import openpyxl

    wb   = openpyxl.load_workbook(str(XLSX_PATH))
    ws   = wb.active
    rows = list(ws.iter_rows(values_only=True))

    # Locate header row
    header_idx = None
    for i, row in enumerate(rows):
        for cell in row:
            if cell and re.search(r"C[ÓO]D", str(cell), re.IGNORECASE):
                header_idx = i
                break
        if header_idx is not None:
            break

    if header_idx is None:
        print("[Excel] WARNING: Header row not found — Excel skipped.")
        return {}

    header = [_clean(c) for c in rows[header_idx]]

    def col(patterns: list[str]) -> int:
        for pat in patterns:
            for idx, h in enumerate(header):
                if re.search(pat, h, re.IGNORECASE):
                    return idx
        raise KeyError(f"Column not found: {patterns}")

    try:
        i_cod = col([r"C[ÓO]D"])
        i_sec = col([r"SECC"])
        i_fec = col([r"FECHA"])
        i_tip = col([r"SESI[ÓO]N|TIPO|ACTIVIDAD"])
        i_hi  = col([r"INICIO|H[\._\s]*INI"])
        i_hf  = col([r"FIN|H[\._\s]*FIN"])
    except KeyError as e:
        print(f"[Excel] WARNING: {e} — Excel skipped.")
        return {}

    result: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    total = skipped = 0

    for row in rows[header_idx + 1:]:
        codigo = _clean(row[i_cod])
        if not re.match(r"^\d{5,7}$", codigo):
            continue
        seccion  = _clean(row[i_sec])
        iso_date = _parse_excel_date(row[i_fec])
        tipo     = _clean(row[i_tip])
        hi       = _parse_time(row[i_hi])
        hf       = _parse_time(row[i_hf])

        if not iso_date:
            skipped += 1
            continue

        d        = datetime.strptime(iso_date, "%Y-%m-%d").date()
        dia      = _WEEKDAY_ES[d.weekday()]

        total += 1
        result[codigo][seccion].append({
            "fecha":       iso_date,
            "dia":         dia,
            "tipo":        tipo,
            "hora_inicio": hi or "",
            "hora_fin":    hf or "",
        })

    # Sort by (fecha, hora_inicio) within each section
    for codigo in result:
        for sec in result[codigo]:
            result[codigo][sec].sort(key=lambda s: (s["fecha"], s["hora_inicio"]))

    print(f"[Excel] {total} session rows | {len(result)} cursos | {skipped} skipped")
    return dict(result)


# ── Step 2: Parse PDF ────────────────────────────────────────────────────────

def _load_pdf() -> list[dict]:
    """Parse all EFE courses from PDF. Returns list of course dicts."""
    import pdfplumber

    courses: list[dict] = []
    current_efe_type   = None
    current_prereq     = None
    current_course     = None
    current_section    = None   # last section letter

    def new_section(letter: str, facilitador: str, cupos, session_type: str,
                    date_or_day: str, hi: str, hf: str, detalle: str) -> dict:
        """Build a new section dict based on session type."""
        facilitadores = [facilitador] if facilitador else []
        cupos_int = None
        try:
            cupos_int = int(str(cupos).strip()) if cupos else None
        except (ValueError, TypeError):
            pass

        if session_type in ("INICIO", "FIN"):
            sec = {
                "seccion":        letter,
                "facilitadores":  facilitadores,
                "cupos":          cupos_int,
                "tipo_sesion":    "INICIO_FIN",
                "fecha_inicio":   _parse_pdf_date(date_or_day) if session_type == "INICIO" else None,
                "fecha_fin":      _parse_pdf_date(date_or_day) if session_type == "FIN" else None,
                "detalle":        _clean_detalle(detalle),
                "sesiones_por_dia": [],
            }
        elif session_type == "CLASE":
            sec = {
                "seccion":       letter,
                "facilitadores": facilitadores,
                "cupos":         cupos_int,
                "tipo_sesion":   "CLASE",
                "sesiones":      [],
            }
            if date_or_day and hi:
                sec["sesiones"].append({
                    "dia":         date_or_day,
                    "hora_inicio": hi,
                    "hora_fin":    hf,
                })
        else:
            # unknown — treat as CLASE with no sessions
            sec = {
                "seccion":       letter,
                "facilitadores": facilitadores,
                "cupos":         cupos_int,
                "tipo_sesion":   session_type or "CLASE",
                "sesiones":      [],
            }
        return sec

    def _clean_detalle(raw: str) -> str:
        """Remove emoji/icon characters from detalle text."""
        if not raw:
            return ""
        # Remove common emoji ranges
        cleaned = re.sub(
            r"[\U0001F300-\U0001F9FF\u2600-\u26FF\u2700-\u27BF✅☑📄🔗]",
            "", raw
        )
        # Remove leftover check-box prefixes like "✔" or similar
        cleaned = re.sub(r"\s+", " ", cleaned).strip()
        return cleaned

    with pdfplumber.open(str(PDF_PATH)) as pdf:
        for page in pdf.pages:
            for tbl in page.find_tables():
                rows = tbl.extract()
                for row in rows:
                    cells = [_clean(c) for c in row]
                    col0  = cells[0]
                    if not col0 and all(not c for c in cells):
                        continue

                    # Remove trailing empty columns
                    while cells and not cells[-1]:
                        cells.pop()

                    non_empty = [c for c in cells if c]
                    joined_up = " ".join(non_empty).upper()

                    # ── EFE type heading ──────────────────────────────────
                    if _EFE_HEADING_RE.match(col0) and len(non_empty) <= 2:
                        current_efe_type = " ".join(non_empty)
                        current_prereq   = None
                        continue

                    # ── Skip header/preamble rows ─────────────────────────
                    if _is_skip_row(col0):
                        continue

                    # Capture prerequisite/requirement text (large text row
                    # that's not a course or section)
                    if (len(col0) > 40 and len(non_empty) <= 3
                            and not COURSE_CODE_RE.match(col0)
                            and not SECTION_RE.match(col0)):
                        current_prereq = col0
                        continue

                    # ── Course header ────────────────────────────────────
                    m_course = COURSE_CODE_RE.match(col0)
                    if m_course:
                        # Strip any trailing newline + garbage (e.g. "\nPRE")
                        nombre_raw = m_course.group(2).strip()
                        nombre_clean = nombre_raw.split("\n")[0].strip()
                        current_course = {
                            "codigo":      m_course.group(1),
                            "nombre":      nombre_clean,
                            "tipo_efe":    current_efe_type or "",
                            "creditos":    "1",
                            "prerequisitos": current_prereq or None,
                            "secciones":   [],
                        }
                        courses.append(current_course)
                        current_section = None
                        continue

                    if current_course is None:
                        continue

                    # ── Section header row ────────────────────────────────
                    # PDF format (9 cols): [seccion, facilitador, tipo_sesion, dia_o_fecha, hi, hf, cupos, detalle, silabo]
                    # PDF format (7 cols): [seccion, facilitador, tipo_sesion, dia_o_fecha, cupos, detalle, silabo]
                    m_sec = SECTION_RE.match(col0)
                    if m_sec:
                        letter    = col0
                        facilit   = cells[1] if len(cells) > 1 else ""
                        ses_type  = cells[2].upper() if len(cells) > 2 else ""
                        col3      = cells[3] if len(cells) > 3 else ""  # dia or date
                        col4      = cells[4] if len(cells) > 4 else ""
                        col5      = cells[5] if len(cells) > 5 else ""
                        col6      = cells[6] if len(cells) > 6 else ""
                        col7      = cells[7] if len(cells) > 7 else ""

                        # Determine layout:
                        # 9-col regular:  col3=dia, col4=hi, col5=hf, col6=cupos, col7=detalle
                        # 7-col SSU:      col3=fecha, col4=cupos, col5=detalle
                        is_regular = ses_type == "CLASE"
                        if is_regular:
                            dia    = col3
                            hi     = col4
                            hf     = col5
                            cupos  = col6
                            det    = col7
                        else:
                            # INICIO/FIN format
                            # in 9-col: col4 might be empty, cupos in col6
                            # in 7-col: cupos in col4
                            if len(cells) >= 7:
                                # 7-col layout (SSU, page 4+)
                                cupos = col4
                                det   = col5
                            else:
                                cupos = col4
                                det   = col5
                            dia   = col3
                            hi    = ""
                            hf    = ""

                        sec = new_section(letter, facilit, cupos, ses_type,
                                          dia, hi, hf, det)

                        # Check if section already exists (avoid duplicate from cross-page)
                        existing = next(
                            (s for s in current_course["secciones"] if s["seccion"] == letter),
                            None,
                        )
                        if existing:
                            # Merge: update fecha_fin if FIN row
                            if ses_type == "FIN":
                                existing["fecha_fin"] = sec.get("fecha_fin")
                            elif ses_type == "INICIO":
                                existing["fecha_inicio"] = sec.get("fecha_inicio")
                        else:
                            current_course["secciones"].append(sec)
                            existing = sec

                        current_section = letter
                        continue

                    # ── Continuation row (col0 empty) ─────────────────────
                    if not col0 and current_course and current_section:
                        # Find the last section
                        sec = next(
                            (s for s in reversed(current_course["secciones"])
                             if s["seccion"] == current_section),
                            None,
                        )
                        if sec is None:
                            continue

                        ses_type = cells[2].upper() if len(cells) > 2 else ""
                        col3     = cells[3] if len(cells) > 3 else ""
                        col4     = cells[4] if len(cells) > 4 else ""
                        col5     = cells[5] if len(cells) > 5 else ""

                        if ses_type == "CLASE" and sec.get("tipo_sesion") == "CLASE":
                            # Additional recurring session day
                            dia = col3
                            hi  = col4
                            hf  = col5
                            if dia and hi:
                                sec["sesiones"].append({
                                    "dia":         dia,
                                    "hora_inicio": hi,
                                    "hora_fin":    hf,
                                })
                        elif ses_type == "FIN" and sec.get("tipo_sesion") == "INICIO_FIN":
                            sec["fecha_fin"] = _parse_pdf_date(col3)
                        elif ses_type == "INICIO" and sec.get("tipo_sesion") == "INICIO_FIN":
                            sec["fecha_inicio"] = _parse_pdf_date(col3)

    print(f"[PDF] {len(courses)} cursos extraídos.")
    by_type: dict[str, int] = defaultdict(int)
    for c in courses:
        by_type[c["tipo_efe"]] += 1
    for t, n in by_type.items():
        print(f"  {n:3d}  {t}")

    return courses


# ── Step 3: Merge Excel sessions into SSU courses ─────────────────────────────

def _merge_excel(courses: list[dict], excel: dict[str, dict[str, list[dict]]]) -> None:
    """Inject sesiones_por_dia from Excel into INICIO_FIN sections."""
    for course in courses:
        codigo = course["codigo"]
        if codigo not in excel:
            continue
        for sec in course["secciones"]:
            if sec.get("tipo_sesion") != "INICIO_FIN":
                continue
            seccion_key = sec["seccion"]
            flat_sessions = excel[codigo].get(seccion_key, [])
            if not flat_sessions:
                # Try all sections for this course (may have section mismatch)
                continue
            # Group by fecha
            by_day: dict[str, list[dict]] = defaultdict(list)
            for s in flat_sessions:
                by_day[s["fecha"]].append({
                    "tipo":        s["tipo"],
                    "hora_inicio": s["hora_inicio"],
                    "hora_fin":    s["hora_fin"],
                })
            sesiones_por_dia = [
                {
                    "fecha":    f,
                    "dia":      _WEEKDAY_ES[datetime.strptime(f, "%Y-%m-%d").date().weekday()],
                    "sesiones": by_day[f],
                }
                for f in sorted(by_day)
            ]
            sec["sesiones_por_dia"] = sesiones_por_dia


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=== EFE Extractor (todos los tipos) ===")
    print(f"PDF:   {PDF_PATH.name}")
    print(f"Excel: {XLSX_PATH.name}")
    print(f"Out:   {OUT_PATH}")
    print()

    print("[1/3] Parsing Excel (sesiones SSU)...")
    excel = _load_excel()

    print()
    print("[2/3] Parsing PDF (todos los EFEs)...")
    courses = _load_pdf()

    print()
    print("[3/3] Merging Excel sessions into SSU courses...")
    _merge_excel(courses, excel)

    data = {
        "metadata": {
            "ciclo":            CICLO,
            "descripcion":      "Experiencias Formativas Estudiantiles — Planes Antiguos 2026-I",
            "fecha_extraccion": date.today().isoformat(),
            "fuente_pdf":       PDF_PATH.name,
            "fuente_excel":     XLSX_PATH.name,
            "total_cursos":     len(courses),
        },
        "cursos": courses,
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    # Stats
    tipo_clase    = sum(
        1 for c in courses for s in c["secciones"]
        if s.get("tipo_sesion") == "CLASE"
    )
    tipo_ssu      = sum(
        1 for c in courses for s in c["secciones"]
        if s.get("tipo_sesion") == "INICIO_FIN"
    )
    total_secciones = tipo_clase + tipo_ssu

    print(f"\n[OK] {OUT_PATH.name}")
    print(f"     Cursos:    {len(courses)}")
    print(f"     Secciones: {total_secciones}  (CLASE={tipo_clase}, INICIO_FIN={tipo_ssu})")

    # Quick preview
    print("\n[Preview]")
    for c in courses[:3]:
        print(f"  {c['codigo']} - {c['nombre'][:45]}")
        for s in c["secciones"][:2]:
            if s.get("tipo_sesion") == "CLASE":
                print(f"    Secc {s['seccion']} | cupos={s['cupos']} | sesiones={s.get('sesiones')}")
            else:
                ndias = len(s.get("sesiones_por_dia", []))
                print(f"    Secc {s['seccion']} | {s.get('fecha_inicio')} → {s.get('fecha_fin')} | dias_excel={ndias}")


if __name__ == "__main__":
    main()
