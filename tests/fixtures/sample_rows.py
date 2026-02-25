"""
Hard-coded sample rows that mimic real PDF table rows from the 2026-1 Economia course offer.

Each row is a list representing the columns extracted by pdfplumber from a table.
Column order (based on v6 notebook analysis):
  [0] codigo_or_indicator  -- 6-digit course code, section letter, or empty for continuation
  [1] nombre_or_type       -- course name, session type (CLASE, PRACTICA, etc.)
  [2] creditos_or_profesor  -- credits for course rows, professor for section rows
  [3] dia                  -- day of week (LUN, MAR, etc.) or empty
  [4] hora                 -- time range (07:30 - 09:30) or empty
  [5] aula                 -- classroom code or empty
"""

# A standard course header row: 6-digit code, name, credits (prerequisites in a sub-row)
COURSE_HEADER_ROW = [
    "138201",
    "Microeconomia I",
    "4",
    None,
    None,
    None,
]

# A prerequisite row where the first cell is empty and the text ends mid-expression
# with an unclosed AND operator — classic truncation pattern.
PREREQ_ROW_TRUNCATED = [
    "",
    "166097 Contabilidad Financiera I Y (",
    None,
    None,
    None,
    None,
]

# The continuation row that completes the open parenthesis started above.
PREREQ_ROW_CONTINUATION = [
    "",
    "138105 Matematica II)",
    None,
    None,
    None,
    None,
]

# A section/CLASE row: section letter, session type, professor, day, time, room.
# This marks the end of prerequisite accumulation for the current course.
SECTION_ROW_CLASE = [
    "A",
    "CLASE",
    "CASTROMATTA, Milagros Del Rosario",
    "LUN",
    "07:30 - 09:30",
    "A-301",
]

# A raw professor cell text containing two professors with compound Spanish surnames,
# separated by the ' / ' delimiter used in the v6 notebook extraction logic.
PROFESSOR_COMPOUND_ROW = (
    "CASTROMATTA, Milagros Del Rosario / GARCIA, Juan De La Cruz"
)
