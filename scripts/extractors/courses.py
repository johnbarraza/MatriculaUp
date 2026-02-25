"""
courses.py — CourseOfferingExtractor

Extracts course offering data from UP academic offer PDFs (pdfplumber).
Fixes EXT-02 (prerequisite truncation) and EXT-03 (Spanish compound surnames).

Real PDF format (2026-1):
  Course row:  [code+name, None, None, creditos, prereq_text, None, ...]   (11+ cols)
  Section row: [letter, obs, professor, tipo, None, dia, hora_inicio, hora_fin, '', cupos, aula]
  Session row: [None, None, None, tipo, None, dia, hora_inicio, hora_fin, '', cupos, aula]

Test fixture format (6 cols — used by tests/test_extraction.py):
  Course row:  [code_6digit, name, creditos, None, None, None]
  Prereq row:  ['', prereq_text, None, None, None, None]
  Section row: [section_letter, tipo, professor, dia, hora, aula]
"""

from __future__ import annotations

import json
import logging
import re
from datetime import date
from pathlib import Path

from scripts.extractors.base import BaseExtractor

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SESSION_KEYWORDS = {
    "CLASE", "FINAL", "PARCIAL", "PRÁCTICA", "PRACTICA", "LABORATORIO",
    "EXAMEN", "RECUPERACIÓN", "RECUPERACION", "PRÁC. CALIFICADA",
    "PRAC. CALIFICADA", "PRÁCTICA DIRIGIDA", "PRÁCTICA CALIFICADA",
    "PRACDIRIGIDA", "PRACCALIFICADA",
}

# Regex for a 6-digit course code
COURSE_CODE_RE = re.compile(r'^(\d{6})\s*-\s*(.+)', re.DOTALL)
# Also detect stand-alone 6-digit code (fixture format)
STANDALONE_CODE_RE = re.compile(r'^\d{6}$')

# Spanish professor name pattern (EXT-03 fix):
# Accepts LASTNAME(S), Firstname [del/de la/de los/de ...] [MoreNames]
# Key fix: 'del' must appear BEFORE 'de' in alternation so that "Del Rosario"
# is not matched as just "De" (prefix of "Del"). Alternation is ordered longest-first.
PROF_PATTERN = re.compile(
    r'([A-ZÑÁÉÍÓÚ][A-ZÁÉÍÓÚÑ]*(?:\s+[A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ]*)*'  # lastname (multi-word caps)
    r',\s+'
    r'[A-ZÁÉÍÓÚÑ][A-Za-záéíóúñÁÉÍÓÚÑ]+'  # firstname
    r'(?:\s+(?:'
    r'[Dd]el\s+[A-ZÁÉÍÓÚÑ][A-Za-záéíóúñÁÉÍÓÚÑ]*'   # del + word (e.g. "Del Rosario")
    r'|[Dd]el'                                          # del (standalone)
    r'|[Dd]e\s+[Ll]os\s+[A-ZÁÉÍÓÚÑ][A-Za-záéíóúñÁÉÍÓÚÑ]*'  # de los + word
    r'|[Dd]e\s+[Ll]os'                                  # de los (standalone)
    r'|[Dd]e\s+[Ll]a\s+[A-ZÁÉÍÓÚÑ][A-Za-záéíóúñÁÉÍÓÚÑ]*'   # de la + word
    r'|[Dd]e\s+[Ll]a'                                   # de la (standalone)
    r'|[Dd]e'                                            # de (standalone)
    r'|[A-ZÁÉÍÓÚÑ][A-Za-záéíóúñÁÉÍÓÚÑ]*'              # any capitalized word
    r'))*'
    r')'
)


# ---------------------------------------------------------------------------
# Public helper functions (exported, tested by test_extraction.py)
# ---------------------------------------------------------------------------

