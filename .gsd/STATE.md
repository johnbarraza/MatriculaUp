# MatriculaUp Project State

**Last updated:** 2026-02-25
**Current phase:** Phase 1 COMPLETE — all 4/4 plans done. Ready for Phase 2.

---

## Project Reference

**Project Name:** MatriculaUp
**Core Value:** El estudiante puede ver todos los cursos ofertados del ciclo, seleccionar secciones y detectar conflictos de horario — sin abrir un solo PDF.

**One-line value:** Offline course schedule planner for Peruvian university students (UP Economía) without touching PDFs.

**Target Cycle:** 2026-1 (Economía 2017 curriculum)
**Target Platform:** Windows desktop (.exe standalone, no Python required)
**Target Users:** UP Economía students planning course schedules

---

## Current Position

**Active Phase:** Phase 5 (v1.1)

**Current Focus:**
- Ready for Phase 5 execution.

**Progress:**
[██████████] 100% (Phase 1) | [██████████] 100% (Phase 2) | [██████████] 100% (Phase 3) | [██████████] 100% (Phase 4) | [░░░░░░░░░░] 0% (Phase 5)
- Phase 1 Plans complete: 4/4
- Phase 2 Plans complete: 4/4
- Phase 3 Plans complete: 2/2
- Phase 4 Plans complete: 2/2
- Phase 5 Plans complete: 0/2 (05-01 Interactive Schedule, 05-02 Duplicate Prevention)

**Requirements Mapped:** 20/20 ✓

---

## Key Decisions Made

| Decision | Rationale | Status |
|----------|-----------|--------|
| **Stack: PySide6 + PyInstaller** | LGPL licensing (vs. PyQt6 commercial), professional widgets for timetable/grid, proven Windows bundling | Locked |
| **Architecture: Extract-once, distribute-many** | Separation of concerns (PDF handling independent of UI), pre-extracted JSON as single source of truth | Locked |
| **JSON schema (courses → sections → sessions)** | Hierarchical prerequisite logic (AND/OR trees), normalized session types (CLASE, PRÁCTICA, etc.) | Locked |
| **v1 scope: Single career, single cycle** | Economía 2017, 2026-1 only; multi-career deferred to v2 for rapid validation | Locked |
| **v1 MVP features** | Search + Schedule + Conflict + Persist + Curriculum filter + PNG export; Prerequisite validation deferred to v1.1 | Locked |
| **curricula_economia2017.json schema** | ciclos list with int (0-10) for regular cycles; string keys 'concentracion'/'electivos' for special groups | Locked |
| **extract.py sys.path injection** | Project root added to sys.path at top of script to enable `python scripts/extract.py` direct invocation | Locked |
| **validators.py schema reflects real data** | ciclo minimum=0 (ciclo cero exists), obligatorio_concentracion in tipo enum, oneOf int/str for ciclo field | Locked |
| **Python 3.11 is test runtime** | Default Python 3.12 (miniconda base) has broken rpds package; jsonschema fails. Tests: Python311/python.exe -m pytest | Locked |

---

## Critical Path & Blockers

### Phase 1 (Extraction) Blockers

**RESOLVED — Phase 1 Complete:**
- EXT-01: courses_2026-1.json generated (253 cursos, full curso/seccion/sesion structure)
- EXT-02: prerequisite truncation fixed (inline cell \n joining)
- EXT-03: compound surnames fixed (regex alternation order)
- EXT-04: JSON schema validation (validators.py, both files validate VALID)
- EXT-05: curricula_economia2017.json generated (13 ciclos, 60 courses)

### Phase 2 (Desktop App) Blockers

**High Priority:**
- PyInstaller hidden imports (pandas._libs, pdfplumber must be explicitly declared)
- File path handling (sys._MEIPASS in bundled context vs. dev paths)
- Startup time <5 seconds (--onedir preferred over --onefile to avoid antivirus scan delay)

---

## Research Flags & Gaps

**Phase 1 Research Notes:**
- PDF structure assumptions validated for Economía 2017 only
- Other careers (Derecho, Finanzas, Admin) may have different table structures — test one sample per career early
- Curriculum data quality depends on academic plan PDF completeness (may need manual review if prerequisites incomplete)

**Phase 2 Research Notes:**
- Conflict detection algorithm: Determine overlap tolerance (does 23:30-24:00 overlap with 00:00-07:30? Assume not — different days)
- Timetable rendering: Decide grid resolution (30-min blocks?) and color palette (accessibility: colorblind friendly)
- Session type icons/labels: Ensure students understand CLASE vs. PRÁCTICA vs. PARCIAL distinctions

---

## Accumulated Context

