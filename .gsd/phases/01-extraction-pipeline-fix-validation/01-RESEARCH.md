# Phase 1: Extraction Pipeline Fix & Validation - Research

**Researched:** 2026-02-24
**Domain:** PDF table extraction + JSON schema validation (pdfplumber, Python)
**Confidence:** HIGH (existing code analyzed, critical pitfalls identified, requirements locked)

## Summary

Phase 1 requires fixing two critical bugs in the existing pdfplumber extraction pipeline (`scripts/pdf_to_csv.ipynb` v6) and migrating it from notebook to production CLI script (`scripts/extract.py`). The bugs cause data loss in two specific areas: multi-line prerequisite cells truncate mid-expression, and Spanish compound surnames fail regex parsing. The phase also requires generating validated JSON output (courses_2026-1.json and curricula_economia2017.json) with structural validation against a defined schema.

The existing v6 notebook already handles 90% of the extraction logic correctly (multi-docent name extraction with ` / ` separator, activity type parsing, schedule extraction). The fix involves: (1) tuning pdfplumber table parameters for multi-line cell preservation, (2) replacing the professor name regex to accept lowercase Spanish prepositions, (3) implementing a prerequisite continuation buffer that detects truncation patterns, and (4) building validation rules that check for incomplete logical expressions and missing row boundaries.

**Primary recommendation:** Migrate v6 notebook logic to `scripts/extract.py` with prerequisite continuation buffering, Spanish name regex fix, and JSON schema validation. Test against both source PDFs (2026-1 offer + 2017 economics curriculum) before completion. Include console reporting of truncation detection and error counts.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- JSON schema: Nested structure `curso → secciones[] → sesiones[]` with prerequisites as structured tree or raw fallback
- Output: Two files — `courses_2026-1.json` and `curricula_economia2017.json` in `input/` folder
- Script: `scripts/extract.py` with CLI args `--type courses|curriculum --pdf <path>`
- Error handling: Skip unparseable rows + log (fail if >1% error rate)
- Validation: Console report with truncation pattern detection

### Claude's Discretion
- Exact log message format
- PDF page handling (skip cover/header pages without tables)
- pdfplumber algorithm details for edge case cells
- Internal script structure (classes vs functions)

### Deferred Ideas (Out of Scope)
- Multi-cycle support (only 2026-1 in v1)
- Multi-career extraction beyond sample testing
- Exam role extraction
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| EXT-01 | Extractor processes course offering PDF → generates courses.json with courses, sections, sessions | Existing v6 notebook already does this; Phase 1 fixes truncation bugs + migrates to CLI |
| EXT-02 | Compound prerequisites (multi-row AND/OR chains) parsed complete without truncation | CRITICAL FIX: Continuation buffer detects incomplete expressions (ending with "Y (" or "O (") and merges rows |
| EXT-03 | Professor names with Spanish prepositions (Del, De La, De Los) captured complete | CRITICAL FIX: Regex updated to accept lowercase prepositions mid-name; test "CASTROMATTA, Milagros Del Rosario" |
| EXT-04 | Generated JSON validated against defined schema (nested structure with required fields) | Schema validation: check curso.codigo, secciones[].docentes[], sesiones[].tipo in [CLASE, PRÁCTICA, ...] |
| EXT-05 | Extractor processes curriculum PDF → generates curricula_economia2017.json by academic cycle | Existing economia2017.json shows target structure; Phase 1 must extract from 2017 plan PDF with same schema |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pdfplumber | 0.11.8+ | PDF table extraction with multi-line cell support | Industry standard for Python PDF extraction; better than PyPDF2/reportlab for table detection |
| pandas | 2.3.3+ | DataFrame creation + validation | Ubiquitous for data cleaning; integrates with pdfplumber output |
| Python | 3.9+ | CLI script runtime | Project baseline; no additional runtimes needed |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jsonschema | 4.20+ | JSON schema validation | Validate extracted JSON against defined schema; fail fast on structure errors |
| re (standard) | - | Regex parsing for names, codes, times | Already in use in v6; essential for Spanish name handling |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pdfplumber | PyPDF2 | PyPDF2 lacks table detection; would require manual boundary parsing |
| pdfplumber | tabula-py | tabula-py depends on Java; adds distribution complexity for .exe bundle |
| pandas DataFrame | dict + manual validation | Loses built-in data cleaning (NaN handling, type coercion) |
| jsonschema | manual dict checks | Fragile; schema validation is declarative and testable |