def is_truncated_prerequisite(text: str) -> bool:
    """Return True if the prerequisite string is incomplete (EXT-02).

    A prerequisite is considered truncated if it ends with an unclosed
    logical operator or open parenthesis — indicating that a continuation
    row was not merged.

    Args:
        text: Raw prerequisite string to check.

    Returns:
        True if truncated, False if the string appears complete.
    """
    stripped = text.rstrip()
    truncated_endings = ("Y (", "O (", "Y(", "O(", "Y", "O", "(")
    return any(stripped.endswith(e) for e in truncated_endings)


def extract_professors_spanish(text: str) -> list[str]:
    """Extract professor names from a cell, handling Spanish compound surnames.

    EXT-03 fix: Correctly captures names with prepositions like 'Del', 'De La',
    'De Los' that are lowercase mid-name (e.g. 'CASTROMATTA, Milagros Del Rosario').

    Professors are separated by ' / ' in the cell text (possibly with embedded
    newlines that join parts of the same name). Newlines within a single professor
    entry are replaced with a space before parsing.

    Args:
        text: Raw professor cell text, potentially containing multiple names.

    Returns:
        List of professor name strings. Never empty — falls back to [stripped_text]
        if no regex match.
    """
    if not text or not text.strip():
        return []

    # Normalize: replace newlines between parts of the same name with spaces,
    # but preserve the ' / ' separator between different professors.
    # Strategy: replace '\n' with space, since ' / ' is already the separator.
    normalized = text.replace('\n', ' ')

    # Split on ' / ' to get individual professor entries
    parts = [p.strip() for p in normalized.split(' / ') if p.strip()]

    results = []
    for part in parts:
        part = part.strip()
        m = PROF_PATTERN.match(part)
        if m:
            results.append(m.group(1).strip())
        else:
            # Edge case: regex didn't match — never discard a name
            results.append(part)

    return results if results else [text.strip()]


