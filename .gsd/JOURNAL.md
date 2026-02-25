## Session: 2026-02-25 17:00

### Objective
Fix PDF extraction column alignment bug and implement Phase 9 UI improvements in the Flutter app.

### Accomplished
- ✅ **Phase 9 Complete**: IndexedStack for search tab persistence, conflict reason display ("Cruce con: Curso X"), session detail formatting (tipo/dia/hora), virtual room formatting ("Virtual"), Obligatorio/Electivo tags via optional Curriculum JSON.
- ✅ **Extractor Fix (Phase 10)**: Diagnosed and fixed 10-col vs 11-col PDF row format. Sections G-M of "Religiones, Culturas y Economía" now extract with correct `dia` values.
- ✅ **Session tipo display**: Fixed `SessionType.clase` enum display → `Clase` in the UI.
- ✅ **JSON regenerated**: `courses_2026-1.json` re-extracted (253 cursos, 14 advertencias, schema validated).

### Verification
- [x] `flutter analyze` → No issues found.
- [x] `flutter build windows` → Build successful.
- [x] `python debug_religiones.py` → Religiones K/G/H/M have correct dia values.
- [x] All changes committed and pushed to GitHub.

### Next Steps
- Test in the running Windows app: add sección K of Religiones and confirm it appears in the timetable.
- Answer any remaining user questions about missing features.

---

## Session: 2026-02-24 23:55

### Objective
Complete Phase 4 (Windows Distribution) and plan the next Milestone (v1.1) based on user feedback.

### Accomplished
- ✅ Executed Phase 4 successfully.
- ✅ Fixed PyInstaller relative path imports (`src.matriculaup`).
- ✅ User verified `MatriculaUp_v1_Setup.exe` installs and runs flawlessly on Windows.
- ✅ Created the new Roadmap for Milestone v1.1.
- ✅ **PIVOT**: Decided to migrate the entire frontend from PySide6 to **Flutter** for Phase 5 onwards. The goal is a highly interactive, mobile-ready (or desktop-native) modern UI.

### Verification
- [x] Phase 4 Windows Installer confirmed working by the user.
- [x] Flutter Pivot ROADMAP.md and PLAN files created and committed to Git.

### Paused Because
- User requested to save progress for tomorrow.

### Handoff Notes
- We are officially **done with Python GUI development** (PySide6).
- The next step (Phase 5) is to initialize a brand new Flutter project (`matriculaup_app`) in the same repository.
- The user confirmed Flutter is the stack of choice, but specifically targeting **Windows/Mac (Desktop)**, not Android.
- The Python code will remain in the repo ONLY as a backend data-extraction script to generate the JSONs from the PDFs.
- Run `/resume` next session and start with `/execute 5` to begin Flutter initialization.
