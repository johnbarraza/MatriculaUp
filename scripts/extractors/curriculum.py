"""
CurriculumExtractor: Extracts Economia 2017 academic plan from PDF.
Generates curricula_economia2017.json with courses organized by academic cycle.

PDF structure (1 page, 3 tables):
  Table 1: Obligatory courses - Ciclo column uses Roman numerals (0, I, II...X).
           When Ciclo is None, course belongs to the same ciclo as the previous row.
           The Codigo cell on the ciclo-header row contains all codes for that ciclo
           separated by newlines. Subsequent rows with None ciclo have the remaining
           codes matched in order.
  Table 2: Concentration required courses (obligatorias de concentracion) - no ciclo.
  Table 3: Elective courses - no ciclo.
"""
import pdfplumber
import logging
from datetime import date
from scripts.extractors.base import BaseExtractor

logger = logging.getLogger(__name__)

# Roman numeral to integer mapping (includes 0 for ciclo cero)
ROMAN_MAP = {
    '0': 0, 'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5,
    'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10,
}

# 6-character course code: digits only, or digits with one alpha (e.g. '1F0229')
import re
COURSE_CODE_RE = re.compile(r'^[0-9][A-Z0-9]{5}$')


def _parse_ciclo(value: str) -> int | None:
    """Convert a ciclo cell value to an integer. Returns None if not a valid ciclo."""
    if not value:
        return None
    v = value.strip().upper()
    return ROMAN_MAP.get(v)


def _is_course_code(value: str) -> bool:
    """Return True if value looks like a course code (6 chars, starts with digit)."""
    if not value:
        return False
    v = value.strip()
    return bool(COURSE_CODE_RE.match(v))


def _extract_codes(raw: str) -> list[str]:
    """Extract all course codes from a cell that may contain newline-separated codes."""
    if not raw:
        return []
    parts = [p.strip() for p in raw.split('\n') if p.strip()]
    return [p for p in parts if _is_course_code(p)]


def _clean_nombre(raw: str) -> str:
    """Clean course name, stripping whitespace."""
    if not raw:
        return ""
    return raw.strip()


def _parse_creditos(raw: str) -> str:
    """Return credits string (column C in Table 1)."""
    if not raw:
        return ""
    return raw.strip()


def _extract_table1_ciclos(table) -> list[dict]:
    """
    Parse Table 1 (obligatorias) into a list of ciclo dicts.

    The Ciclo column contains a Roman numeral (or '0') on the first row of each
    ciclo group. The Codigo cell of that header row holds ALL codes for that ciclo
    (newline-separated). Subsequent rows with Ciclo=None provide course names in
    the same order as the codes.

    Returns: list of {ciclo: int, cursos: []}
    """
    rows = table.extract()
    ciclos: list[dict] = []
    current_ciclo_num: int | None = None
    pending_codes: list[str] = []
    current_cursos: list[dict] = []
    code_index: int = 0  # index into pending_codes for current ciclo

    for row in rows:
        if not row or all(cell is None or str(cell).strip() == "" for cell in row):
            continue

        # Unpack columns: Ciclo, Codigo, Nombre/Asignatura, DA, T, P, C, TC
        ciclo_cell = row[0].strip() if row[0] else ""
        codigo_cell = row[1].strip() if row[1] else ""
        nombre_cell = row[2].strip() if row[2] else ""
        # column C (index 6) = credits in Table 1
        creditos_cell = row[6].strip() if len(row) > 6 and row[6] else ""

        # Skip header row
        if ciclo_cell.lower() in ("ciclo",):
            continue

        # Skip total row
        if "TOTAL" in nombre_cell.upper():
            continue

        ciclo_num = _parse_ciclo(ciclo_cell)

        if ciclo_num is not None:
            # Save previous ciclo
            if current_ciclo_num is not None:
                ciclos.append({"ciclo": current_ciclo_num, "cursos": current_cursos})

            # Start new ciclo
            current_ciclo_num = ciclo_num
            pending_codes = _extract_codes(codigo_cell)
            code_index = 0
            current_cursos = []

            # The header row itself is also a course (the first course of the ciclo)
            if nombre_cell:
                codigo = pending_codes[0] if pending_codes else ""
                code_index = 1
                current_cursos.append({
                    "codigo": codigo,
                    "nombre": _clean_nombre(nombre_cell),
                    "creditos": creditos_cell,
                    "tipo": "obligatorio",
                })

        elif current_ciclo_num is not None:
            # Continuation row in same ciclo
            if nombre_cell:
                # If this row has its own code directly (e.g. ciclo 0 pattern),
                # use it; otherwise pull from pending_codes list.
                if _is_course_code(codigo_cell):
                    codigo = codigo_cell
                else:
                    codigo = pending_codes[code_index] if code_index < len(pending_codes) else ""
                    code_index += 1
                current_cursos.append({
                    "codigo": codigo,
                    "nombre": _clean_nombre(nombre_cell),
                    "creditos": creditos_cell,
                    "tipo": "obligatorio",
                })

    # Flush last ciclo
    if current_ciclo_num is not None and current_cursos:
        ciclos.append({"ciclo": current_ciclo_num, "cursos": current_cursos})

    return ciclos


