---
phase: 01-extraction-pipeline-fix-validation
plan: 03
subsystem: extraction
tags: [curriculum, pdfplumber, json-output, economia2017]
dependency_graph:
  requires: [01-01]
  provides: [CurriculumExtractor, curricula_economia2017.json]
  affects: [phase-02-desktop-app]
tech_stack:
  added: [pdfplumber (PDF table extraction), scripts/extract.py CLI]
  patterns: [BaseExtractor ABC, Roman-numeral ciclo parsing, multi-code cell unpacking]
key_files:
  created:
    - scripts/extractors/curriculum.py
    - scripts/extractors/base.py
    - scripts/extractors/__init__.py
    - scripts/extract.py
    - scripts/__init__.py
    - input/curricula_economia2017.json
  modified:
    - tests/test_extraction.py
decisions:
  - "Output schema uses ciclos list with mixed types: int (0-10) for regular cycles, string ('concentracion', 'electivos') for special groups"
  - "Ciclo 0 pattern: each row has its own code in Codigo column; Ciclos 1-10 pattern: codes batched in ciclo-header row, subsequent rows have None"
  - "sys.path injection in extract.py enables python scripts/extract.py direct invocation without -m flag"
metrics:
  duration: "~30 minutes"
  completed: "2026-02-25"
  tasks_completed: 2
  files_created: 7
---

# Phase 1 Plan 3: Curriculum Extractor (Economia 2017) Summary

**One-liner:** CurriculumExtractor parses 1-page 3-table PDF into 60 courses across 11 ciclos (0-10) plus concentration and elective groups.

## What Was Built

Implemented `scripts/extractors/curriculum.py` with `CurriculumExtractor` that extracts the Economia 2017 academic plan from a 1-page pdfplumber PDF into structured JSON organized by academic cycle.

### Output: `input/curricula_economia2017.json`

```
13 groups total:
- Ciclos 0-10: 42 obligatory courses (3/4/4/5/5/5/5/5/3/2/1)
- concentracion: 8 concentration-required courses (3 tracks: Sector Publico, Empresarial, Teoria Economica)
- electivos: 10 elective courses
Total: 60 courses, 0 extraction warnings
```

### Key Files

- `scripts/extractors/curriculum.py` — CurriculumExtractor with 3 private parsing functions
- `scripts/extractors/base.py` — BaseExtractor ABC (save/error_rate shared logic)
- `scripts/extract.py` — CLI entry point (`python scripts/extract.py --type curriculum --pdf ...`)
- `input/curricula_economia2017.json` — Output JSON artifact

### Tests

- `tests/test_extraction.py::TestCurriculumStructure::test_curriculum_has_ciclos` — PASSED
- `tests/test_extraction.py::TestCurriculumStructure::test_curriculum_output_structure` — PASSED

## PDF Structure Discovered (Task 1 Inspection)

The curriculum PDF has:
- **1 page**, **3 tables**
- **Table 1** (44 rows): Obligatory courses. Ciclo column uses Roman numerals (`0`, `I`-`X`). Two code patterns:
  - Ciclo 0: each row has its own code in the Codigo column
  - Ciclos I-X: header row batches all cycle codes with `\n` separator; subsequent rows have None in Codigo
- **Table 2** (7 rows): Concentration required courses. Multi-code/multi-name cells with `\n` separators. Groups: Sector Publico, Sector Empresarial, Teoria Economica
- **Table 3** (11 rows): Elective courses. One course per row with direct code in Codigo column.

Course codes: 6 characters, start with digit, may contain one alpha (e.g., `1F0228`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Ciclo 0 code extraction returned empty string for courses 2 and 3**
- **Found during:** Task 2 - initial extraction run
- **Issue:** The extractor assumed all ciclos use the "batched codes in header row" pattern. Ciclo 0 has individual codes per row (code is in Codigo cell, not None).
- **Fix:** Added logic to check if the continuation row has a direct code in its Codigo cell; if so, use it directly instead of pulling from `pending_codes`.
- **Files modified:** `scripts/extractors/curriculum.py` (_extract_table1_ciclos function)
- **Commit:** 7d8a869

**2. [Rule 3 - Blocking] `python scripts/extract.py` fails with ModuleNotFoundError**
- **Found during:** Task 2 - first CLI invocation
- **Issue:** Running `python scripts/extract.py` doesn't add project root to sys.path, so `from scripts.extractors.curriculum import ...` fails.
- **Fix:** Added `sys.path.insert(0, project_root)` at the top of extract.py, with project root derived from `__file__`.
- **Files modified:** `scripts/extract.py`
- **Commit:** 7d8a869

## Success Criteria Verification

- [x] `scripts/extractors/curriculum.py` exists and implements CurriculumExtractor
- [x] `input/curricula_economia2017.json` exists with 11 numeric ciclos (0-10) and 60 total courses
- [x] `python scripts/extract.py --type curriculum --pdf ...` exits 0
- [x] `pytest tests/test_extraction.py::TestCurriculumStructure -x` exits 0 (2 passed)

## Self-Check: PASSED

Files verified present:
- `scripts/extractors/curriculum.py` — EXISTS
- `scripts/extract.py` — EXISTS
- `input/curricula_economia2017.json` — EXISTS

Commits verified:
- `73cac8c` — test(01-03): add TestCurriculumStructure
- `7d8a869` — feat(01-03): implement CurriculumExtractor and extract curricula_economia2017.json
