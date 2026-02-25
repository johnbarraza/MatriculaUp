---
phase: 01-extraction-pipeline-fix-validation
verified: 2026-02-24T12:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
human_verification: []
---

# Phase 1: Extraction Pipeline Fix & Validation — Verification Report

**Phase Goal:** Fix the extraction pipeline so it produces trustworthy JSON data files (courses + curriculum) with no truncation bugs, correct Spanish name handling, and schema-validated output.
**Verified:** 2026-02-24
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `courses_2026-1.json` exists with 50+ courses (codigo, nombre, creditos, secciones) | VERIFIED | 253 courses confirmed via `json.load` |
| 2 | No prerequisite in `courses_2026-1.json` ends with 'Y (' or 'O (' (truncation bug fixed) | VERIFIED | `trunc=0` via truncation check; 14 unparsed are CREDITOS CURSADOS entries (credit-hour prereqs, not truncated logic) |
| 3 | Professor names with 'Del', 'De La', 'De Los' are captured in full | VERIFIED | 2 compound-surname professors found in real data; `extract_professors_spanish('CASTROMATTA, Milagros Del Rosario')` returns `['CASTROMATTA, Milagros Del Rosario']` |
| 4 | `validate_courses_json(courses_2026-1.json)` returns `[]` and `validate_curriculum_json(curricula_economia2017.json)` returns `[]` | VERIFIED | Both validators return empty list; confirmed by direct Python invocation |
| 5 | `curricula_economia2017.json` exists with ciclos 0-10 plus string groups (concentracion, electivos) | VERIFIED | 13 groups total: ciclos 0-10 (11 groups) + concentracion (8 courses) + electivos (10 courses) = 60 total |

**Score:** 5/5 truths verified

---

## Required Artifacts

### Plan 01-01 (TDD Scaffolding)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/conftest.py` | Shared fixtures: sample rows, minimal_valid_course | VERIFIED | 4 fixtures present; imports from `tests.fixtures.sample_rows` confirmed |
| `tests/fixtures/sample_rows.py` | 5 named constants matching PDF row format | VERIFIED | `COURSE_HEADER_ROW`, `PREREQ_ROW_TRUNCATED`, `PREREQ_ROW_CONTINUATION`, `SECTION_ROW_CLASE`, `PROFESSOR_COMPOUND_ROW` all present |
| `tests/test_extraction.py` | Unit tests for prereq continuation and Spanish name regex | VERIFIED | 10 tests pass GREEN (TestPrerequisiteContinuation x4, TestProfessorSpanishNames x4, TestCurriculumStructure x2) |
| `tests/test_validation.py` | JSON schema compliance tests | VERIFIED | 4 tests pass GREEN |
| `requirements.txt` | pytest>=8.0.0, pytest-cov>=5.0.0 added | VERIFIED | Confirmed in 01-01-SUMMARY key-decisions; pytest 9.0.2 installed |

### Plan 01-02 (Courses Extractor)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/extractors/courses.py` | CourseOfferingExtractor + exported functions | VERIFIED | 814 lines; exports `is_truncated_prerequisite`, `extract_professors_spanish`, `extract_prerequisites_with_continuation`, `parse_prerequisite_tree`, `CourseOfferingExtractor` |
| `scripts/extract.py` | CLI entry point --type courses/curriculum | VERIFIED | Accepts `--type`, `--pdf`, `--output-dir`; CourseOfferingExtractor wired at line 15, 32 |
| `input/courses_2026-1.json` | Extracted 2026-1 courses data | VERIFIED | 253 courses, metadata `ciclo: "2026-1"`, `fecha_extraccion: "2026-02-24"` |

### Plan 01-03 (Curriculum Extractor)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/extractors/curriculum.py` | CurriculumExtractor for Economia 2017 PDF | VERIFIED | Full implementation with `_extract_table1_ciclos`, `_extract_table2_concentracion`, `_extract_table3_electivos` private methods; 300+ lines |
| `input/curricula_economia2017.json` | Curriculum by academic cycle | VERIFIED | 13 groups: ciclos 0-10, concentracion, electivos; 60 total courses |

