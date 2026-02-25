# Coding Conventions

**Analysis Date:** 2026-02-24

## Naming Patterns

**Files:**
- Snake case for all Python files: `matricula_app.py`, `schedule-builder.py`, `convert_excel_to_csv.py`
- Descriptive names indicating purpose: `schedule-builder.py`, `convert_excel_to_csv.py`

**Functions:**
- Snake case universally: `parse_credits()`, `normalize_str()`, `match_keywords()`, `load_from_json()`, `get_course_names()`, `get_mandatory_courses_status()`, `update_taken_courses()`, `detect_conflicts()`, `remove_from_schedule()`, `draw_week_schedule()`
- Verb-first pattern for action functions: `load_*()`, `get_*()`, `set_*()`, `add_*()`, `remove_*()`, `update_*()`, `detect_*()`, `draw_*()`, `save_*()`, `export_*()`, `validate_*()`, `clear_*()`, `filter_*()`, `list_*()`, `build_*()`
- Private functions use leading underscore: `_normalize_columns()`, `_invalidate_all_caches()`, `_invalidate_schedule_cache()`, `_try_read_csv()`, `_check_overlap_in_schedule()`, `_remove_conflicting_blocks()`, `_detect_conflicts_with_new()`, `_row_hash()`, `entry_slots()`

**Variables:**
- Snake case for all variables: `courses_df`, `current_career`, `schedule_index`, `search_term`, `filter_mandatory_only`, `taken_courses`, `cache_key`, `excel_size`, `csv_size`
- Constant names in UPPER_SNAKE_CASE: `WORKSPACE_ROOT`, `CAREER_CURRICULUM_MAP`, `CLASES_SET`, `EXAMENES_SET`
- Abbreviated names in specific contexts: `df` for DataFrames, `col` for columns, `idx` for index, `kw` for keyword arguments
- Descriptive plural forms for collections: `courses`, `cycles`, `schedules`, `credits`, `taken_courses`, `existing_blocks`, `conflicts_clases`, `conflicts_examenes`

**Classes:**
- PascalCase: `CurriculumData`, `MatriculaApp`, `ScheduleBuilder`
- Descriptive names indicating responsibility: `CurriculumData` manages curriculum, `MatriculaApp` handles application logic

**Type Hints:**
- Full type hints used throughout: `def parse_credits(value) -> float`, `def normalize_str(s: str) -> str`, `def load_from_json(self, json_path: str) -> bool`, `def get_mandatory_courses_status(self) -> Tuple[List[str], List[str], List[str]]`
- Optional types for nullable values: `Optional[pd.DataFrame]`, `Optional[str]`, `Optional[CurriculumData]`, `Optional[dict]`, `Optional[Image.Image]`
- Collection types explicit: `Dict[int, List[dict]]`, `Dict[int, float]`, `Set[str]`, `List[str]`, `List[dict]`, `Tuple[str, List[str], List[str]]`, `Dict[str, Tuple[Optional[Image.Image], Optional[Image.Image], str]]`

## Code Style

**Formatting:**
- Line continuations and multi-line logic formatted for readability in matricula_app.py
- Classes organized with `__init__` followed by public methods, private methods last
- Blank lines between method definitions
- Imports grouped: standard library first, then third-party (gradio, pandas, json, os, unicodedata, datetime, typing, io, matplotlib, PIL, tkinter)

**Linting:**
- No formal linter configuration found (no .pylintrc, .flake8, pyproject.toml linting config)
- Code follows PEP 8 conventions informally

**Line Length:**
- Lines average 80-120 characters
- Some UI setup lines in schedule-builder.py exceed 120 chars for readability (function parameters)

## Import Organization

**Order:**
1. Standard library: `os`, `sys`, `json`, `unicodedata`, `io`
2. Date/time: `from datetime import datetime, timedelta`
3. Type hints: `from typing import Dict, List, Set, Tuple, Optional`
4. Third-party frameworks: `import gradio as gr`, `import pandas as pd`, `import tkinter as tk`, `import matplotlib.pyplot as plt`, `import matplotlib.patches as patches`
5. UI/Image: `from PIL import Image, ImageGrab`, `from tkinter import ttk, filedialog, messagebox, PhotoImage`

**Path Aliases:**
- No path aliases used; all imports are direct
- Relative path management through `WORKSPACE_ROOT = os.path.dirname(os.path.dirname(__file__))` in each script

**Module Structure:**
- Constants at top: `WORKSPACE_ROOT`, `CAREER_CURRICULUM_MAP`
- Utility functions before classes: `parse_credits()`, `normalize_str()`, `match_keywords()`
- Classes follow: `CurriculumData`, then `MatriculaApp`
- Main entry point at end: `build_ui()`, `if __name__ == "__main__": main()`

## Error Handling

**Patterns:**
- Broad `try/except` blocks for robustness: `try: ... except: return 0.0` in `parse_credits()`
- Exception chaining in file operations: `try: ... except Exception as e: print(f"Error cargando {json_path}: {e}")`
- Fallback strategies for data loading: multiple CSV parsing engines attempted in `_try_read_csv()` with progressive fallbacks
- Early returns on error: `if not self.curriculum: return []`, `if cache_key in cache: return cached_value`
- Error messages propagated to UI: `return f"✗ Error al cargar: {e}"`, `return f"❌ Error: {e}"`
- Silent failures in utility functions (parse_credits returns 0.0 on any exception)

