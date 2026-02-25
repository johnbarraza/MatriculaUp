---
phase: 01-extraction-pipeline-fix-validation
plan: "04"
subsystem: extraction
tags: [jsonschema, validation, python, courses, curriculum, schema]

# Dependency graph
requires:
  - phase: 01-02
    provides: "CourseOfferingExtractor + input/courses_2026-1.json (253 courses)"
  - phase: 01-03
    provides: "CurriculumExtractor + input/curricula_economia2017.json (13 ciclos)"
provides:
  - "scripts/extractors/validators.py with validate_courses_json() and validate_curriculum_json()"
  - "COURSES_SCHEMA and CURRICULUM_SCHEMA (jsonschema Draft7)"
  - "Both real JSON files validated VALID: 253 cursos, 13 ciclos, 60 total curriculum courses"
  - "Phase 1 extraction pipeline complete: all 5 requirements satisfied (EXT-01 through EXT-05)"
affects:
  - phase-02-desktop-app  # App consumes input/*.json; schema defines contract

# Tech tracking
tech-stack:
  added:
    - "jsonschema>=4.20.0 (Draft7Validator, already in requirements.txt)"
  patterns:
    - "Schema-first validation: define schema as Python dicts, validate via Draft7Validator.iter_errors()"
    - "oneOf pattern for union types: CICLO_SCHEMA accepts int ciclo (0-10) OR string ciclo (concentracion/electivos)"
    - "Never-fail validation wiring: ImportError catches in extractor extract() so validators.py absence is non-fatal"
    - "Schema describes real data, not idealized data: obligatorio_concentracion tipo added after inspection"

key-files:
  created:
    - "scripts/extractors/validators.py"
  modified:
    - "scripts/extractors/courses.py (validation wired into extract() before return)"
    - "scripts/extractors/curriculum.py (validation wired into extract() before return)"

key-decisions:
  - "Schema adjusted from plan defaults to match real data: ciclo minimum=0 (ciclo cero exists), obligatorio_concentracion added to tipo enum"
  - "String ciclos ('concentracion', 'electivos') handled via oneOf[CICLO_INT_SCHEMA, CICLO_STR_SCHEMA] since real curricula has mixed int/string ciclo keys"
  - "Python 3.11 is the test runtime (not default Python 3.12/miniconda base which has broken rpds package)"
  - "Task 2 has no new file artifacts: validation-only task proved correctness but produced no commits"

patterns-established:
  - "Validation wiring: try/except ImportError guards in extractors so schema validation is non-fatal during development"
  - "Real data wins over schema assumptions: always inspect actual JSON before finalizing enum/type constraints"

requirements-completed: [EXT-04]

# Metrics
duration: 5min
completed: 2026-02-25
---

# Phase 1 Plan 04: JSON Schema Validators Summary