def extract_prerequisites_with_continuation(rows: list) -> list[dict]:
    """Parse a sequence of table rows and return a list of course dicts.

    This function handles the continuation-buffer algorithm described in EXT-02.
    It is designed to work with BOTH:
      - The test fixture format (6-column rows, 6-digit code in col[0])
      - The real PDF format (11-column rows, code embedded in col[0] as 'XXXXXX - Name')

    Prerequisite merging: If a prerequisite string is split across multiple rows
    (i.e. first row ends with 'Y (' and a second row continues it), the rows are
    concatenated before parsing.

    Args:
        rows: List of row lists as returned by pdfplumber table extraction.

    Returns:
        List of course dicts, each with keys: codigo, nombre, creditos, prerequisitos.
        The prerequisitos value is either:
          - None (no prerequisite)
          - A parsed tree dict: {"op": "AND"|"OR", "items": [...]}
          - A raw fallback dict: {"raw": text, "parsed": False}
    """
    courses = []
    current_course: dict | None = None
    prereq_buffer: list[str] = []

    def flush_prereq_buffer():
        """Merge buffer into current course's prerequisitos field."""
        if current_course is None:
            return
        if not prereq_buffer:
            current_course["prerequisitos"] = None
            return
        merged = " ".join(p.strip() for p in prereq_buffer if p.strip())
        merged = merged.strip()
        if not merged:
            current_course["prerequisitos"] = None
        elif is_truncated_prerequisite(merged):
            logger.warning("Truncated prerequisite detected: %s", merged[:80])
            current_course["prerequisitos"] = {"raw": merged, "parsed": False}
        else:
            current_course["prerequisitos"] = parse_prerequisite_tree(merged)

    for row in rows:
        if not row:
            continue

        # Normalize cells: convert None to "" and strip whitespace
        cells = [str(c).strip() if c is not None else "" for c in row]
        col0 = cells[0] if cells else ""

        # --- Detect course header row ---
        # Format A (real PDF): "123456 - Course Name" in col[0]
        m_course = COURSE_CODE_RE.match(col0)
        # Format B (fixture): standalone 6-digit code in col[0]
        m_standalone = STANDALONE_CODE_RE.match(col0)

        if m_course:
            # Flush previous course
            flush_prereq_buffer()
            if current_course is not None:
                courses.append(current_course)

            code = m_course.group(1)
            name_and_rest = m_course.group(2).strip()
            # credits in col[3], prereq in col[4]
            creditos = cells[3] if len(cells) > 3 else ""
            prereq_inline = cells[4] if len(cells) > 4 else ""

            current_course = {
                "codigo": code,
                "nombre": name_and_rest,
                "creditos": creditos,
                "prerequisitos": None,
                "secciones": [],
            }
            prereq_buffer = []
            if prereq_inline:
                # Remove 'PREREQUISITO:' prefix if present
                prereq_text = re.sub(r'^PREREQUISITO:\s*', '', prereq_inline).strip()
                if prereq_text:
                    prereq_buffer.append(prereq_text)
            continue

        elif m_standalone:
            # Fixture format: col[0]=code, col[1]=name, col[2]=creditos
            flush_prereq_buffer()
            if current_course is not None:
                courses.append(current_course)

            code = col0
            name = cells[1] if len(cells) > 1 else ""
            creditos = cells[2] if len(cells) > 2 else ""
            current_course = {
                "codigo": code,
                "nombre": name,
                "creditos": creditos,
                "prerequisitos": None,
                "secciones": [],
            }
            prereq_buffer = []
            continue

        if current_course is None:
            continue

        # --- Check if this is a section/session row ---
        # In fixture format: section row has a keyword in col[1] (CLASE, etc.)
        # In real PDF format: section row has a keyword in col[3]
        row_str = " ".join(cells)
        is_session_row = any(kw in cells for kw in SESSION_KEYWORDS)

        # Check for section header (starts a new section)
        # Real PDF: col[0] is a 1-3 char letter (A-Z) and col[3] is a session keyword
        # Fixture: col[0] is a 1-3 char letter and col[1] is a session keyword
        is_section_start = (
            col0
            and len(col0) <= 3
            and col0.upper() == col0
            and col0.isalpha()
            and not STANDALONE_CODE_RE.match(col0)
        )

        if is_section_start and is_session_row:
            # This is a section header — stop reading prerequisites
            # Parse the section row
            flush_prereq_buffer()
            prereq_buffer = []  # reset after flush
            section = _parse_section_row(cells, current_course)
            if section:
                current_course["secciones"].append(section)
            continue

        # --- None-leading session continuation row (real PDF) ---
        # col[0] is empty/None and contains a session keyword
        if not col0 and is_session_row:
            # Add session to last section if available
            if current_course["secciones"]:
                session = _parse_session_from_cells(cells)
                if session:
                    current_course["secciones"][-1]["sesiones"].append(session)
            continue

        # --- Fixture format: section row has empty col[0] and prereq text in col[1] ---
        # These are continuation prerequisite rows (empty col[0], prereq text in col[1])
        if not col0 and not is_session_row:
            prereq_text = cells[1] if len(cells) > 1 else ""
            if prereq_text:
                prereq_buffer.append(prereq_text)
            continue

    # Flush last course
    flush_prereq_buffer()
    if current_course is not None:
        courses.append(current_course)

    return courses


def parse_prerequisite_tree(text: str) -> dict:
    """Attempt to parse a prerequisite string into an AND/OR tree.

    This is a best-effort parser. If parsing fails at any point, it returns
    a raw fallback dict. Never raises.

    Args:
        text: Clean (non-truncated) prerequisite string.

    Returns:
        A dict: {"op": "AND"|"OR", "items": [...]} for compound prerequisites,
        {"items": [{"code": "...", "name": "..."}]} for single-course prerequisites,
        or {"raw": text, "parsed": False} if parsing fails.
    """
    if not text or not text.strip():
        return {"raw": text, "parsed": False}

    try:
        text = text.strip()
        return _parse_prereq_expression(text)
    except Exception as exc:
        logger.debug("Prerequisite parse failed for %r: %s", text[:60], exc)
        return {"raw": text, "parsed": False}


