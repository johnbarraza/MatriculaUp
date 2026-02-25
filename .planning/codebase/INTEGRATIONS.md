# External Integrations

**Analysis Date:** 2026-02-24

## APIs & External Services

**Not detected** - No external API integrations found in the codebase. Application operates entirely offline.

## Data Storage

**Databases:**
- None - Application uses local file system only

**File Storage:**
- Local filesystem only
  - Input: `input/` directory contains curriculum JSON files and schedule Excel/CSV files
  - Output: Generated exports stored locally (schedules.xlsx, visualizations.png)

**Caching:**
- None - Data loaded fresh from files each session

## Authentication & Identity

**Auth Provider:**
- None - No authentication system implemented

**User State:**
- Manual progress save/load via JSON serialization
- Stored locally in user's filesystem
- Format: `{"schedules": {...}, "credits": {...}, "taken": [...], "current_career": "..."}`

## Monitoring & Observability

**Error Tracking:**
- None - No external error tracking service

**Logs:**
- Console output via print statements
- No persistent logging configured

## CI/CD & Deployment

**Hosting:**
- Standalone local application (not deployed to external server)
- Gradio UI runs on `http://127.0.0.1:7860` locally
- tkinter GUI runs locally on desktop

**CI Pipeline:**
- None detected

## Environment Configuration

**Required env vars:**
- None required

**Application Configuration:**
- Hard-coded career mapping in `scripts/matricula_app.py`:
  ```python
  CAREER_CURRICULUM_MAP = {
      "Economía": "economia2017.json",
      "Finanzas": "finanzas2018.json",
  }
  ```
- File paths resolved relative to `WORKSPACE_ROOT` (script directory parent)

**Secrets location:**
- No secrets configured

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

## Data Sources

**Curriculum Data:**
- `input/economia2017.json` - Economics program structure (Plan 2017/2022)
- `input/finanzas2018.json` - Finance program structure (Plan 2018/2021)
- Format: JSON with title, faculty, cycles array, courses array (name, code, credits, cycle_recommended)

**Course Schedule Data:**
- `input/horarios_cursos_matricula/horarios_regular_up_2025_V6.xlsx` - Available courses and sections
- Format: Excel spreadsheet with course information, sections, schedules, instructors
- Also available as CSV for faster loading (10x performance improvement)

## File Dependencies

**Curriculum Loading:**
- Location: `scripts/matricula_app.py` - `CurriculumData.load_from_json()`
- Input: JSON files with encoding='utf-8'
- Error handling: Prints error to console if file not found

**Schedule Parsing:**
- Location: `scripts/matricula_app.py` - `MatriculaApp.load_courses_from_file()`
- Input: Excel/CSV files via pandas
- Parsing: Uses openpyxl engine for Excel, pandas default for CSV

**Export Operations:**
- Excel export: Uses openpyxl to write schedule data
- PNG export: matplotlib rendering to image file with PIL
- Locations: Generated in working directory or specified output path

---

*Integration audit: 2026-02-24*