**jsonschema Draft7 validators for courses and curriculum JSON, wired into both extractors, with both input/*.json files passing schema validation (253 cursos, 13 ciclos)**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-02-25T04:15:35Z
- **Completed:** 2026-02-25T04:20:00Z
- **Tasks:** 2 (Task 1 committed; Task 2 was validation-only, no new files)
- **Files modified:** 3 created/modified

## Accomplishments

- Implemented `scripts/extractors/validators.py` with full `COURSES_SCHEMA` and `CURRICULUM_SCHEMA` using jsonschema Draft7Validator
- Validated real `input/courses_2026-1.json` (253 cursos) and `input/curricula_economia2017.json` (13 ciclos, 60 courses) against their schemas — both return `[]` (valid)
- Wired `validate_courses_json` and `validate_curriculum_json` into both extractors' `extract()` method before returning
- All 14 tests pass GREEN: 10 extraction tests + 4 validation tests (was 4 skipped before this plan)
- Phase 1 extraction pipeline is complete: EXT-01 through EXT-05 all satisfied

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement validators.py and wire into extractors** - `855de5f` (feat)
2. **Task 2: Validate real output files and run full test suite** - no new files; verification passed in-memory

## Files Created/Modified

- `scripts/extractors/validators.py` - Full schema definitions (SESSION_SCHEMA, SECTION_SCHEMA, COURSE_SCHEMA, COURSES_SCHEMA, CURRICULUM_COURSE_SCHEMA, CICLO_INT_SCHEMA, CICLO_STR_SCHEMA, CICLO_SCHEMA, CURRICULUM_SCHEMA) and two validator functions
- `scripts/extractors/courses.py` - Added validate_courses_json call in extract() with try/except ImportError guard
- `scripts/extractors/curriculum.py` - Added validate_curriculum_json call in extract() with try/except ImportError guard

## Decisions Made

- **Schema adjusted from plan defaults:** The plan's CICLO_SCHEMA had `"minimum": 1` but real data has ciclo 0 (Nivelacion courses). Fixed to `"minimum": 0`.
- **obligatorio_concentracion tipo:** The plan's CURRICULUM_COURSE_SCHEMA had `["obligatorio", "electivo", "other"]` but real curricula uses `"obligatorio_concentracion"`. Added to enum.
- **oneOf for ciclo field:** Real curricula has string ciclo keys ("concentracion", "electivos") alongside int keys (0-10). Used `oneOf[CICLO_INT_SCHEMA, CICLO_STR_SCHEMA]` to accept both.
- **Python 3.11 for tests:** Default Python 3.12 (miniconda base) has broken rpds package that crashes jsonschema import. Tests run with `Python311/python.exe -m pytest`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CICLO_SCHEMA minimum=0 (plan had minimum=1)**
- **Found during:** Task 2 (validating real curricula_economia2017.json)
- **Issue:** Plan schema had `"minimum": 1` on ciclo field. Real data has ciclo=0 (Nivelacion courses in Economia 2017 curriculum).
- **Fix:** Changed `"minimum": 1` to `"minimum": 0` in CICLO_INT_SCHEMA.
- **Files modified:** scripts/extractors/validators.py
- **Verification:** curricula_economia2017.json validates as VALID (13 ciclos).
- **Committed in:** 855de5f

**2. [Rule 1 - Bug] Added obligatorio_concentracion to CURRICULUM_COURSE_SCHEMA tipo enum**
- **Found during:** Task 2 (validating real curricula_economia2017.json)
- **Issue:** Plan's tipo enum was `["obligatorio", "electivo", "other"]` but CurriculumExtractor emits `"obligatorio_concentracion"` for concentration courses (8 courses).
- **Fix:** Added `"obligatorio_concentracion"` to the enum list.
- **Files modified:** scripts/extractors/validators.py
- **Verification:** curricula_economia2017.json validates as VALID (13 ciclos).
- **Committed in:** 855de5f

**3. [Rule 1 - Bug] Replaced CICLO_SCHEMA int-only type with oneOf int/str union**
- **Found during:** Task 2 (validating real curricula_economia2017.json)
- **Issue:** Plan's CICLO_SCHEMA had `"type": ["integer", "number"]` for ciclo field, but real curricula has string ciclo keys "concentracion" and "electivos" alongside int 0-10.
- **Fix:** Split into CICLO_INT_SCHEMA and CICLO_STR_SCHEMA, combined via `oneOf` in CICLO_SCHEMA.
- **Files modified:** scripts/extractors/validators.py
- **Verification:** curricula_economia2017.json validates as VALID (13 ciclos, including 2 string-keyed groups).
- **Committed in:** 855de5f

---

**Total deviations:** 3 auto-fixed (all Rule 1 bugs — schema mismatches between plan assumptions and real extracted data)
**Impact on plan:** All three fixes were discovered by inspecting the real JSON before writing the schema. Real data always wins over idealized schema assumptions. No scope creep.

## Issues Encountered

- Default Python 3.12 (miniconda base env) has broken rpds package: jsonschema imports fail with `ModuleNotFoundError: No module named 'rpds.rpds'`. Tests must be run with `C:/Users/johnb/AppData/Local/Programs/Python/Python311/python.exe`. This is the same environment issue documented in Plan 02 Summary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 1 extraction pipeline is fully complete: EXT-01 through EXT-05 all satisfied
- `input/courses_2026-1.json` (253 cursos, schema-validated) ready for Phase 2 desktop app consumption
- `input/curricula_economia2017.json` (13 ciclos, 60 courses, schema-validated) ready for Phase 2
- `scripts/extractors/validators.py` can be imported by Phase 2 or integration tests for continuous validation
- To run extraction again: `C:/Users/johnb/AppData/Local/Programs/Python/Python311/python.exe scripts/extract.py --type courses --pdf pdfs/matricula/...`
- To run tests: `C:/Users/johnb/AppData/Local/Programs/Python/Python311/python.exe -m pytest tests/`

## Self-Check: PASSED

Files verified present:
- FOUND: scripts/extractors/validators.py
- FOUND: scripts/extractors/courses.py (modified)
- FOUND: scripts/extractors/curriculum.py (modified)
- FOUND: input/courses_2026-1.json (validated VALID)
- FOUND: input/curricula_economia2017.json (validated VALID)

Commits verified:
- FOUND: 855de5f feat(01-04): implement validators.py and wire into extractors

---
*Phase: 01-extraction-pipeline-fix-validation*
*Completed: 2026-02-25*
