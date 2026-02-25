# Project Research Summary

**Project:** MatriculaUp — University course schedule planner
**Domain:** Python desktop app (PDF extraction + schedule planning UI)
**Researched:** 2026-02-24
**Confidence:** HIGH

## Executive Summary

MatriculaUp is a desktop course planning tool for Peruvian university students, built on a three-layer architecture: an offline Python PDF extraction pipeline (CLI-based), pre-extracted JSON data bundled with the app, and a Windows desktop UI using PySide6. The recommended stack is **PySide6 + PyInstaller + pyside6-deploy** for the UI layer, which keeps users in the Python ecosystem, avoids GPL licensing friction (PySide6 is LGPL), and produces manageable bundles (80-150 MB). Core risks center on PDF extraction brittleness (multi-line cell truncation, Spanish name parsing, missing table boundaries) and PyInstaller deployment gotchas (hidden imports, file path hardcoding, performance). All six critical extraction pitfalls must be addressed in Phase 1 before building the UI, since the app consumes pre-extracted JSON that becomes the single source of truth.

The feature set is narrowly scoped for v1: course search, conflict detection, visual timetable, save/load 3 schedules, curriculum filter (basic), and PNG export. This MVP validates the core value proposition (offline planning without PDFs) without premature multi-semester planning or optimization algorithms. Prerequisite validation defers to v1.x, multi-semester to v2+. This phasing ensures rapid launch to a validated user base (Economía 2017 students at UP).

## Key Findings

### Recommended Stack

**PySide6 + PyInstaller + pyside6-deploy** is the clear choice for this Windows desktop app. PySide6 (LGPL) beats PyQt6 (requires expensive commercial license) for proprietary distribution. PyInstaller is the industry standard for Python executables and handles pdfplumber/pandas binary dependencies automatically. The `pyside6-deploy` tool optimizes bundle size by excluding unused Qt modules (QtWebEngine, etc.), reducing size from ~400 MB to ~80-150 MB. This keeps the team in Python, avoids Rust/Node.js complexity, and produces single-file installers users expect. Alternative stacks (Tauri, Electron, CustomTkinter) either add unnecessary complexity for marginal gains or lack professional widgets needed for course list/schedule grid UI.

**Core technologies:**
- **PySide6 6.7+**: Desktop UI framework; LGPL licensed; Qt models/views perfect for tabular schedule data
- **PyInstaller 6.x**: Bundles Python + dependencies into standalone .exe; industry standard, zero learning curve
- **pyside6-deploy**: Optimizes bundle size automatically by detecting and excluding unused Qt modules
- **Python 3.11+**: Reuses existing pdfplumber extraction code directly; no API changes needed
- **pdfplumber 0.10+**: Already working in extraction layer; extracted data becomes pre-computed JSON
- **pandas 2.0+**: Tabular data processing for normalized schedules and prerequisites
- **PyYAML**: Configuration for pyside6-deploy spec

**Bundle size estimates:** PySide6 + PyInstaller yields 80-150 MB raw, 40-80 MB installer (acceptable for desktop utility). Development checklist must include: relative path handling (pathlib), pre-extracted JSON bundled in data/, `sys.frozen` detection for bundled vs. dev contexts, hidden imports for pandas._libs, Windows .ico inclusion, UAC elevation disabled.

### Expected Features

**Must have (v1 table stakes):**
- **Course Search & Filter** — Users must find courses by name/code/instructor without manual PDF scrolling
- **Section Selection** — Each course has multiple sections (times, instructors); users pick one section per course
- **Visual Timetable** — Week view (Mon-Fri, 7:30-23:30) with color-coded courses; shows at-a-glance schedule shape
- **Conflict Detection** — Real-time detection when adding sections; highlights overlapping times in red; shows exact overlap details
- **Save/Load 3 Schedules** — Users compare options; persist tentative plans to disk between sessions
- **Schedule Export** — PNG export of timetable with course names, times, instructors; share via email/Telegram
- **Curriculum Filter (Basic)** — User selects career + year; app shows which courses are required, marks completed

**Should have (v1.x competitive differentiators):**
- **Prerequisite Validation** — Warn before selecting course with unmet prerequisites; block conflicting selections
- **Multi-Semester Planning** — Plan across semesters; validate prerequisite chains across time
- **Schedule Optimization Hints** — Suggest valid schedule alternatives ranked by user preference (compact vs. spread)
- **Shared Schedule Comparison** — Import peer's schedule; overlay two timetables side-by-side

