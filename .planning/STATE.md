# MatriculaUp Project State

**Last updated:** 2026-02-24
**Current phase:** Phase 1 (planning complete, execution pending)

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

**Active Phase:** Phase 1 — Extraction Pipeline Fix & Validation

**Current Focus:**
- Fix pdfplumber extraction bugs (multi-line truncation, Spanish names, missing rows)
- Generate validated courses.json, curricula.json for 2026-1
- Build extraction test suite

**Progress:**
- Roadmap: Complete ✓
- Phase 1 Plan: TBD (next: `/gsd:plan-phase 1`)
- Phase 1 Execution: Not started

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

---

## Critical Path & Blockers

### Phase 1 (Extraction) Blockers

**High Priority:**
- Multi-line prerequisite truncation in pdfplumber (research shows incomplete expressions ending with "Y (" — must fix before JSON output)
- Spanish compound surname parsing ("Del Rosario", "de la", etc. truncated by naive regex)
- Missing table boundaries (first/last rows dropped if lines faint)

**Validation Required:**
- Prerequisite row count validation (ensure all prerequisites captured)
- Professor name list cross-check (validate parsed names against known faculty)
- Encoding checks (UTF-8 Spanish characters not mangled)

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

5. **Update strategy for future cycles:** v1 ships with 2026-1 data. When 2026-2 comes, do we release new .exe or add JSON update mechanism? (v1.1: Add JSON update from GitHub releases; v2+: Full multi-cycle support.)

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

**Next Steps:**
- `/gsd:plan-phase 1` — Decompose Phase 1 extraction tasks into executable plans
- Execute Phase 1 plans (fix extraction bugs, validate JSON)
- Generate courses.json, curricula.json for 2026-1 Economía

---

*State file created: 2026-02-24*
*Ready for Phase 1 planning*
