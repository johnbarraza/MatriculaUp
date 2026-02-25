# Codebase Concerns

**Analysis Date:** 2026-02-24

## Tech Debt

**Bare Exception Handlers:**
- Issue: Multiple `except:` clauses without exception type specification catch all exceptions including KeyboardInterrupt and SystemExit
- Files: `scripts/matricula_app.py` (lines 27, 512, 535, 609, 826, 955, 977), `scripts/schedule-builder.py` (lines 13, 348, 373, 510, 520, 716)
- Impact: Errors are silently swallowed with generic fallback values (e.g., `return 0.0`), making debugging difficult and hiding actual problems
- Fix approach: Replace bare `except:` with specific exception types like `except ValueError:` or `except (ValueError, TypeError):`. Log exceptions before returning fallback values.

**Hardcoded Time Constants:**
- Issue: Schedule grid generation and visualization use hardcoded time values (7:30 AM, 23:30 PM) scattered throughout code
- Files: `scripts/schedule-builder.py` (lines 259, 719), `scripts/matricula_app.py` (similar patterns in visualization methods)
- Impact: Difficult to maintain time range consistency; changing hours requires multiple edits in different files
- Fix approach: Extract time constants to module-level variables (e.g., `START_TIME = "07:30"`, `END_TIME = "23:30"`) and cell calculations

**Magic Numbers in Grid Calculations:**
- Issue: Canvas drawing logic uses hardcoded pixel values and time slot calculations
- Files: `scripts/schedule-builder.py` (cell_width=120, cell_height=30, first_col_width=80, header_height=40)
- Impact: Scaling schedule views, adjusting cell sizes, or adding more time slots requires recomputing all positions manually
- Fix approach: Create constants or configuration class for layout parameters. Calculate positions programmatically from these values.

**Code Duplication Between schedule-builder.py and matricula_app.py:**
- Issue: Core functionality duplicated across files (normalize_str, parse_credits, match_keywords, conflict detection logic)
- Files: Both `scripts/schedule-builder.py` and `scripts/matricula_app.py` contain identical utility functions
- Impact: Bug fixes must be applied in two places; maintenance overhead increases with each file
- Fix approach: Extract shared utilities to `scripts/utils.py`. Import from both applications.

**Missing .planning/codebase Directory Structure:**
- Issue: The `.planning/codebase/` directory does not exist yet
- Files: N/A (directory structure)
- Impact: Architecture documentation cannot be written until directory is created
- Fix approach: Create `.planning/codebase/` directory to store STACK.md, ARCHITECTURE.md, etc.

## Known Bugs

**Credit Calculation Underflow:**
- Symptoms: Credits can display negative values in edge cases (e.g., rapid conflict removal)
- Files: `scripts/schedule-builder.py` (lines 551-552, 645), `scripts/matricula_app.py` (line 559)
- Trigger: Remove conflicting courses quickly before UI refresh completes
- Workaround: Code includes `max(0.0, ...)` guards but only in some locations; not consistently applied
- Recommendation: Ensure all credit deduction operations use `max(0.0, new_value)` guard uniformly

**PNG Export Path Resolution Issue:**
- Symptoms: `schedule-builder.py` saves PNG files to current working directory without explicit path
- Files: `scripts/schedule-builder.py` (line 810)
- Trigger: When app is launched from different working directories, PNG files save to unexpected locations
- Workaround: None - users must manually locate generated PNGs
- Recommendation: Save to application home directory or ask user for destination via dialog

**Time Parsing Brittleness:**
- Symptoms: Schedule display fails silently if time fields contain unexpected formats
- Files: `scripts/schedule-builder.py` (lines 713-717), `scripts/matricula_app.py` (lines 509-513, 532-536)
- Trigger: When Excel data contains time values in non-standard formats (e.g., decimal hours, "HH:MM:SS", regional separators)
- Workaround: Invalid times are skipped without warning; schedule blocks don't render
- Recommendation: Validate time formats during data load. Log warnings for unparseable values.

## Security Considerations

**No Input Validation on File Paths:**
- Risk: File loading functions don't validate absolute paths; could potentially read files outside intended directories
- Files: `scripts/schedule-builder.py` (lines 278-281), `scripts/matricula_app.py` (line 139)
- Current mitigation: File dialogs restrict to Excel/CSV; OS-level directory permissions apply
- Recommendations: Explicitly validate that loaded files are in expected directories (e.g., `input/`, `output/`). Prevent path traversal with `os.path.abspath()` and boundary checks.

