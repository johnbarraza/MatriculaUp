# Architecture

**Analysis Date:** 2026-02-24

## Pattern Overview

**Overall:** Model-View pattern with a monolithic single-file application architecture.

**Key Characteristics:**
- Single main application file (`matricula_app.py`) containing business logic and UI definition
- Clear separation between data model (`CurriculumData`, `MatriculaApp`) and Gradio UI layer
- Three independent parallel schedules (1, 2, 3) for schedule comparison
- Extensive caching layer for performance optimization (schedule images, course searches, sections)
- Stateful application with session persistence via JSON

## Layers

**Data Model Layer:**
- Purpose: Manages core business logic and schedule operations
- Location: `scripts/matricula_app.py` (classes `CurriculumData`, `MatriculaApp`)
- Contains: Curriculum loading, course filtering, schedule management, conflict detection, progress persistence
- Depends on: Pandas, Pillow, Matplotlib, standard libraries
- Used by: Gradio UI layer via global instance `app_logic`

**Presentation Layer:**
- Purpose: Gradio-based web UI providing user interactions
- Location: `scripts/matricula_app.py` (function `build_ui()`)
- Contains: UI components (dropdowns, text boxes, tables, images), event callbacks, layout configuration
- Depends on: Gradio framework, MatriculaApp instance
- Used by: Gradio server

**Data Input Layer:**
- Purpose: Loads and normalizes external data sources
- Location: `scripts/matricula_app.py` (methods `load_excel()`, `_normalize_columns()`)
- Contains: Excel/CSV parsing, column mapping, data validation
- Depends on: Pandas with multiple engine fallbacks
- Used by: MatriculaApp state management

**Visualization Layer:**
- Purpose: Generates calendar visualizations
- Location: `scripts/matricula_app.py` (method `draw_week_schedule()`)
- Contains: Matplotlib-based schedule drawing, conflict highlighting, PNG export
- Depends on: Matplotlib, PIL, caching system
- Used by: Gradio UI for weekly schedule display

## Data Flow

**Career Selection Flow:**
1. User selects career from dropdown
2. `handle_load_career()` callback invokes `app_logic.set_career()`
3. `CurriculumData` loads JSON file from `input/` (e.g., `input/economia2017.json`)
4. Curriculum cycles and mandatory courses populate UI dropdowns/checkboxes
5. `mandatory_stats` displays course status (carried / pending)

**Schedule Building Flow:**
1. User uploads Excel/CSV via file uploader
2. `handle_load_data()` calls `app_logic.load_excel(file_obj)`
3. Pandas reads file with fallback engine handling (C → Python with separators)
4. `_normalize_columns()` maps varied column names to standard schema: `['Curso', 'Secc', 'Docentes', 'Cred', 'Día', 'Horario_Inicio', 'Horario_Cierre', 'Tipo']`
5. Course list populated; user can search, filter, select sections
6. Sections parsed via `get_sections_for_course()` grouping by section ID, professor, credits
7. User selects section(s) and target schedule (1, 2, or 3)
8. `add_to_schedule()` validates: conflicts detected, credit limit (25 max), duplicates prevented
9. If conflicts, user can force-replace conflicting blocks or cancel
10. Schedule state updated, credits recalculated, cache invalidated
11. Weekly visualization regenerated via `draw_week_schedule()`

**Conflict Detection Flow:**
1. `_detect_conflicts_with_new()` compares new course slots with existing schedule
2. Extracts day, start time, end time, session type (CLASE/PARCIAL/FINAL)
3. Groups types: CLASE/PRÁCTICA/PRACDIRIGI vs FINAL/PARCIAL
4. Only compares same type group, same day, overlapping times
5. Returns conflict pairs displayed to user
6. If force_replace=True, conflicting blocks removed and credits adjusted

