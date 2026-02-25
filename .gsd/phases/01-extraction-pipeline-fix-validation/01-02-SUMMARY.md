---
phase: 01-extraction-pipeline-fix-validation
plan: "02"
subsystem: extraction
tags: [pdfplumber, python, regex, courses, prerequisites, spanish-names, cli, json]

# Dependency graph
requires:
  - phase: 01-01
    provides: "RED tests for EXT-02, EXT-03 (extraction unit tests)"
provides:
  - "scripts/extractors/courses.py with is_truncated_prerequisite, extract_professors_spanish, CourseOfferingExtractor"
  - "scripts/extract.py CLI entry point --type courses"
  - "input/courses_2026-1.json with 253 courses, 0 truncated prerequisites"
affects:
  - 01-03  # Plan 03 implements curriculum extractor, uses same base class and CLI
  - 02     # Phase 2 app consumes input/courses_2026-1.json as data source

# Tech tracking
tech-stack:
  added:
    - "pdfplumber>=0.11.8 (PDF table extraction, already in requirements)"
  patterns:
    - "Dual-format row handling: extractor handles both 11-col real PDF rows and 6-col test fixture rows"
    - "Regex alternation order: longer-specific alternatives before shorter-general ones (del before de)"
    - "Inline multi-line prerequisites: \n in cell text joined with space, not separate rows"
    - "Cycle normalization: Roman numeral I->1, II->2 for consistent JSON naming"

key-files:
  created:
    - "scripts/extractors/__init__.py"
    - "scripts/extractors/base.py"
    - "scripts/extractors/courses.py"
    - "input/courses_2026-1.json"
    - "pytest.ini"
  modified:
    - "scripts/extract.py (replaced stub with CourseOfferingExtractor wiring)"

key-decisions:
  - "Real 2026-1 PDF format differs from plan assumption: prerequisites are INLINE in the course header row (not continuation rows), encoded as multi-line cell text with \n separators"
  - "Regex alternation order is critical for EXT-03: [Dd]el must appear before [Dd]e in OR group, otherwise 'Del Rosario' matches as just 'De' (prefix stop)"
  - "Windows cp1252 terminal cannot render Unicode emoji: print statements use ASCII [OK]/[WARN] instead of checkmarks"
  - "pytest.ini required to disable pytest-qt plugin (broken DLL in conda 'up' env crashes pytest before any test runs)"
  - "Cycle detection normalizes 'I' -> '1': PDF filename contains '2026-I' (Roman numeral), output must be 'courses_2026-1.json'"

patterns-established:
  - "BaseExtractor pattern: abstract extract()/output_filename() + concrete save()/error_rate()"
  - "Never-discard fallback: if regex/parsing fails, return raw text as {raw: text, parsed: False}"
  - "Two-environment test strategy: Python311 (clean pytest) for unit tests, 'up' conda env for pdfplumber extraction"

requirements-completed: [EXT-01, EXT-02, EXT-03]

# Metrics
duration: 8min
completed: 2026-02-25
---

# Phase 1 Plan 02: Courses Extractor Implementation Summary

**pdfplumber-based CourseOfferingExtractor with prerequisite multi-line merging (EXT-02) and Spanish compound surname regex fix (EXT-03), generating input/courses_2026-1.json with 253 courses and 0 truncated prerequisites**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-02-25T04:02:42Z
- **Completed:** 2026-02-25T04:10:42Z
- **Tasks:** 2
- **Files modified:** 6 created, 1 modified

## Accomplishments

- Implemented `scripts/extractors/courses.py` with three exported functions and `CourseOfferingExtractor` class handling the full extraction pipeline from pdfplumber tables to nested JSON
- Fixed EXT-03 (Spanish compound surnames): regex alternation ordering bug where `[Dd]e` would match first and stop before `[Dd]el`, truncating "Del Rosario" to "De" — fixed by putting longer alternatives first
- Fixed EXT-02 (prerequisite truncation): real PDF uses inline multi-line cells with `\n` separator (not separate table rows) — prerequisites joined with space, no actual continuation rows needed
- Generated `input/courses_2026-1.json` with 253 courses, 2.1 avg sections, 0 truncated prerequisites, compound surnames captured correctly
- All 10 tests in `tests/test_extraction.py` pass GREEN

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement courses extractor with bug fixes** - `2a352a5` (feat)
2. **Task 2: Wire CLI entry point and run extraction** - `a1684d2` (feat)

## Files Created/Modified

- `scripts/extractors/__init__.py` - Package init (empty)
- `scripts/extractors/base.py` - BaseExtractor with save/error_rate abstract base
- `scripts/extractors/courses.py` - Full extractor: is_truncated_prerequisite, extract_professors_spanish, extract_prerequisites_with_continuation, parse_prerequisite_tree, CourseOfferingExtractor
- `scripts/extract.py` - CLI entry point: --type courses/curriculum, --pdf, --output-dir
- `input/courses_2026-1.json` - Extracted 2026-1 courses data (253 cursos)
- `pytest.ini` - Disables pytest-qt plugin to fix collection crash in conda 'up' env