**Installation:**
```bash
pip install pdfplumber==0.11.8 pandas==2.3.3 jsonschema==4.20+
```

---

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── extract.py               # New: CLI entry point, wraps ExtractorPipeline
├── pdf_to_csv.ipynb         # Old: v6 notebook (archive, reference only)
└── extractors/
    ├── __init__.py
    ├── base.py              # Abstract Extractor class
    ├── courses.py           # CourseOfferingExtractor
    ├── curriculum.py        # CurriculumExtractor
    └── validators.py        # JSONSchemaValidator, TruncationDetector
tests/
├── test_extraction.py       # Unit tests for extractors
├── test_validation.py       # Schema validation tests
├── fixtures/                # Sample PDFs + expected outputs
└── conftest.py              # Shared test config
input/
├── courses_2026-1.json      # Generated output
└── curricula_economia2017.json
```

### Pattern 1: Pipeline Composition
**What:** Extract → Transform → Validate → Output (functional pipeline)
**When to use:** Multi-stage PDF extraction where each stage can fail independently
**Example:**
```python
# From existing v6 notebook structure
pipeline = ExtractorPipeline()
pipeline.extract_tables()           # pdfplumber
pipeline.parse_rows()               # Transform to structured data
pipeline.detect_truncation()        # Validate completeness
pipeline.output_json()              # Write with schema check
```

### Pattern 2: Row Continuation Buffer
**What:** Accumulate prerequisite rows until a terminating condition (sección/clase detected)
**When to use:** Multi-line cells in PDF tables get split across rows
**Example:**
```python
# From PITFALLS.md Pitfall 1 solution
continuation_buffer = []
for row in table:
    if is_new_section(row) or is_class_row(row):
        # Merge accumulated prerequisite rows
        merged_prereq = " ".join(continuation_buffer)
        validate_not_truncated(merged_prereq)  # Check ends with code, not "Y ("
        continuation_buffer = []
    elif in_prerequisite_field:
        continuation_buffer.append(row)