### Plan 01-04 (Validators)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/extractors/validators.py` | validate_courses_json, validate_curriculum_json, COURSES_SCHEMA, CURRICULUM_SCHEMA | VERIFIED | 183 lines; all 4 exports present; Draft7Validator used |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `tests/conftest.py` | `tests/test_extraction.py` | pytest fixtures auto-imported | WIRED | `sample_truncated_prereq_rows`, `sample_complete_prereq_rows`, `sample_professor_text`, `minimal_valid_course` used by test classes |
| `tests/test_extraction.py` | `scripts/extractors/courses.py` | `from scripts.extractors.courses import` | WIRED | All import targets present; 14/14 tests pass (0 skipped) |
| `scripts/extract.py` | `scripts/extractors/courses.py` | `from scripts.extractors.courses import CourseOfferingExtractor` (line 15) | WIRED | Direct import at module level; instantiated at line 32 |
| `scripts/extract.py` | `scripts/extractors/curriculum.py` | lazy `from scripts.extractors.curriculum import CurriculumExtractor` (line 36) | WIRED | Lazy import on `--type curriculum`; confirmed present in file |
| `scripts/extractors/courses.py` | `pdfplumber` | `import pdfplumber` inside `extract()`, `pdfplumber.open(str(self.pdf_path))` (line 562) | WIRED | PDF opened and tables extracted per page |
| `scripts/extractors/courses.py` | `scripts/extractors/validators.py` | `from scripts.extractors.validators import validate_courses_json` (line 623) | WIRED | Called inside `extract()` before return; try/except guard for non-fatal if absent |
| `scripts/extractors/curriculum.py` | `scripts/extractors/validators.py` | `from scripts.extractors.validators import validate_curriculum_json` (line 305) | WIRED | Called inside `extract()` before return; try/except guard |
| `tests/test_validation.py` | `scripts/extractors/validators.py` | `from scripts.extractors.validators import validate_courses_json, validate_curriculum_json` | WIRED | 4 tests pass GREEN; was 4 skipped before Plan 04 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| EXT-01 | 01-02 | Extractor procesa PDF de oferta académica y genera courses.json con cursos, secciones y sesiones | SATISFIED | `courses_2026-1.json`: 253 cursos, each with `secciones[]` containing `sesiones[]` |
| EXT-02 | 01-01, 01-02 | Prerequisitos con lógica compuesta (Y/O multi-fila) se parsean completos sin truncar | SATISFIED | 0 truncated-string prereqs; 14 `{"raw": ..., "parsed": False}` entries are credit-hour requirements, not truncated logic |
| EXT-03 | 01-01, 01-02 | Nombres de docentes con apellidos compuestos (Del, De La, De Los) se capturan completos | SATISFIED | PROF_PATTERN regex has del before de in alternation; 2 real compound-surname professors in extracted data; unit tests pass |
| EXT-04 | 01-04 | JSON generado validado contra esquema definido (curso → secciones → sesiones) | SATISFIED | `validate_courses_json()` returns `[]` for 253-course file; `validate_curriculum_json()` returns `[]` for 13-ciclo file |
| EXT-05 | 01-03 | Extractor procesa PDF plan de estudios Economía 2017 y genera curricula_economia2017.json con cursos por ciclo | SATISFIED | `curricula_economia2017.json`: 13 ciclos (0-10, concentracion, electivos), 60 total courses |

**No orphaned requirements.** REQUIREMENTS.md maps EXT-01 through EXT-05 to Phase 1 only. All 5 claimed and verified.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `input/courses_2026-I.json` | N/A | Stale pre-fix artifact with `ciclo: "2026-I"` (Roman numeral, unnormalized) | INFO | Does not affect current output; `courses_2026-1.json` is the correct file. The Roman-numeral fix was applied after this file was created. File is harmless but should be deleted during cleanup. |

No BLOCKER or WARNING anti-patterns found in implementation files. The `return []` occurrences in extractor/validator code are intentional: `extract_professors_spanish` returns `[]` for empty input, and validators return `[]` when no errors exist — both correct.

---

## Human Verification Required

None. All goal-critical behaviors are verifiable programmatically:
- Test suite runs headlessly with deterministic output
- JSON files are loadable and schema-checkable
- Regex functions are unit-testable with fixed inputs

---

## Gaps Summary

No gaps. All 5 requirements verified, all artifacts substantive and wired, all key links confirmed, 14/14 tests passing.

**One informational note:** `input/courses_2026-I.json` is a stale artifact from before the Roman-numeral normalization fix was applied (it has `ciclo: "2026-I"` in its metadata). It does not affect correctness — `courses_2026-1.json` is the canonical output file used by all validators and downstream consumers. The stale file warrants cleanup but does not block the phase goal.

---

_Verified: 2026-02-24_
_Verifier: Claude (gsd-verifier)_
