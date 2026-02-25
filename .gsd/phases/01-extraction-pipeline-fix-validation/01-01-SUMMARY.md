---
phase: 01-extraction-pipeline-fix-validation
plan: "01"
subsystem: testing
tags: [pytest, pdfplumber, jsonschema, tdd, fixtures, extraction, spanish-names, prerequisites]

# Dependency graph
requires: []
provides:
  - "pytest test infrastructure with 12 RED tests covering EXT-02, EXT-03, EXT-04"
  - "tests/fixtures/sample_rows.py with hard-coded rows matching 2026-1 Economia PDF format"
  - "tests/conftest.py with shared fixtures (sample rows, minimal_valid_course)"
  - "requirements.txt updated with pytest>=8.0.0, pytest-cov>=5.0.0, pdfplumber>=0.11.8, jsonschema>=4.20.0"
affects:
  - 01-02  # Plan 02 implements scripts/extractors/courses.py to pass these RED tests
  - 01-03  # Plan 03 implements scripts/extractors/validators.py to pass validation tests

# Tech tracking
tech-stack:
  added:
    - "pytest>=8.0.0 (test runner)"
    - "pytest-cov>=5.0.0 (coverage reporting)"
    - "pdfplumber>=0.11.8 (PDF extraction, added to requirements)"
    - "jsonschema>=4.20.0 (schema validation, added to requirements)"
  patterns:
    - "TDD RED-GREEN-REFACTOR: test scaffolding written before implementation"
    - "try/except ImportError guard: tests skip cleanly when implementation absent"
    - "pytest.mark.skipif per-class: skips propagate without collection errors"
    - "Fixture constants in fixtures/sample_rows.py: mimic real PDF row format"

key-files:
  created:
    - "tests/__init__.py"
    - "tests/fixtures/__init__.py"
    - "tests/fixtures/sample_rows.py"
    - "tests/conftest.py"
    - "tests/test_extraction.py"
    - "tests/test_validation.py"
  modified:
    - "requirements.txt (appended pdfplumber, jsonschema, pytest, pytest-cov)"

key-decisions:
  - "Used try/except ImportError + pytest.mark.skipif so test collection succeeds without implementation; tests skip rather than error, giving cleaner RED baseline"
  - "PROFESSOR_COMPOUND_ROW stored as raw string (not list row) because professor text is extracted as a single cell value, not a row tuple"
  - "tests/__init__.py added to enable 'from tests.fixtures.sample_rows import ...' absolute imports from conftest.py"
  - "Fixture sample rows use None for empty columns (not empty string) to match pdfplumber's default None fill for empty cells"

patterns-established:
  - "Fixture pattern: hard-coded sample rows in tests/fixtures/sample_rows.py, shared via conftest.py fixtures"
  - "Guard pattern: try/except ImportError at module top, skip_if_no_modules mark applied per class"
  - "TDD wave pattern: Wave 0 = RED scaffolding, Wave 1 = GREEN implementation, Wave 2 = integration"

requirements-completed: [EXT-02, EXT-03]

# Metrics
duration: 2min
completed: 2026-02-25
---

# Phase 1 Plan 01: Test Scaffolding (TDD Wave 0) Summary

**12-test pytest RED baseline covering prerequisite continuation (EXT-02), Spanish compound surnames (EXT-03), and JSON schema compliance (EXT-04) — all skip cleanly until Plan 02 creates scripts/extractors/**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-25T03:55:39Z
- **Completed:** 2026-02-25T03:57:32Z
- **Tasks:** 2
- **Files modified:** 6 created, 1 modified

## Accomplishments

- Created tests/fixtures/sample_rows.py with 5 named constants matching real 2026-1 Economia PDF table rows including truncated prerequisite pattern and compound Spanish surname example
- Created tests/conftest.py with 4 shared fixtures covering truncated/complete prereq rows, professor text, and minimal valid course dict
- Created 12 RED tests (8 extraction + 4 validation) that skip cleanly until implementation modules exist; pytest collects all 12 without errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Create test fixtures and conftest** - `891b88a` (feat)
2. **Task 2: Write failing unit tests (RED phase)** - `ea498be` (test)

**Plan metadata:** `5042a4d` (docs: complete test scaffolding plan)

## Files Created/Modified

- `tests/__init__.py` - Package init enabling absolute imports
- `tests/fixtures/__init__.py` - Package init for fixture subpackage
- `tests/fixtures/sample_rows.py` - 5 constants: COURSE_HEADER_ROW, PREREQ_ROW_TRUNCATED, PREREQ_ROW_CONTINUATION, SECTION_ROW_CLASE, PROFESSOR_COMPOUND_ROW
- `tests/conftest.py` - 4 pytest fixtures: sample_truncated_prereq_rows, sample_complete_prereq_rows, sample_professor_text, minimal_valid_course
- `tests/test_extraction.py` - 8 tests (TestPrerequisiteContinuation x4, TestProfessorSpanishNames x4)
- `tests/test_validation.py` - 4 tests (TestJsonSchemaCompliance x4)
- `requirements.txt` - Added pdfplumber>=0.11.8, jsonschema>=4.20.0, pytest>=8.0.0, pytest-cov>=5.0.0

## Decisions Made

- Used try/except ImportError guard so test collection succeeds without implementation; tests skip rather than error, giving cleaner RED baseline feedback
- PROFESSOR_COMPOUND_ROW is a raw string (not a list), matching how pdfplumber returns professor cell text from a section row
- Added tests/__init__.py to enable absolute imports (`from tests.fixtures.sample_rows import ...`) from conftest.py
- Sample rows use None for empty columns to match pdfplumber's default behavior for empty cells

## Deviations from Plan

None - plan executed exactly as written. The try/except ImportError pattern from the plan was implemented as specified. The `__init__.py` files were an obvious necessity for Python import resolution (Rule 3 - blocking, auto-fixed inline).

## Issues Encountered

None - fixture import worked on first attempt; pytest collection succeeded immediately with 12 tests all skipping correctly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- RED baseline established: `pytest tests/ -q` shows `12 skipped` confirming no false greens
- Plan 02 must create `scripts/extractors/__init__.py`, `scripts/extractors/courses.py` with `extract_prerequisites_with_continuation`, `is_truncated_prerequisite`, and `extract_professors_spanish`
- Plan 03 must create `scripts/extractors/validators.py` with `validate_courses_json` and `validate_curriculum_json`
- Run `pytest tests/ -v` after Plan 02 implementation to confirm tests transition from skipped to passed

## Self-Check: PASSED

All created files verified present on disk:
- FOUND: tests/__init__.py
- FOUND: tests/fixtures/__init__.py
- FOUND: tests/fixtures/sample_rows.py
- FOUND: tests/conftest.py
- FOUND: tests/test_extraction.py
- FOUND: tests/test_validation.py
- FOUND: requirements.txt
- FOUND: .planning/phases/01-extraction-pipeline-fix-validation/01-01-SUMMARY.md

Commits verified:
- FOUND: 891b88a feat(01-01): create test fixtures and conftest for extraction pipeline
- FOUND: ea498be test(01-01): add failing RED tests for extraction and validation (TDD wave 0)

---
*Phase: 01-extraction-pipeline-fix-validation*
*Completed: 2026-02-25*