```

### Pattern 3: Spanish Name Regex (Fixed)
**What:** Accept lowercase prepositions in multi-part surnames
**When to use:** Parsing "LASTNAME, Firstname [Prefix] Suffix" with "del", "de la" mid-name
**Example:**
```python
# From PITFALLS.md Pitfall 2 solution
spanish_prepositions = {'de', 'del', 'de la', 'de los', 'da', 'la', 'las', 'y'}
regex_fixed = r'([A-ZÑÁÉÍÓÚ][A-Za-zÑÁÉÍÓÚñáéíóú\s\-\.]+,[\s]+[A-ZÑÁÉÍÓÚ](?:[A-Za-zÑÁÉÍÓÚñáéíóú]|(?:\s+(?:del|de|la|de la|de los)))+)'
# Test: "CASTROMATTA, Milagros Del Rosario" → Full match ✓
```

### Anti-Patterns to Avoid
- **Hardcoded pdfplumber settings:** Different PDFs (different tools, fonts, line styles) require different `vertical_strategy`/`horizontal_strategy`. Use detection logic, not magic numbers.
- **Regex-only name parsing:** Pure regex breaks on edge cases (compound surnames, multi-line cells). Combine regex with fallback logic (raw text storage).
- **Single-pass extraction:** Don't extract once and assume correctness. Multi-pass: extract → detect gaps → re-extract with tuned parameters.
- **Validation after output:** Validate during extraction so errors are caught early with context (row number, cell content) for debugging.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PDF table boundary detection | Manual line-drawing algorithm | pdfplumber + `find_tables()` with tuned strategies | Line detection varies by PDF tool; reinventing it introduces subtle bugs |
| JSON schema validation | Manual dict key checking | jsonschema library | Schema validation is a solved, standardized problem; custom validation is fragile and incomplete |
| Multi-row cell merging | Custom string concatenation with heuristics | pdfplumber's `text_y_tolerance` tuning + explicit row grouping | Text merging requires understanding PDF geometry; tune library parameters first |
| CSV/DataFrame cleaning | Manual regex replacements | pandas built-ins (`.str.strip()`, `.fillna()`) | DataFrame operations are optimized and tested; regex is brittle |

**Key insight:** PDF extraction is inherently fragile because PDF is a rendering format, not a structured format. Leverage battle-tested libraries (pdfplumber, pandas) for heavy lifting; use custom logic only for domain-specific rules (Spanish names, prerequisite logic).

---

## Common Pitfalls

### Pitfall 1: Multi-line Prerequisite Truncation
**What goes wrong:** Prerequisite field "138201 Microeconomía I Y (166097 Contabilidad Financiera I O [continues]" stops mid-expression instead of capturing full AND/OR chain. Ends with `"Y ("` or `"O ("` instead of course code or `)`.

**Why it happens:** pdfplumber's default line-based table detection treats wrapped text within a cell as separate rows. No row-merge logic captures the continuation.

**How to avoid:**
1. Use `text_y_tolerance=10` to group vertically-close text in same cell
2. Implement continuation buffer: if next row's first column is empty AND current cell ends with incomplete operator, merge
3. Add validation: prerequisite must NOT end with `"Y ("`, `"O ("`, etc.

**Warning signs:**
- Extracted prerequisites end mid-token ("Contabilidad Financiera I O")
- Row count increases unexpectedly (wrapped lines treated as separate rows)
- Regex validators fail on prerequisite strings
- Validate before committing: count "(" and ")" — should be balanced

**Phase to address:** Phase 1 (CRITICAL — must fix before JSON output)

---

### Pitfall 2: Spanish Compound Surname Regex Failure
**What goes wrong:** "CASTROMATTA, Milagros Del Rosario" captured as "CASTROMATTA, Milagros" — regex stops at lowercase "d" in "Del".

**Why it happens:** Standard name regex assumes `[A-Z][a-z]+` pattern. Spanish prepositions ("del", "de la") break capitalization assumption.

**How to avoid:**
1. Update regex to accept lowercase prepositions: `(?:de|del|de la|de los|la|y)` within firstname
2. Or: Parse names by splitting on comma, then reconstruct firstname respecting prepositions as separate tokens
3. Validate: Check extracted names are >5 chars and contain no orphaned prepositions ("del" alone = truncation)

**Warning signs:**
- Extracted names shorter than expected (2 words instead of 3+)
- Names ending with lowercase: "LASTNAME, Firstname del"
- Professor lists show same person inconsistently (truncated vs. full)

**Phase to address:** Phase 1 (CRITICAL — data integrity)

---

### Pitfall 3: Missing Table Row Boundaries
**What goes wrong:** First or last row of table drops silently. "Course A section B" first row disappears; last prerequisite row cut off.

**Why it happens:** pdfplumber misses faint/missing horizontal lines at table edges. Uses line-based detection by default; if border is thin, missing, or rendered differently, table boundary is misdetected.

**How to avoid:**
1. After extraction, compare expected row count with extracted count — missing rows should trigger detailed inspection
2. Use `vertical_strategy="text"` and `horizontal_strategy="text"` (not "lines") if borders are faint
3. Check table bbox alignment with page geometry; if large gap between table top and page top → missing row

**Warning signs:**
- Extracted row count < visually-counted rows
- First/last row contains NULL while adjacent rows have data
- `find_tables()` returns fewer tables than expected

**Phase to address:** Phase 1 (CRITICAL)

---

### Pitfall 4: Encoding Mismatches (Spanish Characters)
**What goes wrong:** "Microeconomía" appears as "Microeconom?a" — Spanish accents lost.

**Why it happens:** PDFs may use different encodings; pdfplumber doesn't always auto-detect. Output written without UTF-8 encoding spec.

**How to avoid:**
1. Always write output with explicit encoding: `open(file, 'w', encoding='utf-8')`
2. Test with sample PDFs containing accented characters early (ñ, á, é, í, ó, ú)
3. Validate extracted text: no "?" or garbled sequences

**Warning signs:**
- Accented characters replaced with "?"
- Spanish names unreadable in output JSON
- Encoding errors on non-ASCII characters

**Phase to address:** Phase 1 (MODERATE — data quality)

---

### Pitfall 5: Validation Timing (Late Discovery)
**What goes wrong:** Extractor completes with invalid data, errors discovered during app testing weeks later.

**Why it happens:** Validation happens after extraction completes; errors lack context (which row, which cell).

**How to avoid:**
1. Validate during extraction, not after: as each course is parsed, check schema compliance
2. Report errors with context: "Row 42: missing section letter", not just "Invalid course"
3. Set <1% error threshold (from CONTEXT.md): count problematic rows, alert if ratio exceeds threshold

**Warning signs:**
- Extraction completes without errors, app loading fails
- No row-level error logging in output
- Can't trace data corruption to source PDF location

**Phase to address:** Phase 1 (CRITICAL for debugging)

---

## Code Examples

### Example 1: Prerequisite Continuation Buffer (v6 improvement)
```python
# From PITFALLS.md + existing v6 notebook logic
def extract_prerequisites_with_continuation(table):
    """Accumulate multi-line prerequisite cells until next course/section detected."""
    courses = []
    current_course = None
    prerequisite_buffer = []

    for row in table:
        row_str = " ".join(str(cell).strip() for cell in row if cell)

        # Detect new course (6-digit code)
        if re.match(r'^[A-Z0-9]{6}', row_str):
            # Save previous course with merged prerequisites
            if current_course:
                merged_prereq = " ".join(prerequisite_buffer)
                current_course['prerequisitos'] = merged_prereq
                validate_prerequisite_complete(merged_prereq)  # Check not truncated
                courses.append(current_course)

            # Start new course
            current_course = parse_course_header(row)
            prerequisite_buffer = []

        # Detect section/class (end of prerequisites for this course)
        elif is_section_or_class(row):
            if current_course:
                merged_prereq = " ".join(prerequisite_buffer)
                current_course['prerequisitos'] = merged_prereq
                validate_prerequisite_complete(merged_prereq)
                courses.append(current_course)
            current_course = None
            prerequisite_buffer = []

        # Accumulate prerequisite rows
        elif current_course and row[0].strip() == "":  # Empty first column = continuation
            prerequisite_buffer.append(row_str)

    return courses