**Visualization Generation Flow:**
1. `draw_week_schedule(schedule_index)` called
2. Generates hash of current schedule to validate cache
3. If cache hit and hash matches, returns cached images (classes + exams)
4. If cache miss, calls `make_fig('CLASE')` and `make_fig('EXAM')`
5. Creates matplotlib figure: 6 day columns × (16.5 hour blocks × 30-min intervals)
6. Time range: 7:30 AM - 11:00 PM (23:00)
7. Draws rectangles for each slot; colors: blue (classes OK), red (conflicts), yellow (exams)
8. Generates PNG via BytesIO, caches with hash
9. Returns (PIL Image for classes, PIL Image for exams)

**State Management:**
- `app_logic` is a global singleton instance of `MatriculaApp`
- State persisted via `save_progress()`: JSON with schedules dict, credits dict, taken courses set, career name
- Loaded via `load_progress()` to restore previous session
- Three independent schedule dicts keyed 1-3
- Taken courses tracked as normalized strings set

## Key Abstractions

**CurriculumData:**
- Purpose: Represents a career's curriculum structure
- Examples: Loaded from `input/economia2017.json`, `input/finanzas2018.json`
- Pattern: Simple data container with JSON deserialization; methods for filtering by cycle

**MatriculaApp:**
- Purpose: Central orchestrator for all schedule operations
- Core state: `courses_df` (pandas DataFrame of available courses), `schedules` (3 parallel schedule lists), `credits` (per-schedule credit sums), `taken_courses` (normalized course name set), `current_career` (selected career)
- Caches: `_schedule_image_cache`, `_course_search_cache`, `_sections_cache`
- Key pattern: Dictionary-keyed by schedule index (1, 2, 3) for multi-schedule support

**Schedule Block:**
- Purpose: Represents a course section in a schedule
- Structure: Dict with keys: `block` (course__section ID), `curso`, `secc`, `prof`, `tipo`, `slots` (list of day/time slots), `cred`
- Pattern: New format with `slots` list supports multi-day sections; legacy single-slot fallback supported

## Entry Points

**Main Application:**
- Location: `scripts/matricula_app.py` (lines 1615-1618)
- Triggers: `python scripts/matricula_app.py`
- Responsibilities: Creates Gradio app via `build_ui()`, launches server on port 7860

**Build UI Function:**
- Location: `scripts/matricula_app.py` line 1039
- Triggers: Called once at startup
- Responsibilities: Constructs Gradio Blocks layout, registers all callbacks, returns demo object

**Utility Script:**
- Location: `scripts/convert_excel_to_csv.py`
- Triggers: `python scripts/convert_excel_to_csv.py [input] [output]`
- Responsibilities: One-time Excel-to-CSV conversion for 10x performance improvement

## Error Handling

**Strategy:** Try-except blocks with user-facing error messages prefixed with emoji (✗, ⚠, ✓).

**Patterns:**
- **File Loading:** Catches file not found, permission errors; returns descriptive message
- **Data Parsing:** CSV parsing attempts multiple engines (C fast, Python with separators); falls back gracefully
- **Time Parsing:** Attempts datetime.strptime with %H:%M format; silently skips malformed entries
- **Excel Export:** Catches pandas/openpyxl errors; returns exception message
- **JSON Persistence:** Catches file I/O and JSON errors; returns error status

## Cross-Cutting Concerns

**Logging:** None - application uses print() for debugging only. User feedback via status text fields in UI.

**Validation:**
- Credit limit: 25.0 max per schedule (enforced in `add_to_schedule()`)
- Duplicate prevention: Block IDs checked before insertion
- Column mapping: Expected 8 columns auto-created if missing
- Normalization: All course names normalized (unicode decomposition, lowercase, no accents) for consistent matching

**Authentication:** None - single-user local application.

**Caching Strategy:**
- Schedule images cached per schedule index with SHA-like hash of schedule contents
- Course search cached by (search_term, filter_mandatory, filter_pending, taken_courses_count) tuple
- Sections cached by course name
- All caches invalidated on `load_excel()` or `_invalidate_all_caches()` calls
- Schedule image cache invalidated on `add_to_schedule()`, `remove_from_schedule()`, conflict replacement

---

*Architecture analysis: 2026-02-24*