# ---------------------------------------------------------------------------
# Private parsing helpers
# ---------------------------------------------------------------------------

def _parse_prereq_expression(text: str) -> dict:
    """Recursive prerequisite expression parser."""
    text = text.strip()

    # Try to detect top-level AND / OR operators (outside parentheses)
    top_op, parts = _split_top_level(text)

    if top_op and len(parts) > 1:
        items = [_parse_prereq_expression(p.strip()) for p in parts]
        return {"op": top_op, "items": items}

    # Unwrap outer parentheses if present
    if text.startswith("(") and text.endswith(")"):
        inner = text[1:-1].strip()
        return _parse_prereq_expression(inner)

    # Try to parse as a single course entry
    m = re.match(r'^(\d{6})\s+(.+)$', text, re.DOTALL)
    if m:
        return {"items": [{"code": m.group(1), "name": m.group(2).strip()}]}

    # Fallback
    return {"raw": text, "parsed": False}


def _split_top_level(text: str) -> tuple[str | None, list[str]]:
    """Split text on ' Y ' or ' O ' at the top level (not inside parentheses).

    Returns (operator, parts) where operator is 'AND', 'OR', or None.
    """
    depth = 0
    i = 0
    n = len(text)
    and_splits: list[int] = []
    or_splits: list[int] = []

    while i < n:
        ch = text[i]
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        elif depth == 0:
            # Check for ' Y ' operator
            if text[i:i+3] == ' Y ' and (i == 0 or text[i-1] != '('):
                and_splits.append(i)
            # Check for ' O ' operator
            elif text[i:i+3] == ' O ' and (i == 0 or text[i-1] != '('):
                or_splits.append(i)
        i += 1

    def split_at(positions: list[int], op_str: str) -> list[str]:
        parts = []
        prev = 0
        op_len = len(op_str)
        for pos in positions:
            parts.append(text[prev:pos].strip())
            prev = pos + op_len
        parts.append(text[prev:].strip())
        return [p for p in parts if p]

    if and_splits:
        return "AND", split_at(and_splits, " Y ")
    if or_splits:
        return "OR", split_at(or_splits, " O ")

    return None, [text]


def _parse_section_row(cells: list[str], current_course: dict) -> dict | None:
    """Parse a section header row and return a section dict.

    Handles both real PDF format (11 cols) and fixture format (6 cols).
    """
    if not cells:
        return None

    col0 = cells[0]  # section letter

    # Determine format based on column count
    if len(cells) >= 11:
        # Real PDF format:
        # [letter, obs, professor, tipo, None, dia, hora_inicio, hora_fin, '', cupos, aula]
        obs = cells[1] if len(cells) > 1 else ""
        prof_text = cells[2] if len(cells) > 2 else ""
        tipo = cells[3] if len(cells) > 3 else ""
        dia = cells[5] if len(cells) > 5 else ""
        hora_inicio = cells[6] if len(cells) > 6 else ""
        hora_fin = cells[7] if len(cells) > 7 else ""
        aula = cells[10] if len(cells) > 10 else ""

        docentes = extract_professors_spanish(prof_text) if prof_text else []
        section = {
            "seccion": col0,
            "docentes": docentes,
            "observaciones": obs,
            "sesiones": [],
        }

        # Add the first session from this row if tipo is present
        if tipo and tipo in SESSION_KEYWORDS and dia:
            session = {
                "tipo": tipo,
                "dia": dia,
                "hora_inicio": hora_inicio,
                "hora_fin": hora_fin,
                "aula": aula,
            }
            section["sesiones"].append(session)

        return section

    elif len(cells) >= 6:
        # Fixture format:
        # [letter, tipo, professor, dia, hora_range, aula]
        tipo = cells[1] if len(cells) > 1 else ""
        prof_text = cells[2] if len(cells) > 2 else ""
        dia = cells[3] if len(cells) > 3 else ""
        hora_range = cells[4] if len(cells) > 4 else ""
        aula = cells[5] if len(cells) > 5 else ""

        # Parse hour range "07:30 - 09:30"
        hora_inicio, hora_fin = _parse_hora_range(hora_range)

        docentes = extract_professors_spanish(prof_text) if prof_text else []
        section = {
            "seccion": col0,
            "docentes": docentes,
            "observaciones": "",
            "sesiones": [],
        }

        if tipo and dia:
            session = {
                "tipo": tipo,
                "dia": dia,
                "hora_inicio": hora_inicio,
                "hora_fin": hora_fin,
                "aula": aula,
            }
            section["sesiones"].append(session)

        return section

    return None


