# Codebase Structure

**Analysis Date:** 2026-02-24

## Directory Layout

```
MatriculaUp/
├── .git/                           # Git version control
├── .planning/                      # Planning and analysis documents
├── output/                          # Input data files (generated from the pdfs)
│   ├── horarios_cursos_matricula/  # Convenience collection of schedule data
│   ├── economia2017.json           # Curriculum: Economics 2017 plan
│   └── finanzas2018.json           # Curriculum: Finance 2018 plan
├── pdfs/                           # Reference PDF documents (not code)
│   ├── matricula/                  # Enrollment documents by term
│   ├── plan_estudios/              # Study plans by career and year
│   └── concentraciones/            # Specialization documents
├── scripts/                        # Python application code
│   ├── matricula_app.py            # Main application (1618 lines)
│   ├── convert_excel_to_csv.py     # Data conversion utility
│   ├── schedule-builder.py         # Archived schedule builder
│   └── pdf_to_csv.ipynb            # Data extraction notebook
├── mcp-server-demo/                # MCP server (separate subsystem)
│   ├── main.py                     # MCP entry point
│   ├── pyproject.toml              # Python project config
│   ├── .python-version             # Python version specification
│   └── .venv/                      # Virtual environment
├── .gitattributes                  # Git attributes
├── LICENSE                         # Apache 2.0 license
├── README.md                       # Project documentation
└── requirements.txt                # Python dependencies
```

## Directory Purposes