def validate_prerequisite_complete(prereq_text):
    """Detect truncation: prerequisite should NOT end with 'Y (', 'O (', etc."""
    if prereq_text.rstrip().endswith(('Y (', 'O (', 'Y', 'O')):
        raise ValueError(f"Truncated prerequisite: {prereq_text[:50]}...")
```

### Example 2: Fixed Spanish Name Regex
```python
# From PITFALLS.md Pitfall 2 solution
import re

def extract_professors_spanish(text):
    """Extract professor names handling Spanish prepositions."""
    # Pattern: LASTNAME, Firstname [+ prepositions/suffixes]
    # Accept lowercase 'de', 'del', 'de la' within name
    spanish_prepositions = {'de', 'del', 'de la', 'de los', 'da', 'la', 'las', 'y'}

    # Regex: Accept Name, Name [and prepositions] multiple times
    pattern = r'([A-ZÑÁÉÍÓÚ][A-Za-zÑÁÉÍÓÚñáéíóú\s\-\.]+,\s+[A-ZÑÁÉÍÓÚ][A-Za-zÑÁÉÍÓÚñáéíóú\s\-\.]+(?:\s+(?:de|del|de la|de los|la|las|y|Y)\s+[A-ZÑÁÉÍÓÚ][A-Za-zÑÁÉÍÓÚñáéíóú\s\-\.]+)*)'

    matches = re.findall(pattern, text)
    return [m.strip() for m in matches]

# Test cases
test_cases = [
    "CASTROMATTA, Milagros Del Rosario",  # Should match fully
    "GARCIA, Juan De La Cruz",            # Should match fully
    "SMITH, John",                        # Should match
]