**No Data Sanitization in Gradio UI:**
- Risk: User-entered text (course names, search terms) is not sanitized before display in UI
- Files: `scripts/matricula_app.py` (UI rendering functions)
- Current mitigation: Gradio handles basic HTML escaping; no known injection vectors currently exploited
- Recommendations: If extending to REST API, add explicit input sanitization. Validate all external data before database operations.

**Environment Variable Exposure:**
- Risk: `GRADIO_SERVER_PORT` environment variable read without validation
- Files: `scripts/matricula_app.py` (line 1617)
- Current mitigation: Port defaults to 7860 if not set; binding to localhost only
- Recommendations: Validate port is in valid range (1024-65535). Document required environment setup.

## Performance Bottlenecks

**Excel/CSV Load Performance:**
- Problem: Large Excel files (1000+ rows) load slowly; no pagination or incremental loading
- Files: `scripts/matricula_app.py` (lines 139-200)
- Cause: `pd.read_excel()` loads entire file into memory; no streaming or chunking
- Improvement path: Implement CSV-only option (10x faster per convert_excel_to_csv.py docs). Add data caching. Consider lazy loading for filtered subsets.

**Schedule Visualization Regeneration:**
- Problem: Every UI tab switch triggers complete canvas redraw even if data unchanged
- Files: `scripts/schedule-builder.py` (lines 407-408, 665-697)
- Cause: `on_tab_changed()` calls `refresh_schedule()` unconditionally without change detection
- Improvement path: Cache rendered schedule images. Regenerate only when schedule data changes. Use dirty flag pattern.

**Search Filter Full Scan:**
- Problem: Course search filters entire DataFrame on every keystroke with no debounce
- Files: `scripts/schedule-builder.py` (lines 293-404), `scripts/matricula_app.py` (similar)
- Cause: No debouncing on search input; no index-based lookup
- Improvement path: Add 300ms debounce on search input. Pre-compute normalized course names at load time. Build keyword index.

**Conflict Detection O(n²) Algorithm:**
- Problem: Checking all course pairs for conflicts is O(n²); becomes slow with 50+ courses
- Files: `scripts/matricula_app.py` (lines 573-612 in `detect_conflicts`)
- Cause: Nested loop over all schedule entries without spatial indexing
- Improvement path: Group courses by day/time slot first. Use time interval trees or hash-based lookup. Current code acceptable for <100 courses.

## Fragile Areas

**CurriculumData JSON Loading:**
- Files: `scripts/matricula_app.py` (lines 45-84)
- Why fragile: Assumes specific JSON structure; no schema validation. Missing fields silently default to empty strings/lists
- Safe modification: Add explicit field validation in `load_from_json()`. Log warnings for missing fields. Use dataclass with defaults.
- Test coverage: No tests for malformed JSON; only success case documented in README.md

**DataFrame Column Name Assumptions:**
- Files: `scripts/schedule-builder.py` (lines 304-311), `scripts/matricula_app.py` (throughout)
- Why fragile: Hard-coded column names ("Curso", "Docentes", "Día", "Horario_Inicio", "Horario_Cierre") must match exactly
- Safe modification: Add column name mapping at load time. Validate columns exist before use. Raise clear errors for mismatches.
- Test coverage: Assumes Excel format matches one specific template; no tests for variants

**Type Conversions and Coercions:**
- Files: `scripts/matricula_app.py` (lines 22-28, `parse_credits`), both scripts throughout
- Why fragile: Broad try-except with silent fallback to 0.0; doesn't distinguish between missing data and corrupt data
- Safe modification: Return tuple (success, value) instead of just value. Log what failed. Validate before conversion.
- Test coverage: No unit tests for edge cases (NaN, negative values, strings with special characters)

**Block ID Parsing with String Split:**
- Files: `scripts/schedule-builder.py` (line 762: `split("__", 1)`)
- Why fragile: Course name and section IDs are joined with `__` separator; if course name contains `__`, parsing breaks
- Safe modification: Use structured data (namedtuple or dataclass) for block identifiers instead of string manipulation
- Test coverage: No tests for course names with special characters

## Scaling Limits