**input/**

- Purpose: Stores curriculum definitions and schedule data
- Contains: JSON files with course structures, cycle mappings
- Key files: `economia2017.json`, `finanzas2018.json`
- Committed: Yes
- Generated: No

**pdfs/**

- Purpose: Reference documentation (not processed by application)
- Contains: PDF curriculum documents, enrollment information
- Not used by main application code
- Committed: Yes
- Generated: No (manually organized references)

**scripts/**

- Purpose: All runnable Python code for the main application
- Contains: Main app, utilities, experimental notebooks
- Key files: `matricula_app.py` (primary), `convert_excel_to_csv.py` (helper)
- Committed: Yes
- Generated: No

**mcp-server-demo/**

- Purpose: MCP (Model Context Protocol) server for AI integration
- Contains: Separate FastAPI-based service
- Isolated: Yes - has its own pyproject.toml and .venv
- Note: Not part of main application; separate subsystem

**.planning/**

- Purpose: Generated analysis and planning documents
- Contains: Architecture, structure, conventions documentation
- Committed: Yes (tracks planning process)
- Generated: Yes (by GSD mapping tools)

## Key File Locations

**Entry Points:**

- `scripts/matricula_app.py` (line 1615): Main application entry point - launches Gradio server
- `scripts/convert_excel_to_csv.py` (line 109): Utility entry point - converts Excel files to CSV
- `mcp-server-demo/main.py`: MCP server entry point (separate system)

**Configuration:**

- `requirements.txt`: Python dependencies (gradio, pandas, openpyxl, matplotlib, pillow)
- `README.md`: Project documentation and usage guide

**Curriculum Data:**

- `input/economia2017.json`: Economics career curriculum structure
- `input/finanzas2018.json`: Finance career curriculum structure
- Format: JSON with `title`, `faculty`, `cycles` array, `courses` array

**Core Logic:**

- `scripts/matricula_app.py` lines 45-83: `CurriculumData` class (curriculum loader)
- `scripts/matricula_app.py` lines 86-1033: `MatriculaApp` class (main business logic)
- `scripts/matricula_app.py` line 1036: Global `app_logic` instance
- `scripts/matricula_app.py` lines 1039-1612: `build_ui()` function (Gradio interface)

**UI Components:**

- `scripts/matricula_app.py` lines 1050-1152: Left panel (controls): Career, data load, course marking, search, schedule addition
- `scripts/matricula_app.py` lines 1154-1206: Right panel (display): Tabs for 3 schedules, credit display, weekly view

**Callbacks:**

- `scripts/matricula_app.py` lines 1209-1610: Event handlers for all UI interactions
- Organized by function: career loading, cycle marking, data loading, course search, schedule operations, progress management

## Naming Conventions

**Files:**

- Snake case: `matricula_app.py`, `convert_excel_to_csv.py`
- Descriptive purpose-based names
- JSON data files: `{career}{year}.json` (e.g., `economia2017.json`)

**Directories:**

- Snake case: `mcp-server-demo` (kebab case in this case), `plan_estudios`, `horarios_cursos_matricula`
- Semantic grouping by domain: `input/`, `scripts/`, `pdfs/`

**Functions:**

- Snake case: `get_sections_for_course()`, `add_to_schedule()`, `draw_week_schedule()`
- Prefixed with underscore for internal: `_normalize_columns()`, `_detect_conflicts_with_new()`, `_invalidate_schedule_cache()`
- Callback functions in Gradio: `handle_load_career()`, `update_taken_courses()`, `search_change()`

**Variables:**

- Snake case throughout: `schedule_index`, `course_dropdown`, `taken_courses`
- Prefixed with underscore for private: `_CLASES_NORM`, `_schedule_image_cache`, `_course_search_cache`
- ALL_CAPS for constants: `CAREER_CURRICULUM_MAP`, `CLASES_SET`, `EXAMENES_SET`, `WORKSPACE_ROOT`

**Types:**

- CamelCase for classes: `CurriculumData`, `MatriculaApp`
- Type hints used throughout: `Dict[int, List[dict]]`, `Optional[str]`, `Tuple[str, List[str], List[str]]`

## Where to Add New Code

**New Feature (e.g., prerequisite checking):**

- Primary code: Add method to `MatriculaApp` class in `scripts/matricula_app.py` (after existing schedule methods, ~line 1033)
- UI integration: Add callback function after line 1209, register with `btn_*.click()` in build_ui()
- Example: `def check_prerequisites(course_name: str) -> List[str]` method on MatriculaApp

**New Career Support:**

1. Add curriculum JSON file to `input/` directory: `input/{carrera}{year}.json`
2. Update `CAREER_CURRICULUM_MAP` in `scripts/matricula_app.py` line 16: `"Carrera Name": "{carrera}{year}.json"`
3. No other code changes required (extensible design)

**New Utility Script:**

- Location: `scripts/{purpose}.py`
- Pattern: Follow `convert_excel_to_csv.py` structure with main() entry point
- Imports: Use same workspace root calculation pattern: `WORKSPACE_ROOT = os.path.dirname(os.path.dirname(__file__))`

**Testing Code (not currently present):**

- Would place in `scripts/tests/` or `tests/` directory
- Follow pytest convention: `test_*.py` or `*_test.py`
- Import app logic via: `from scripts.matricula_app import MatriculaApp, CurriculumData`

## Special Directories

**input/**

- Purpose: Runtime data - curriculum definitions and schedule files
- Generated: No (manually maintained)
- Committed: Yes
- Must contain before running: `economia2017.json` and/or `finanzas2018.json`
- Optional: CSV/XLSX schedule files (can be uploaded via UI)

**output/** (implied, created at runtime)

- Purpose: Generated Excel exports, schedule PNG images, progress JSON file
- Generated: Yes (by application at runtime)
- Committed: No (in .gitignore)
- Files: `schedule_1.xlsx`, `schedule_2.xlsx`, `schedule_3.xlsx`, `horario_1_clase.png`, `matricula_progress.json`

**.venv/ (in mcp-server-demo only)**

- Purpose: Isolated Python environment for MCP server
- Generated: Yes (by `uv` or `pip`)
- Committed: No (in .gitignore)

**.git/**

- Purpose: Version control metadata
- Committed: Yes
- No code files here

## External File Dependencies

**At Runtime:**

- `input/economia2017.json` - Required if user selects Economía career
- `input/finanzas2018.json` - Required if user selects Finanzas career
- User-uploaded Excel/CSV - Required for schedule data
- `matricula_progress.json` - Optional, created by "Save Progress" button

**Data Format - Curriculum JSON:**

```json
{
  "title": "FLUJOGRAMA DE LA CARRERA...",
  "faculty": "FACULTAD DE ECONOMÍA Y FINANZAS",
  "cycles": ["CICLO CERO", "PRIMER CICLO", "SEGUNDO CICLO", ...],
  "courses": [
    {
      "name": "Economía General I",
      "code": "ECO101",
      "credits": "5",
      "cycle_recommended": "PRIMER CICLO"
    }
  ]
}
```

**Data Format - Schedule CSV/XLSX:**
Required columns (auto-mapped): Curso, Secc, Docentes, Cred, Día, Horario_Inicio, Horario_Cierre, Tipo

- Curso: Course name (e.g., "Economía General I")
- Secc: Section number
- Docentes: Instructor name(s)
- Cred: Credit hours
- Día: Day of week (e.g., "LUNES", "MARTES")
- Horario_Inicio: Start time (HH:MM format, e.g., "08:00")
- Horario_Cierre: End time (HH:MM format, e.g., "10:00")
- Tipo: Session type (CLASE, PRÁCTICA, PRACDIRIGI, FINAL, PARCIAL)

---

*Structure analysis: 2026-02-24*