def _parse_session_from_cells(cells: list[str]) -> dict | None:
    """Parse a continuation session row (None-leading in real PDF format).

    Format: [None/empty, None/empty, None/empty, tipo, None, dia, hora_inicio, hora_fin, '', cupos, aula]
    """
    if len(cells) < 8:
        return None

    tipo = cells[3] if len(cells) > 3 else ""
    dia = cells[5] if len(cells) > 5 else ""
    hora_inicio = cells[6] if len(cells) > 6 else ""
    hora_fin = cells[7] if len(cells) > 7 else ""
    aula = cells[10] if len(cells) > 10 else ""

    if not tipo or not dia:
        return None

    return {
        "tipo": tipo,
        "dia": dia,
        "hora_inicio": hora_inicio,
        "hora_fin": hora_fin,
        "aula": aula,
    }


def _parse_hora_range(hora_range: str) -> tuple[str, str]:
    """Parse '07:30 - 09:30' into ('07:30', '09:30')."""
    if ' - ' in hora_range:
        parts = hora_range.split(' - ', 1)
        return parts[0].strip(), parts[1].strip()
    return hora_range.strip(), ""


# ---------------------------------------------------------------------------
# CourseOfferingExtractor (main class)
# ---------------------------------------------------------------------------

class CourseOfferingExtractor(BaseExtractor):
    """Extracts course offering data from a UP academic offer PDF.

    Usage:
        extractor = CourseOfferingExtractor("pdfs/matricula/2026-1/regular/Oferta-Academica-2026-I_v1.pdf")
        data = extractor.extract()
        extractor.save(data)
    """

    # pdfplumber table detection settings
    TABLE_SETTINGS = {
        "vertical_strategy": "lines",
        "horizontal_strategy": "lines",
        "snap_tolerance": 3,
        "join_tolerance": 3,
    }

    def __init__(self, pdf_path: str, output_dir: str = "input"):
        super().__init__(pdf_path, output_dir)
        self._cycle = self._detect_cycle()

    def _detect_cycle(self) -> str:
        """Extract cycle identifier from PDF filename, e.g. '2026-1'.

        Converts Roman numeral cycle suffixes (I->1, II->2) to Arabic numerals.
        Examples:
          'Oferta-Academica-2026-I_v1' -> '2026-1'
          'Oferta-Academica-2025-II' -> '2025-2'
        """
        stem = self.pdf_path.stem
        # Match YYYY-I, YYYY-II, YYYY-1, YYYY-2 patterns
        m = re.search(r'(\d{4})[-_](I{1,2}|[12])(?=[-_\s]|$)', stem, re.IGNORECASE)
        if m:
            year = m.group(1)
            suffix = m.group(2).upper()
            suffix = suffix.replace('II', '2').replace('I', '1')
            return f"{year}-{suffix}"
        return "2026-1"

    @property
    def cycle(self) -> str:
        return self._cycle

    def output_filename(self) -> str:
        return f"courses_{self.cycle}.json"

    def extract(self) -> dict:
        """Extract all courses from the PDF.

        Returns:
            Dict with 'metadata' and 'cursos' keys.
        """
        import pdfplumber

        all_courses: list[dict] = []
        section_count_total = 0
        warning_count = 0

        with pdfplumber.open(str(self.pdf_path)) as pdf:
            total_pages = len(pdf.pages)

            for i, page in enumerate(pdf.pages):
                if i % 10 == 0:
                    print(f"Procesando página {i+1}/{total_pages}...", end="\r", flush=True)

                # Use find_tables for better table detection
                tables = page.find_tables(self.TABLE_SETTINGS)
                if not tables:
                    # Try simpler extract_table fallback
                    table = page.extract_table()
                    if table:
                        tables_data = [table]
                    else:
                        continue  # Cover/header page, skip silently
                else:
                    tables_data = [t.extract() for t in tables]

                for table in tables_data:
                    if not table:
                        continue
                    self.total_rows += len(table)
                    page_courses = self._process_table(table)
                    all_courses.extend(page_courses)

        # Deduplicate: if a course spans pages, merge sections
        merged = self._merge_courses(all_courses)

        # Calculate stats
        for course in merged:
            section_count_total += len(course.get("secciones", []))
            prereq = course.get("prerequisitos")
            if isinstance(prereq, dict) and prereq.get("parsed") is False:
                warning_count += 1
                self.warnings.append(
                    f"{course['codigo']}: truncated prerequisite: {prereq.get('raw', '')[:60]}"
                )

        # Report error rate
        rate = self.error_rate()
        if rate > 0.01:
            print(f"\n[WARN] Error rate {rate:.1%} exceeds 1% threshold")

        avg_sections = (section_count_total / len(merged)) if merged else 0
        print(
            f"\n[OK] courses.json: {len(merged)} cursos, "
            f"{avg_sections:.1f} secciones promedio, "
            f"{warning_count} advertencias"
        )

        data = {
            "metadata": {
                "ciclo": self.cycle,
                "fecha_extraccion": date.today().isoformat(),
            },
            "cursos": merged,
        }

        # Validate output against schema before saving
        try:
            from scripts.extractors.validators import validate_courses_json
            errors = validate_courses_json(data)
            if errors:
                for e in errors[:5]:  # Show first 5 errors
                    logger.warning("Schema error: %s", e)
                print(f"[WARN] {len(errors)} schema validation errors")
            else:
                print("[OK] Schema validation passed")
        except ImportError:
            logger.debug("validators.py not available — skipping schema validation")

        return data

    def _process_table(self, table: list[list]) -> list[dict]:
        """Process a single extracted table and return course list."""
        courses = []
        current_course: dict | None = None
        prereq_parts: list[str] = []

        session_kws = SESSION_KEYWORDS

        def flush_course():
            nonlocal current_course, prereq_parts
            if current_course is None:
                return
            # Process accumulated prerequisite parts (shouldn't happen in real PDF
            # since prereqs are inline, but handle defensively)
            if prereq_parts:
                merged_prereq = " ".join(prereq_parts).strip()
                if merged_prereq:
                    if is_truncated_prerequisite(merged_prereq):
                        self.error_count += 1
                        logger.warning("Truncated prereq for %s: %s", current_course["codigo"], merged_prereq[:60])
                        current_course["prerequisitos"] = {"raw": merged_prereq, "parsed": False}
                    else:
                        current_course["prerequisitos"] = parse_prerequisite_tree(merged_prereq)
            courses.append(current_course)
            current_course = None
            prereq_parts = []

        for row in table:
            if not row:
                continue

            cells = [str(c).strip() if c is not None else "" for c in row]
            col0 = cells[0] if cells else ""

            # Skip header rows
            if any(h in col0 for h in ["Secc", "CURSOS"]):
                continue

            # --- Course header row ---
            m = COURSE_CODE_RE.match(col0)
            if m:
                flush_course()

                code = m.group(1)
                name = m.group(2).strip()
                creditos = cells[3].replace(",", ".") if len(cells) > 3 and cells[3] else ""
                prereq_inline = cells[4] if len(cells) > 4 else ""

                current_course = {
                    "codigo": code,
                    "nombre": name,
                    "creditos": creditos,
                    "prerequisitos": None,
                    "secciones": [],
                }

                prereq_parts = []
                if prereq_inline:
                    prereq_text = re.sub(r'^PREREQUISITO:\s*', '', prereq_inline).strip()
                    # Inline prereqs may contain \n (multi-line cell) — join with space
                    prereq_text = " ".join(prereq_text.split())
                    if prereq_text:
                        if is_truncated_prerequisite(prereq_text):
                            self.error_count += 1
                            current_course["prerequisitos"] = {"raw": prereq_text, "parsed": False}
                        else:
                            current_course["prerequisitos"] = parse_prerequisite_tree(prereq_text)
                continue

            if current_course is None:
                continue

            # --- Section header row ---
            # Real PDF: col[0]=letter, col[3]=tipo keyword
            is_section = (
                col0
                and len(col0) <= 3
                and col0.isalpha()
                and col0 == col0.upper()
            )

            if is_section:
                section = self._parse_real_section_row(cells)
                if section:
                    current_course["secciones"].append(section)
                continue

            # --- Session continuation row (None-leading) ---
            if not col0:
                tipo = cells[3] if len(cells) > 3 else ""
                if tipo in session_kws or any(kw in tipo for kw in session_kws):
                    session = self._parse_real_session_row(cells)
                    if session and current_course["secciones"]:
                        current_course["secciones"][-1]["sesiones"].append(session)
                continue

        # Flush the last course
        flush_course()
        return courses

    def _parse_real_section_row(self, cells: list[str]) -> dict | None:
        """Parse a section row from the real PDF format (11 cols)."""
        if len(cells) < 4:
            return None

        section_letter = cells[0]
        obs = cells[1]
        prof_text = cells[2]
        tipo = cells[3] if len(cells) > 3 else ""
        dia = cells[5] if len(cells) > 5 else ""
        hora_inicio = cells[6] if len(cells) > 6 else ""
        hora_fin = cells[7] if len(cells) > 7 else ""
        aula = cells[10] if len(cells) > 10 else ""

        docentes = extract_professors_spanish(prof_text) if prof_text else []

        section = {
            "seccion": section_letter,
            "docentes": docentes,
            "observaciones": obs,
            "sesiones": [],
        }

        # Add the first session from this row
        if tipo and dia:
            session_kws = SESSION_KEYWORDS
            if tipo in session_kws or any(kw in tipo for kw in session_kws):
                session = {
                    "tipo": tipo,
                    "dia": dia,
                    "hora_inicio": hora_inicio,
                    "hora_fin": hora_fin,
                    "aula": aula,
                }
                section["sesiones"].append(session)

        return section

    def _parse_real_session_row(self, cells: list[str]) -> dict | None:
        """Parse a continuation session row from the real PDF format."""
        if len(cells) < 8:
            return None

        tipo = cells[3] if len(cells) > 3 else ""
        dia = cells[5] if len(cells) > 5 else ""
        hora_inicio = cells[6] if len(cells) > 6 else ""
        hora_fin = cells[7] if len(cells) > 7 else ""
        aula = cells[10] if len(cells) > 10 else ""

        if not tipo or not dia:
            return None

        return {
            "tipo": tipo,
            "dia": dia,
            "hora_inicio": hora_inicio,
            "hora_fin": hora_fin,
            "aula": aula,
        }

    def _merge_courses(self, courses: list[dict]) -> list[dict]:
        """Merge duplicate course entries (when a course spans two pages).

        Same course code appearing twice: merge their sections lists.
        """
        seen: dict[str, dict] = {}
        result: list[dict] = []

        for course in courses:
            code = course["codigo"]
            if code in seen:
                # Merge sections
                seen[code]["secciones"].extend(course.get("secciones", []))
            else:
                seen[code] = course
                result.append(course)

        return result