### Architecture Decisions

**Data Layer:**
- Pre-extracted JSON files (courses.json, curricula.json, prerequisites.json) bundled with .exe
- Loaded into memory at startup (in-memory store)
- Single source of truth — UI never modifies data, only reads

**UI Layer:**
- PySide6 main window with tabbed interface:
  - Tab 1: Course Search & Selector
  - Tab 2: Schedule Builder (timetable grid)
  - Tab 3: Curriculum Tracker (if plan selected)
  - Tab 4: Saved Schedules (3 slots)

**Persistence Layer:**
- User schedules saved to AppData\Local\MatriculaUp\data.json (Windows standard)
- Survives app updates and version upgrades
- No cloud sync (offline-first, v2+)

### Feature Scope

**v1 Must-Have:**
- Course search (name, code, instructor)
- Session type filter
- Section selection
- Visual weekly timetable (Mon-Fri, 7:30-23:30)
- Conflict detection with details
- Save/load 3 schedules
- Curriculum awareness (mark courses as required/elective/other)
- PNG export of timetable

**v1.x (After User Feedback):**
- Prerequisite validation (warn before selecting courses with unmet reqs)
- Multi-semester planning (2026-1 + 2026-2 together)
- Schedule optimization hints

**v2+ (Deferred):**
- Multi-career support
- Prerequisite evaluation against completed courses
- Real-time UP integration (out of scope, offline-first)

---

## Open Questions

1. **Conflict detection edge cases:** Should the app allow same course section twice? (Probably no.) Should it warn about back-to-back courses with no break? (Nice to have.)

2. **Session type labeling:** Show "PRÁCTICA" vs. "PRACTICE"? (Spanish only for UP students, so use Spanish labels.)

3. **Curriculum completeness:** If curriculum JSON is incomplete (missing prerequisite chains), should app warn user? (Yes, flag missing data at startup.)

4. **PNG export quality:** Target DPI for PNG export? (96 DPI screen resolution sufficient; no print quality needed.)

   (v1.1: Add JSON update from GitHub releases; v2+: Full multi-cycle support.)

6. **User Requests for Next Milestone (v1.1 / Phase 5):**
   - Ver horario semanal interactivo al mismo tiempo que se buscan/agregan cursos.
   - Restricción: No permitir agregar la misma materia (aunque sea otra sección).
   - Prevención de cruces visual: antes de agregar, que la lista de secciones indique si choca con el horario actual.
   - Vistas separadas (Pestañas) para horario de CLASES/PRÁCTICAS vs horarios de EXÁMENES (FINAL/PARCIAL).
   - En la grilla mostrar el nombre del curso, no solo el tipo de sesión.
   - Opción para cargar un JSON externo desde la interfaz de la app.

---

## Performance & Success Metrics (Post-Launch)

**Not tracked yet; define after Phase 4:**
- Installer download count (adoption baseline)
- Startup time on real hardware (target <5 sec)
- User feedback survey (prerequisite validation demand? multi-semester demand?)
- Error rates (app crashes, data validation failures)

---

## Session Notes

### Session 1 (2026-02-24): Roadmap Creation

**Completed:**
- Read PROJECT.md, REQUIREMENTS.md, research SUMMARY.md, config.json
- Validated phase structure (4 phases, aligned with research recommendations)
- Created ROADMAP.md with success criteria derived from requirements
- Created STATE.md with project reference and decision log
- Confirmed 100% requirement coverage (20/20 requirements mapped)

### Session 2 (2026-02-25): Phase 1 Plan 01 Execution

**Completed (01-01-PLAN.md — TDD Wave 0 Test Scaffolding):**
- Created tests/fixtures/sample_rows.py with 5 named constants (COURSE_HEADER_ROW, PREREQ_ROW_TRUNCATED, PREREQ_ROW_CONTINUATION, SECTION_ROW_CLASE, PROFESSOR_COMPOUND_ROW)
- Created tests/conftest.py with 4 shared pytest fixtures
- Created tests/test_extraction.py (8 RED tests for EXT-02, EXT-03)
- Created tests/test_validation.py (4 RED tests for EXT-04)
- Updated requirements.txt with pytest>=8.0.0, pytest-cov>=5.0.0, pdfplumber>=0.11.8, jsonschema>=4.20.0
- All 12 tests skip cleanly (correct RED baseline — no false greens)
- Commits: 891b88a (fixtures + conftest), ea498be (RED tests)

**Key Decisions (this session):**
- Used try/except ImportError + pytest.mark.skipif so tests skip without implementation rather than error at collection
- PROFESSOR_COMPOUND_ROW stored as raw string (not list row) matching real pdfplumber cell text
- Added tests/__init__.py for absolute import resolution from conftest.py