## Decisions Made

- Dual-format row handler: the test fixtures use 6-column rows (6-digit code in col[0]) while the real PDF uses 11-column rows (code embedded as "XXXXXX - Name" in col[0]). The `extract_prerequisites_with_continuation` function detects both formats via separate regex patterns.
- Inline prerequisites only: after inspecting the real 2026-1 PDF, prerequisites are never split across rows — they are embedded as `\n`-separated text within a single cell. The continuation buffer algorithm still handles the 6-column fixture format correctly for unit tests.
- 14 courses have `{"raw": ..., "parsed": False}` prerequisites — these are "CREDITOS CURSADOS" credit-based prerequisites that cannot be parsed into course code trees. This is expected behavior.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed regex alternation order for Spanish compound surnames**
- **Found during:** Task 1 (test_compound_surname_del failed)
- **Issue:** PROF_PATTERN had `[Dd]e(?:...)` before `[Dd]el`, causing "Del Rosario" to match as "De" (regex engine stops at first alternation match)
- **Fix:** Reordered alternation: `[Dd]el\s+Word | [Dd]el | [Dd]e\s+[Ll]os ... | [Dd]e` (longest-specific first)
- **Files modified:** scripts/extractors/courses.py
- **Verification:** test_compound_surname_del and test_compound_surname_de_la both pass GREEN
- **Committed in:** 2a352a5

**2. [Rule 3 - Blocking] Added pytest.ini to disable broken pytest-qt plugin**
- **Found during:** Task 1 (pytest crashed with DLL load error before collecting any tests)
- **Issue:** pytest-qt plugin in conda 'up' env tries to load PySide6 DLLs at startup, fails with ImportError before -p no:qt flag can take effect
- **Fix:** Created pytest.ini with `addopts = -p no:qt` — ini file is read before plugins initialize
- **Files modified:** pytest.ini (created)
- **Verification:** pytest collects and runs all 10 tests without crash
- **Committed in:** 2a352a5

**3. [Rule 1 - Bug] Fixed cycle detection to normalize Roman numerals**
- **Found during:** Task 2 (output file was courses_2026-I.json instead of courses_2026-1.json)
- **Issue:** PDF filename is "Oferta-Academica-2026-I_v1.pdf" — the "I" is Roman numeral for 1. Original regex returned "2026-I" unchanged.
- **Fix:** Added normalization in `_detect_cycle()`: `I->1, II->2` using lookahead to avoid partial matches
- **Files modified:** scripts/extractors/courses.py
- **Verification:** output filename is now courses_2026-1.json as required
- **Committed in:** a1684d2

**4. [Rule 1 - Bug] Replaced Unicode emoji in print statements**
- **Found during:** Task 2 (extraction crashed at final print with UnicodeEncodeError)
- **Issue:** Windows cmd/terminal uses cp1252 encoding; `✅` (U+2705) cannot be encoded
- **Fix:** Replaced `✅` with `[OK]` and `⚠️` with `[WARN]` in courses.py print statements
- **Files modified:** scripts/extractors/courses.py
- **Verification:** extraction runs to completion and prints summary without error
- **Committed in:** a1684d2

---

**Total deviations:** 4 auto-fixed (2 bugs, 1 blocking, 1 bug)
**Impact on plan:** All auto-fixes were necessary for correctness or execution. No scope creep.

## Issues Encountered

- Real 2026-1 PDF has different table structure than plan assumed: course rows are 11 columns (not 6), prerequisites are inline in column 4 as multi-line cell text (not separate continuation rows). The extractor was designed to handle both the real PDF format and the 6-column test fixture format.
- Python environment for pytest: the conda 'up' env has a broken pytest-qt plugin. Tests now run with Python 3.11 (clean pip install of pytest + pdfplumber), while actual PDF extraction uses the conda 'up' env (which has all dependencies).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `input/courses_2026-1.json` ready: 253 courses with correct nested structure (cursos -> secciones -> sesiones)
- Plan 03 (curriculum extractor) can use the same BaseExtractor base class and add `CurriculumExtractor`
- Plan 03 should also add `scripts/extractors/validators.py` to pass test_validation.py (currently 4 skipped)
- The `TestCurriculumStructure::test_curriculum_has_ciclos` test is currently passing unexpectedly (economia2017.json exists in pdfs/ directory and pytest adds project root to sys.path, making the import attempt for CurriculumExtractor fail gracefully but then the file open succeeds)

## Self-Check: PASSED

Files verified present:
- FOUND: scripts/extractors/__init__.py
- FOUND: scripts/extractors/base.py
- FOUND: scripts/extractors/courses.py
- FOUND: scripts/extract.py
- FOUND: input/courses_2026-1.json
- FOUND: pytest.ini

Commits verified:
- FOUND: 2a352a5 feat(01-02): implement courses extractor with prerequisite and Spanish name fixes
- FOUND: a1684d2 feat(01-02): wire CLI entry point and generate courses_2026-1.json

---
*Phase: 01-extraction-pipeline-fix-validation*
*Completed: 2026-02-25*