def _extract_table2_concentracion(table) -> list[dict]:
    """
    Parse Table 2 (concentration required courses) into a flat list of course dicts.

    Table 2 has multi-code, multi-name cells (newline-separated). Each named course
    gets tipo='obligatorio_concentracion'. Returns a flat list (not ciclo-grouped).
    """
    rows = table.extract()
    cursos = []

    for row in rows:
        if not row or all(cell is None or str(cell).strip() == "" for cell in row):
            continue

        codigo_cell = row[0].strip() if row[0] else ""
        nombre_cell = row[1].strip() if row[1] else ""
        creditos_cell = row[5].strip() if len(row) > 5 and row[5] else ""

        # Skip header row
        if "codigo" in codigo_cell.lower() or "asignatura" in nombre_cell.lower():
            continue

        # Skip concentration group header rows (empty codigo, group name only)
        if not codigo_cell:
            continue

        # Multi-code, multi-name rows: split by newline
        codes = _extract_codes(codigo_cell)
        nombres = [n.strip() for n in nombre_cell.split('\n') if n.strip()]
        creditos_parts = [c.strip() for c in creditos_cell.split('\n') if c.strip()]

        # First 'nombre' entry is often "Obligatorios" label -- skip it
        if nombres and nombres[0].strip().lower() in ("obligatorios", "obligatorio"):
            nombres = nombres[1:]

        for i, nombre in enumerate(nombres):
            # Skip group/section labels (no matching code)
            if i >= len(codes):
                break
            # Skip lines that look like descriptions, not course names (starts with digit = section count)
            if nombre and nombre[0].isdigit():
                continue
            creditos = creditos_parts[i] if i < len(creditos_parts) else ""
            cursos.append({
                "codigo": codes[i],
                "nombre": nombre,
                "creditos": creditos,
                "tipo": "obligatorio_concentracion",
            })

    return cursos


def _extract_table3_electivos(table) -> list[dict]:
    """
    Parse Table 3 (elective courses) into a flat list of course dicts.

    Table 3 has: Codigo, Nombre, DA, T, P, C (one course per row).
    """
    rows = table.extract()
    cursos = []

    for row in rows:
        if not row or all(cell is None or str(cell).strip() == "" for cell in row):
            continue

        codigo_cell = row[0].strip() if row[0] else ""
        nombre_cell = row[1].strip() if row[1] else ""
        creditos_cell = row[5].strip() if len(row) > 5 and row[5] else ""

        # Skip header row
        if not _is_course_code(codigo_cell):
            continue

        cursos.append({
            "codigo": codigo_cell,
            "nombre": nombre_cell,
            "creditos": creditos_cell,
            "tipo": "electivo",
        })

    return cursos


class CurriculumExtractor(BaseExtractor):
    """Extracts Economia 2017 academic plan (ciclos 0-10) from curriculum PDF."""

    def output_filename(self) -> str:
        return "curricula_economia2017.json"

    def extract(self) -> dict:
        ciclos: list[dict] = []
        concentracion_cursos: list[dict] = []
        electivos_cursos: list[dict] = []

        with pdfplumber.open(str(self.pdf_path)) as pdf:
            total_pages = len(pdf.pages)
            print(f"Procesando curriculum PDF: {total_pages} pagina(s)...")

            for page_num, page in enumerate(pdf.pages, 1):
                tables = page.find_tables()
                self.total_rows += sum(len(t.extract()) for t in tables)
                print(f"  Pagina {page_num}: {len(tables)} tabla(s) encontrada(s)")

                if len(tables) >= 1:
                    ciclos.extend(_extract_table1_ciclos(tables[0]))

                if len(tables) >= 2:
                    concentracion_cursos.extend(_extract_table2_concentracion(tables[1]))

                if len(tables) >= 3:
                    electivos_cursos.extend(_extract_table3_electivos(tables[2]))

        # Add concentration courses as a special ciclo group (ciclo 99)
        if concentracion_cursos:
            ciclos.append({
                "ciclo": "concentracion",
                "nombre": "Obligatorias de Concentracion",
                "cursos": concentracion_cursos,
            })

        # Add elective courses as a special group (ciclo "electivos")
        if electivos_cursos:
            ciclos.append({
                "ciclo": "electivos",
                "nombre": "Cursos Electivos",
                "cursos": electivos_cursos,
            })

        total_courses = sum(len(c["cursos"]) for c in ciclos)
        print(
            f"curricula_economia2017.json: {len(ciclos)} grupos, "
            f"{total_courses} cursos, {self.error_count} advertencias"
        )

        if self.error_rate() > 0.01:
            print(f"  ADVERTENCIA: Tasa de error {self.error_rate():.1%} excede umbral 1%")

        return {
            "metadata": {
                "plan": "Economia 2017",
                "carrera": "Economia",
                "universidad": "Universidad del Pacifico",
                "fecha_extraccion": date.today().isoformat(),
            },
            "ciclos": ciclos,
        }
