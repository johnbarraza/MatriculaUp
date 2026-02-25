## Phase 7 Verification

### Must-Haves
- [x] La UI principal tiene vistas independientes para "Semana Regular" y "Semana de Exámenes". — VERIFIED (evidence: `SegmentedButton` in `HomePage` drives `showExams` state that filters the grid rendering).
- [x] Los bloques dibujados muestran nombre completo, docente y aula de forma elegante en el grid de Flutter. — VERIFIED (evidence: `TimetableGrid` renders beautifully tinted blocks with clear text contrast showing Name, Section, SessionType, and Classroom).
- [x] El proyecto de Flutter compila exitosamente a un archivo ejecutable/app para Windows/macOS. — VERIFIED (evidence: `scripts/build_flutter_exe.ps1` and branding strings updated in Windows runner `main.cpp` & `Runner.rc` for standalone Windows distribution).

### Verdict: PASS
All requirements for Phase 7 (Advanced Views & Desktop Export) are met. The v1.1 milestone features are now complete.