**Defer (v2+):**
- Mobile app (desktop superior for tinkering)
- Real-time registration integration (separate from planning)
- Dark mode / theming (nice to have, not core)
- Sync to Google Calendar (iCal export in v1.x)

**MVP rationale:** MatriculaUp solves "plan schedules without PDFs" for one term at one university. All P1 features are table stakes (students already use Excel; MatriculaUp must do what spreadsheets do with less friction). Prerequisite validation and multi-semester defer until user feedback validates demand. Anti-features like automatic schedule recommendation, dark mode, and mobile avoid premature complexity.

### Architecture Approach

MatriculaUp uses **extract-once, distribute-many** architecture: PDF extraction runs offline once per semester via Python CLI, producing versioned JSON files that are committed to the repository and bundled into the final .exe. The app never touches PDFs; it reads pre-extracted, validated JSON at startup. This separates concerns (extraction testing independent of UI) and eliminates Python/pdfplumber dependencies from the distributed executable. The Data Layer (in-memory JSON store) is the single source of truth. UI Layer (PySide6) is read-only consumer. Extraction Layer (Python CLI) is independent build step.

**Major components:**
1. **Extraction Layer (Python CLI)** — Parses PDFs with pdfplumber; validates course structure; outputs versioned JSON with AND/OR prerequisite logic trees; not shipped with app; runs as build step once per term
2. **Data Layer (Bundled JSON)** — Pre-extracted courses.json, prerequisites.json, curricula.json; embedded in .exe; loaded into memory at startup; source of truth for all queries
3. **UI Layer (PySide6)** — Course search/filter, section selector, conflict detector, schedule builder, curriculum tracker; reads from in-memory data store; renders week-view timetable

**JSON schema design:**
- **Courses:** Flat array with nested sections → sessions (day, time, room, instructor, type). Session types normalized (CLASE, PRACTICA, etc.). Time stored as HH:MM 24-hour format. Building + room for future optimization.
- **Prerequisites:** Recursive AND/OR logic trees enable human-readable chains ("Microeconomía I AND (Accounting I OR Accounting II)"). Type discriminators (AND/OR/course) enable tree-walking evaluator.
- **Curricula:** Flat semesters array with courseId references. Type field (required/elective) for filtering. Links back to courses table.

**Build order:** Schema first (defines contract), then extraction fix, then UI, then distribution. This prevents coupling and enables parallel work.

### Critical Pitfalls

1. **Multi-line cell text truncation in pdfplumber** — Prerequisite fields spanning multiple rows are cut off mid-sentence. Fix: Use `vertical_strategy="text"` + `horizontal_strategy="text"`, increase `text_y_tolerance` to group wrapped lines, post-process to detect incomplete expressions (ending with "Y (" indicates truncation), implement continuation buffer. Must validate all prerequisites are complete before JSON output. **Phase 1 blocker.**

2. **Spanish compound surnames regex failure** — Professor names with lowercase prepositions ("del", "de", "la") truncated by naive capitalization regex. Fix: Parse sequentially, maintain lowercase prepositions as part of firstname, validate parsed names against known professor list. Edge case: "CASTROMATTA, Milagros Del Rosario" should parse to lastname="CASTROMATTA", firstname="Milagros Del Rosario". **Phase 1 data quality.**

3. **Missing table boundaries in pdfplumber** — First or last rows of course table dropped because boundary lines faint/missing. Fix: Inspect boundary lines before extraction, use `text_y_tolerance` parameters, fall back to `vertical_strategy="text"` if line-based fails, validate row count against visual count. **Phase 1 validation required.**

4. **Hidden import dependencies in PyInstaller** — Bundled app crashes with `ModuleNotFoundError` for `pandas._libs` or `pdfplumber.utils` despite working in dev. Fix: Use .spec file with explicit `hiddenimports=['pandas', 'pandas._libs.tslibs', 'pdfplumber']`, or use `collect_submodules('pandas')`. Test executable on clean Windows VM before release. **Phase 2 blocker.**

5. **PyInstaller `--onefile` startup slowdown** — Frozen .exe takes 30+ seconds to start because it unpacks entire bundle to temp directory on each run; Windows Defender scans temp extraction. Fix: Use `--onedir` instead (negligible size difference); if one-file required, distribute via installer that extracts once. Measure startup time <5 seconds before shipping. **Phase 2 UX critical.**