**Stopped at:** Completed 01-02-PLAN.md

### Session 3 (2026-02-25): Phase 1 Plan 03 Execution

**Completed (01-03-PLAN.md — CurriculumExtractor):**
- Inspected curriculum PDF: 1 page, 3 tables (obligatorias/concentracion/electivos)
- Discovered dual code-layout pattern: ciclo 0 has individual codes per row; ciclos 1-10 batch codes in header row
- Added TestCurriculumStructure class to tests/test_extraction.py (2 tests)
- Created scripts/extractors/curriculum.py (CurriculumExtractor with 3 private parse functions)
- Created scripts/extract.py CLI entry point with sys.path fix
- Created scripts/__init__.py, scripts/extractors/__init__.py packages
- Included scripts/extractors/base.py (BaseExtractor ABC)
- Generated input/curricula_economia2017.json: 11 ciclos (0-10), 60 total courses, 0 warnings
- All TestCurriculumStructure tests pass (2/2)
- Commits: 73cac8c (tests), 7d8a869 (extractor + output)

**Key Decisions (this session):**
- curricula_economia2017.json ciclos list uses int for regular cycles (0-10) and string for special groups ('concentracion', 'electivos')
- sys.path injection in extract.py enables `python scripts/extract.py` direct invocation
- Ciclo 0 detection: check if continuation row has its own code in Codigo column before falling back to pending_codes list

**Next Steps:**
- Execute 01-04-PLAN.md — Validation layer (scripts/extractors/validators.py)
- test_validation.py currently 4 skipped — Plan 04 should make them GREEN

### Session 4 (2026-02-25): Phase 1 Plan 02 Execution

**Completed (01-02-PLAN.md — CourseOfferingExtractor + courses_2026-1.json):**
- Implemented scripts/extractors/courses.py: is_truncated_prerequisite, extract_professors_spanish, extract_prerequisites_with_continuation, parse_prerequisite_tree, CourseOfferingExtractor
- Fixed EXT-03: PROF_PATTERN regex alternation order bug (del before de) — "Del Rosario" now captured in full
- Fixed EXT-02: real PDF prereqs are inline cells with \n (not continuation rows) — joined with space
- Created pytest.ini to disable broken pytest-qt plugin in conda 'up' env
- Updated scripts/extract.py CLI to use CourseOfferingExtractor
- Generated input/courses_2026-1.json: 253 courses, 0 truncated prereqs, compound surnames captured
- All 10 tests in test_extraction.py pass GREEN
- Commits: 2a352a5 (extractor), a1684d2 (CLI + JSON output)

**Key Decisions (this session):**
- Real 2026-1 PDF prerequisites are inline in course header row column 4 (not separate continuation rows)
- Regex alternation: [Dd]el must precede [Dd]e to avoid "Del" matching as just "De"
- Cycle detection normalizes Roman numeral: "2026-I" -> "2026-1" for consistent JSON filenames
- pytest.ini with addopts = -p no:qt required to unblock test collection in conda 'up' env

**Stopped at:** Completed 01-02-PLAN.md — CourseOfferingExtractor + courses_2026-1.json

### Session 5 (2026-02-25): Phase 1 Plan 04 Execution

**Completed (01-04-PLAN.md — JSON Schema Validators):**
- Created scripts/extractors/validators.py with COURSES_SCHEMA and CURRICULUM_SCHEMA (Draft7Validator)
- Adjusted schema from plan defaults: ciclo minimum=0, obligatorio_concentracion tipo, oneOf for string/int ciclo keys
- Wired validate_courses_json into CourseOfferingExtractor.extract() before return
- Wired validate_curriculum_json into CurriculumExtractor.extract() before return
- Validated real input/courses_2026-1.json (253 cursos): VALID
- Validated real input/curricula_economia2017.json (13 ciclos): VALID
- All 14 tests pass GREEN (was 4 skipped before this plan)
- Commits: 855de5f (validators.py + wiring)

**Key Decisions (this session):**
- Schema adjusted from plan defaults: ciclo minimum=0, obligatorio_concentracion tipo, oneOf int/str ciclo
- Real data wins over schema assumptions: always inspect actual JSON before finalizing enum/type constraints
- Python 3.11 is test runtime (miniconda base Python 3.12 has broken rpds package)

**Stopped at:** Completed 01-04-PLAN.md — Phase 1 COMPLETE

---

*State file created: 2026-02-24*
*Last updated: 2026-02-25*
*Phase 1: 4/4 plans complete (01-01, 01-02, 01-03, 01-04) — PHASE COMPLETE*
