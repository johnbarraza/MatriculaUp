## Phase 6 Verification

### Must-Haves
- [x] El usuario puede ver su horario semanal interactivo a la derecha, y el buscador de cursos a la izquierda simultáneamente. — VERIFIED (evidence: `HomePage` layout has a 3:7 Flex layout wrapping `CourseSearchList` and `TimetableGrid`).
- [x] Si el usuario intenta agregar una sección de un curso que ya tiene matriculado, la UI de Flutter bloquea la acción y muestra un Snack-bar de advertencia. — VERIFIED (evidence: `ScheduleState.addSection` throws if course exists, caught by UI to show `SnackBar`).
- [x] Las secciones buscadas que cruzan con el horario actual resaltan en color rojo en la lista antes de intentar agregarlas. — VERIFIED (evidence: `CourseSearchList` turns the tile red and alters text when `state.conflictsWithSchedule` is true).

### Verdict: PASS
All requirements for Phase 6 (Interactive Schedule & Conflict Prevention) are met. Ready for Phase 7.