**In-Memory DataFrame Limit:**
- Current capacity: ~50,000 course offerings (typical Excel files 1,000-5,000 rows)
- Limit: At 10,000+ rows, Gradio UI becomes sluggish; search filters lag
- Scaling path: Switch to CSV format (10x faster). Implement server-side filtering. Add pagination UI.

**Canvas Drawing Memory:**
- Current capacity: ~200 visible schedule blocks before canvas rendering degrades
- Limit: 500+ blocks cause visible lag in PNG export
- Scaling path: Render schedule to static image backend (PIL directly) instead of Canvas. Implement viewport clipping.

**Hardcoded 3 Schedules Limit:**
- Current capacity: Support for exactly 3 simultaneous schedule plans
- Limit: If user needs >3 plans or wants to compare 4+ options, must reload app or save/load files manually
- Scaling path: Make schedule count configurable. Consider database-backed storage for multiple saved schedules.

## Dependencies at Risk

**Gradio Framework Dependency:**
- Risk: `matricula_app.py` tightly coupled to Gradio web framework; no abstraction layer for UI logic
- Impact: Migrating to desktop (Tkinter), mobile, or API would require complete rewrite
- Migration plan: Extract business logic (CurriculumData, MatriculaApp classes) to separate `core/` module. Create UI adapter interfaces. Current Gradio app becomes thin wrapper.

**Pandas Version Assumptions:**
- Risk: Code uses `pd.concat()` and other methods; no version pinning in requirements.txt
- Impact: Upgrading Pandas could break if API changes (e.g., deprecations removed)
- Migration plan: Add exact version pins to requirements.txt (e.g., `pandas>=1.3.0,<2.0.0`)

**openpyxl for Excel Parsing:**
- Risk: Excel parsing only tested with one openpyxl version; newer files or formats may break
- Impact: Users with Excel 365 or .xlsm files might experience failures
- Migration plan: Test with multiple Excel file types. Add fallback to alternative parsers (pyxlsx). Document supported formats.

## Missing Critical Features

**No Data Persistence:**
- Problem: All progress lost when app closes; no save/load functionality in current code despite README mentioning it
- Blocks: Users cannot interrupt work and resume later; cannot maintain multiple semester plans
- Fix: Implement JSON serialization for schedules, credits, and career state (similar to README examples)

**No Prerequisite Validation:**
- Problem: Users can add courses before completing prerequisites
- Blocks: Schedule suggestions are not validated against curriculum requirements
- Fix: Load prerequisite chains from JSON, check before adding to schedule, warn user

**No Conflict Warnings During Search:**
- Problem: Course search doesn't highlight which sections conflict with existing schedule
- Blocks: Users must manually check conflicts after selecting each course
- Fix: Pre-compute conflicts with current schedule; mark conflicting sections in search results

**No Dark Mode or Accessibility:**
- Problem: Fixed light theme; no keyboard navigation support
- Blocks: Users with visual impairments cannot use app; accessibility compliance unclear
- Fix: Add theme toggle. Implement ARIA labels. Test with screen readers.

## Test Coverage Gaps

**No Unit Tests for Core Logic:**
- What's not tested: `CurriculumData` JSON parsing, conflict detection algorithms, credit calculations
- Files: `scripts/matricula_app.py` (entire MatriculaApp class), `scripts/matricula_app.py` (all utility functions)
- Risk: Refactoring or fixing bugs can introduce regressions without detection
- Priority: High - these are business-critical logic paths

**No Integration Tests:**
- What's not tested: End-to-end workflows (load file → add course → detect conflict → export)
- Files: All scripts
- Risk: Issues appear only in production after user actions
- Priority: High - would catch UI integration bugs early

**No Edge Case Tests:**
- What's not tested: Empty DataFrames, missing columns, malformed times, >100 courses
- Files: All data loading and processing functions
- Risk: App crashes on non-standard inputs
- Priority: Medium - defensive coding would prevent

**No Visual Regression Tests:**
- What's not tested: Schedule canvas rendering with various course configurations
- Files: `scripts/schedule-builder.py` (draw_schedule_block method), `scripts/matricula_app.py` (visualization functions)
- Risk: Changes to drawing code silently break layout without notice
- Priority: Medium - would validate schedule appearance

---

*Concerns audit: 2026-02-24*