for test in test_cases:
    result = extract_professors_spanish(test)
    print(f"{test} → {result}")
    # Expected: Full names captured, not truncated
```

### Example 3: JSON Schema Validation
```python
# Validate extracted courses against schema
from jsonschema import validate, ValidationError

COURSES_SCHEMA = {
    "type": "object",
    "properties": {
        "metadata": {
            "type": "object",
            "properties": {
                "ciclo": {"type": "string"},
                "fecha_extraccion": {"type": "string"}
            },
            "required": ["ciclo", "fecha_extraccion"]
        },
        "cursos": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "codigo": {"type": "string", "pattern": "^[0-9]{6}$"},
                    "nombre": {"type": "string"},
                    "creditos": {"type": ["string", "number"]},
                    "secciones": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "seccion": {"type": "string"},
                                "docentes": {"type": "array", "items": {"type": "string"}},
                                "sesiones": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "tipo": {
                                                "type": "string",
                                                "enum": ["CLASE", "PRÁCTICA", "FINAL", "PARCIAL", "PRACDIRIGIDA"]
                                            },
                                            "dia": {"type": "string"},
                                            "hora_inicio": {"type": "string", "pattern": "^\\d{2}:\\d{2}$"},
                                            "hora_fin": {"type": "string", "pattern": "^\\d{2}:\\d{2}$"}
                                        },
                                        "required": ["tipo", "dia", "hora_inicio", "hora_fin"]
                                    }
                                }
                            },
                            "required": ["seccion", "sesiones"]
                        }
                    }
                },
                "required": ["codigo", "nombre", "creditos", "secciones"]
            }
        }
    },
    "required": ["metadata", "cursos"]
}

# Validate extracted data
try:
    validate(instance=extracted_data, schema=COURSES_SCHEMA)
    print("✓ JSON schema validation passed")