**Exception Types:**
- Generic `Exception` caught for most operations (not specific exceptions)
- No custom exception classes defined
- File-level try/except in `load_from_json()` and `load_excel()` for data loading

## Logging

**Framework:** Print statements and console output (no logging module used)

**Patterns:**
- Informational messages to console: `print(f"✓ Leídos {len(df)} registros")`
- Progress indicators with emoji: `print(f"📖 Leyendo Excel: {excel_path}")`, `print(f"💾 Guardando CSV: {csv_path}")`
- Error messages prefixed with emoji: `print(f"❌ Error: {e}")`, `print(f"✗ Error al cargar CSV: {e}")`
- Status messages returned as strings in API methods: `return f"✓ Datos cargados ({file_type}): {len(df)} registros"`
- UI notifications via tkinter messagebox: `messagebox.showinfo()`, `messagebox.showerror()`, `messagebox.showwarning()`, `messagebox.askyesno()`
- Gradio alerts for web UI: `gr.Info()`, `gr.Error()` (in matricula_app.py)

## Comments

**When to Comment:**
- Spanish language comments throughout for Spanish-speaking audience
- Comments explain WHY not WHAT: `# Cache para imágenes de horarios (evita regenerar si no hay cambios)`, `# Conjuntos normalizados (sin acentos/espacios, en mayúsculas) para comparaciones robustas`
- Complex algorithm explanations: `# Determina el grupo del bloque nuevo`, `# Solo comparar si son del mismo grupo`
- Multi-step logic documented: `# Normalizar nombres de columnas`, `# Asegurar que existan las columnas esperadas`

**Docstrings/TSDoc:**
- Single-line docstrings for functions: `"""Convierte un valor a float, manejando formatos variados."""`
- Docstrings for all public methods: functions and class methods
- Class-level docstrings: `"""Gestiona los datos de currículo de una carrera."""`, `"""Lógica principal de la aplicación de matrícula."""`
- Docstring format: triple quotes followed by description
- Multi-line docstrings include Args and Returns sections:
  ```python
  """
  Carga archivo Excel o CSV con datos de horarios.
  CSV es ~10x más rápido que Excel para archivos grandes.
  """
  ```

## Function Design

**Size:**
- Functions typically 10-50 lines
- Complex functions like `add_to_schedule()` and `draw_week_schedule()` exceed 100 lines
- Longest function: `draw_week_schedule()` at ~250 lines (visualization logic)

**Parameters:**
- Kept minimal; typically 1-3 parameters
- Methods use `self` for state; functions use parameters
- Optional parameters with defaults: `def list_courses(self, search_term: str = "", filter_mandatory_only: bool = False, filter_pending_only: bool = False) -> List[str]`
- Tuple unpacking for related returns: `all_mandatory, taken, pending = get_mandatory_courses_status()`

**Return Values:**
- Explicit return types in all function signatures
- Multiple return values via tuples: `Tuple[str, List[str], List[str]]`, `Tuple[Image.Image, Image.Image]`
- None for operations with side effects: cache invalidation methods
- String returns for status/error messages: `return f"✓ ..."`
- Empty collections for "no data" scenarios: `return []`, `return pd.DataFrame()`

## Module Design

**Exports:**
- No `__all__` declarations found
- Classes and utility functions are implicitly public (no naming convention barrier)
- Entry point: `if __name__ == "__main__": main()` in each script

**Barrel Files:**
- No barrel files (no `__init__.py` with re-exports)
- Each script is standalone with utility functions and classes defined locally

**Reuse Pattern:**
- Utility functions duplicated across files: `parse_credits()`, `normalize_str()`, `match_keywords()` appear in both `matricula_app.py` and `schedule-builder.py`
- No shared utility module; duplication preferred over cross-file imports

## Caching and State Management

**Cache Implementation:**
- Dictionary-based caches: `self._course_search_cache: Dict[str, List[str]]`, `self._schedule_image_cache: Dict[int, Tuple[Optional[Image.Image], Optional[Image.Image], str]]`
- Cache key generation: `cache_key = f"{search_term}|{filter_mandatory_only}|{filter_pending_only}|{len(self.taken_courses)}"`
- Cache invalidation methods: `_invalidate_all_caches()`, `_invalidate_schedule_cache()`
- Cache checking pattern: `if cache_key in self._course_search_cache: return self._course_search_cache[cache_key]`

## Data Processing Patterns

**DataFrame Operations:**
- Normalization applied early: `self._normalize_columns(df)`
- Filtering via pandas operations: `df.groupby()`, `df.apply()`, `df[mask]`
- Unique value extraction: `df['Curso'].dropna().unique().tolist()`
- DataFrame concatenation for accumulation: `pd.concat([existing_df, pd.DataFrame([row_dict])], ignore_index=True)`

**String Normalization:**
- Consistent pattern: `unicodedata.normalize('NFD', str(s).lower())` to remove accents
- Applied to course names, search terms, column headers
- Normalized versions cached separately from display versions

---

*Convention analysis: 2026-02-24*
