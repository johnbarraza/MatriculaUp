# Technology Stack

**Analysis Date:** 2026-02-24

## Languages

**Primary:**
- Python 3.10+ - Core application language
- Python 3.12 - MCP server environment

**Secondary:**
- None detected

## Runtime

**Environment:**
- Python 3.10 (recommended for main application via conda)
- Python 3.12 (required for MCP server)

**Package Manager:**
- pip - Package installation for main application
- uv - Package manager for MCP server (lockfile: uv.lock)
- Lockfile: `requirements.txt` (main), `uv.lock` (MCP server)

## Frameworks

**Core:**
- Gradio 3.0+ - Web UI framework for MatriculaApp (`scripts/matricula_app.py`)
- tkinter - Desktop GUI framework for schedule builder (`scripts/schedule-builder.py`)

**Testing:**
- Not detected

**Build/Dev:**
- conda - Environment management (recommended setup: `conda create -n up python=3.10`)

## Key Dependencies

**Critical:**
- pandas - DataFrame operations for course and schedule data processing
- openpyxl - Excel file reading/writing for schedule import and export
- Pillow (PIL) - Image processing for schedule visualization export to PNG
- matplotlib - Chart rendering and schedule visualization with custom graphics

**Data Processing:**
- unicodedata - Unicode normalization for course name matching and accent removal
- json - Built-in for curriculum data loading from JSON files
- datetime - Schedule time calculations and conflict detection
- io - In-memory file operations

**Infrastructure:**
- mcp[cli] 1.26.0+ - Model Context Protocol server framework (MCP server only)

## Configuration

**Environment:**
- conda virtual environment for main application
- Python environment variables for file paths (WORKSPACE_ROOT set at runtime)
- No .env file required

**Build:**
- pyproject.toml - MCP server project configuration
- requirements.txt - Main application dependencies list

## Platform Requirements

**Development:**
- Windows/macOS/Linux compatible
- Python 3.10+ with conda or venv
- Display/GUI capability required (Gradio web or tkinter desktop)

**Production:**
- Standalone Python application
- Local filesystem for storing curriculum JSON and schedule data
- No external server/database required

## Data Storage

**Local:**
- JSON files in `input/` - Curriculum data (economia2017.json, finanzas2018.json)
- Excel/CSV files in `input/horarios_cursos_matricula/` - Course schedule data
- Serialized progress JSON - User schedule state and completed courses
- Generated exports: Excel files (schedules), PNG files (visualizations)

---

*Stack analysis: 2026-02-24*