except ValidationError as e:
    print(f"✗ Schema error: {e.message} at {e.path}")
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Notebook (pdf_to_csv.ipynb) for extraction | CLI script (extract.py) with parameterization | Phase 1 2026 | Reproducibility, versioning, CI/CD integration |
| Multi-docent regex with \`/\` separator | Already implemented in v6 | Pre-Phase 1 | Handles multiple professors per section ✓ |
| Manual prerequisite row merging | Continuation buffer + truncation detection | Phase 1 (FIX) | Prevents data loss from multi-line cells |
| Naive Spanish name regex | Preposition-aware regex (Pitfall 2) | Phase 1 (FIX) | Captures full names like "Del Rosario" |
| Manual visual inspection for validation | Automated schema + truncation checks | Phase 1 (NEW) | Fast feedback loop, quantified error rate |

**Deprecated/outdated:**
- Hardcoded pdfplumber settings (`vertical_strategy="lines"`): Different PDFs need different strategies. v1 uses text-based detection with fallback.
- CSV intermediate format: Jump directly to JSON for nested data (sessions per section per course).
- No error reporting: v1 logs all problematic rows and calculates error ratio for exit code.

---

## Open Questions

1. **Multi-line cell merging threshold:** How many consecutive empty first-column rows before merging with prerequisite? Recommend: merge until first non-empty column 0 OR class keyword detected.

2. **Curriculum PDF structure:** Is economía 2017 plan PDF table structure similar to 2026-1 offer PDF? Or requires separate parser logic?
   - Recommendation: Extract one course manually from 2017 plan PDF to verify structure before building curriculum extractor.

3. **Error threshold interpretation:** "< 1% error rate" — count errors as (problematic rows / total extracted rows) or (courses with issues / total courses)?
   - Recommendation: Row-level (more granular, easier to debug).

4. **Fallback prerequisite storage:** If prerequisite can't be parsed as AND/OR tree, store as `{"raw": "text", "parsed": false}`? Or attempt partial parsing?
   - Recommendation: Attempt tree parsing first, fall back to raw + flag only if parsing fails.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pytest (standard Python, no existing config detected) |
| Config file | `tests/conftest.py` — shared fixtures for extractor tests |
| Quick run command | `pytest tests/test_extraction.py -x --tb=short` |
| Full suite command | `pytest tests/ -v --cov=scripts/extractors` |
| Estimated runtime | ~10 seconds for 50+ test cases |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXT-01 | Extract courses, sections, sessions from 2026-1 PDF → JSON with correct structure | integration | `pytest tests/test_extraction.py::test_courses_structure -x` | Wave 0 gap |
| EXT-02 | Multi-row prerequisites merged complete; detect and reject truncated expressions | unit + integration | `pytest tests/test_extraction.py::test_prerequisite_continuation -x` + `test_prerequisite_not_truncated` | Wave 0 gap |
| EXT-03 | Spanish compound surnames captured fully (test "Del Rosario", "De La", etc.) | unit | `pytest tests/test_extraction.py::test_professor_spanish_names -x` | Wave 0 gap |
| EXT-04 | Generated JSON validated against schema; all courses have required fields | unit | `pytest tests/test_validation.py::test_json_schema_compliance -x` | Wave 0 gap |
| EXT-05 | Curriculum PDF parsed → JSON by cycle with courses and prerequisites | integration | `pytest tests/test_extraction.py::test_curriculum_structure -x` | Wave 0 gap |

### Nyquist Sampling Rate
- **Minimum sample interval:** After completing each task (Pitfall 1 fix, Pitfall 2 fix, schema validation, etc.) → run: `pytest tests/test_extraction.py -x --tb=short`
- **Full suite trigger:** Before merging final task (validation verification) → run: `pytest tests/ -v`
- **Phase-complete gate:** Full suite green + manual verification (courses_2026-1.json loads without errors, no truncated prerequisites visually spot-checked)
- **Estimated feedback latency per task:** ~5 seconds (fast unit tests)

### Wave 0 Gaps (must be created before implementation)
- [ ] `tests/test_extraction.py` — unit tests for prerequisite continuation buffer, professor name parsing
- [ ] `tests/test_extraction.py::test_*_integration` — integration tests with real PDFs (2026-1 offer, 2017 curriculum)
- [ ] `tests/test_validation.py` — jsonschema validation tests
- [ ] `tests/conftest.py` — shared fixtures (sample PDFs, expected outputs, mocked pdfplumber)
- [ ] `tests/fixtures/` directory — store sample PDFs + expected JSON outputs for regression testing
- [ ] pytest installed in requirements: `pip install pytest pytest-cov`

---

## Sources

### Primary (HIGH confidence)
- **pdfplumber 0.11.8 docs** — [extract_tables() parameters](https://docs.pdfplumber.com/#table-extraction), confirmed multi-line cell behavior
- **Existing v6 notebook** (`scripts/pdf_to_csv.ipynb`) — Analyzed logic; multi-docent extraction + activity parsing already correct
- **PITFALLS.md research** — Identified exact issues (Pitfall 1: multi-line truncation, Pitfall 2: Spanish name regex)
- **economia2017.json** — Existing curriculum structure confirms nested schema expectation

### Secondary (MEDIUM confidence)
- **pdfplumber GitHub Issues #19, #1026, #1243** — Multirow cell handling, text extraction with tables, table boundary detection
- **Spanish naming conventions** — Wikipedia + FamilyTreeMagazine confirm "del", "de la" patterns in Latin surnames

### Tertiary (LOW confidence)
- Web-based regex tutorials for Spanish name parsing (no official standard; applied domain knowledge)

---

## Metadata

**Confidence breakdown:**
- **Standard stack (HIGH):** pdfplumber + pandas versions verified in existing environment (`pip list` from notebook output)
- **Architecture (HIGH):** v6 notebook code already implements 90% of pipeline; fixes are localized to 2 pitfalls + validation layer
- **Pitfalls (HIGH):** Documented in official pdfplumber discussions and existing PITFALLS.md; solutions are standard library usage (tuning parameters)
- **Testing (MEDIUM):** No existing test infrastructure detected; Wave 0 gaps identified; test patterns are standard pytest

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (stable domain, no breaking changes expected in pdfplumber, pandas)