6. **File path hardcoding in bundled data** — Code has absolute paths like `C:\Users\johnb\Documents\MatriculaUp\data\courses.json`; when distributed, path invalid and app crashes. Fix: Use `sys._MEIPASS` in bundled context vs. `os.path.dirname(__file__)` in dev. Use pathlib for cross-platform `/` vs. `\` handling. Test same code in both dev and bundled contexts. **Phase 2 blocker.**

## Implications for Roadmap

Based on combined research, the recommended phase structure prioritizes extraction validation before UI development, then distribution hardening before public release.

### Phase 1: Extraction Pipeline Fix & Validation
**Rationale:** PDF extraction is independent of UI and must be bulletproof before bundling. All data corruption pitfalls (multi-line truncation, name parsing, missing rows) must be solved at extraction time, not runtime. Fixes here prevent silent data issues in distributed app.

**Delivers:**
- Fixed pdfplumber extraction with tuned parameters (text strategies, y_tolerance)
- Spanish name parser handling "Del", "de la", etc.
- Validation suite: row count checks, incomplete expression detection, encoding checks
- courses.json, prerequisites.json, curricula.json for 2026-1 (Economía 2017)
- Extraction CLI tool with README for future semesters
- Unit tests for each parsing module

**Addresses (Features):**
- Curriculum Filter (requires clean curricula.json)
- Prerequisite data (requires AND/OR logic trees)

**Avoids (Pitfalls):**
- Multi-line cell truncation (#1)
- Spanish surname regex failure (#2)
- Missing table boundaries (#3)
- PDF encoding issues (#7)
- Regex performance (#8)

**Duration:** 1-2 weeks (depends on PDF complexity and iteration cycles)

---

### Phase 2: Desktop App Bundle (PySide6 + PyInstaller)
**Rationale:** Once extraction outputs validated JSON, UI can be built independently without touching PDFs. This phase creates the user-facing app that reads bundled data.

**Delivers:**
- PySide6 window with main layout (search bar, course list, timetable, plan tracker)
- Course Search & Filter component (full-text search, case-insensitive)
- Section Selector (dropdown per course, shows capacity/instructor)
- Visual Timetable (week grid, Mon-Fri, 7:30-23:30, color-coded courses)
- Conflict Detection (highlights overlaps, shows exact time clash)
- Save/Load 3 Schedules (JSON persistence to disk, quick switch UI)
- Curriculum Filter (dropdown to select career, checkbox to mark completed)
- Schedule Export (PIL or reportlab to PNG)
- PyInstaller spec file with proper hidden imports and data bundling
- Tested .exe on clean Windows VM (no Python installed)

**Uses (Stack):**
- PySide6 (UI framework)
- PyInstaller (bundling)
- pyside6-deploy (size optimization)

**Implements (Architecture):**
- Data Access Layer (load courses.json into memory)
- UI Layer (all components)
- Read-only in-memory store

**Avoids (Pitfalls):**
- Hidden import dependencies (#4)
- `--onefile` startup slowdown (#5)
- Hardcoded file paths (#6)
- Thread safety issues (#9)
- UX pitfalls (opaque error messages, loading spinners)

**Duration:** 2-3 weeks (depends on complexity of conflict detection and timetable rendering)

**Research flags:** None — PySide6 + PyInstaller patterns well-documented.

---

### Phase 3: Windows Distribution & User Testing
**Rationale:** Once .exe is stable, package for end-user distribution and gather feedback to guide v1.1 roadmap.

**Delivers:**
- Inno Setup or NSIS installer (.exe installer, not bare binary)
- Installation guide + first-run wizard
- GitHub release with .exe and checksums
- User feedback survey (post-launch)

**Uses (Stack):**
- Inno Setup or NSIS (installer framework)

**Duration:** 1 week

---

### Phase 4: v1.1 Post-Launch (Conditional on User Feedback)
**Rationale:** Defer features pending real usage. If users ask for prerequisites or multi-semester, prioritize based on demand signal.

**Possible additions (subject to user feedback):**
- Prerequisite Validation (warn before selecting courses with unmet prerequisites)
- Multi-Semester Planning (if users ask "Can I plan 2026-1 and 2026-2 together?")
- Schedule Optimization Algorithm (if users spend >15min manual tweaking)
- Shared Schedule Comparison (if early adopters ask for friend overlaps)
- iCal export (if users want calendar sync)

**Duration:** 1-3 weeks per feature

---

### Phase Ordering Rationale

1. **Extraction first, UI second:** Extraction is independent and must be perfect before distribution. UI depends on extracted JSON; can't start until data layer is locked.

2. **Bundling tests Phase 2, not Phase 1:** PyInstaller hidden imports and file paths are UI-layer concerns. Focus Phase 1 purely on data quality.

3. **Distribution as separate phase:** Release engineering (installer creation, GitHub setup, release process) is distinct from app functionality and can proceed in parallel with Phase 2 testing.

4. **User feedback gates v1.1:** Prerequisite validation and multi-semester are high-value but not essential for MVP. Real usage data determines priority.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** PDF complexity assessment — if extraction proves fragile or data quality issues arise during initial extraction, may need additional research on pdfplumber alternative strategies or manual intervention workflows.
- **Phase 4+:** Real-time registration integration — if users request direct autoservicio.up.edu.pe integration in v2+, would require research into UP's authentication system and API capabilities (out of scope for v1).

Phases with standard patterns (skip research-phase):
- **Phase 2:** PySide6 + PyInstaller is battle-tested; extensive documentation and examples available. Standard patterns for bundling, resource embedding, conflict detection algorithms well-established.
- **Phase 3:** Windows installer creation and GitHub releases are mature tooling.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | PySide6 vs. alternatives evaluated against licensing, bundle size, widget availability. PyInstaller from official docs. pyside6-deploy tool verified with Qt docs. |
| Features | **MEDIUM-HIGH** | Table stakes (search, conflict, visual timetable) grounded in competitor analysis (Coursicle, uAchieve, MyStudyLife). MVP features chosen conservatively to avoid scope creep. v1.x/v2+ deferments clear and defensible. |
| Architecture | **HIGH** | Three-layer separation (extraction/data/UI) is established pattern for catalog-based apps. Extract-once-distribute-many reduces moving parts and avoids dependency bloat. JSON schema design follows schema.org Course and prerequisite logic patterns. |
| Pitfalls | **MEDIUM-HIGH** | Critical pitfalls (pdfplumber, PyInstaller) sourced from official docs, GitHub issues, and 2026-era comparisons. Spanish name parsing from linguistic best practices. Recovery strategies verified. Prevention checklists actionable. |

**Overall confidence:** **HIGH**

### Gaps to Address

1. **PDF structure assumptions:** Current extraction assumes Economía 2017 PDF format. If other careers (Derecho, Finanzas, Admin, etc.) have different table structures, extraction may need parameterization or manual intervention per career. **Mitigation:** Phase 1 must test at least one course from each of 7 careers; flag structural differences early.

2. **Curriculum data completeness:** Prerequisites and curricula depend on accurate PDF data. If academic plan PDFs are incomplete or outdated, JSON will inherit those gaps. **Mitigation:** Validate against known academic policies; flag incomplete prerequisite chains for manual review.

3. **PyInstaller Windows Defender interaction:** Real-world antivirus scanning behavior can't be fully predicted. `--onefile` startup times may vary widely. **Mitigation:** Phase 2 must test on clean Windows 10/11 VMs with Windows Defender active; measure startup time on multiple hardware configurations.

4. **User adoption on low-bandwidth networks:** If target students (Peruvian university) download large installer, distribution method matters. 40-80 MB is manageable but may struggle on poor connectivity. **Mitigation:** Monitor first 100 downloads; if churn high, consider peer distribution or on-campus USB installation.

5. **Multi-cycle data management:** v1 ships with 2026-1 data only. As new terms (2026-2, 2027-1) arrive, update strategy unclear (new app release vs. downloadable JSON). **Mitigation:** Phase 3 should document data update process; design v1.1 to support multiple semesters without app rebuild if feasible.

## Sources

### Primary Research (HIGH confidence)
- **STACK.md:** PySide6 official docs, PyInstaller docs (v6.19.0), pyside6-deploy Qt docs, licensing comparisons (Riverbank, Qt commercial)
- **FEATURES.md:** Coursicle, uAchieve, MyStudyLife competitor analysis; UP autoservicio documentation; UT Austin, NYU usability labs
- **ARCHITECTURE.md:** Layered architecture patterns, data pipeline design, prerequisite representation (Coursedog, schema.org), Tauri bundling docs
- **PITFALLS.md:** pdfplumber GitHub issues (multirow cells, table boundaries), PyInstaller official docs + Medium deep-dives, Spanish naming conventions (Wikipedia, family tree resources)

### Secondary Research (MEDIUM confidence)
- 2026 tooling comparisons (PyInstaller vs. Nuitka vs. cx_Freeze)
- Community forums (StackOverflow patterns for PyInstaller hidden imports)
- Spanish linguistic resources for name parsing

### Tertiary (LOW confidence, needs validation)
- Antivirus impact on startup time (varies by machine)
- Adoption projections for Peruvian university context (inference from comparable tools)

---

*Research completed: 2026-02-24*
*Ready for roadmap: yes*
*Synthesized from: STACK.md, FEATURES.md, ARCHITECTURE.md, PITFALLS.md*
