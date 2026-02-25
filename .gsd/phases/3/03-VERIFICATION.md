## Phase 3 Verification

### Must-Haves

- [x] El usuario puede seleccionar su carrera y año de plan (ciclo dropdown) — VERIFIED (CurriculumTab with QComboBox over ciclos)
- [x] Los cursos del ciclo están marcados visualmente (🟢 Disponible / 🔴 No Dictado) — VERIFIED (color-coded table rows in _render_table)
- [x] La app muestra qué cursos del plan están disponibles en la oferta actual — VERIFIED (offered_codes set cross-references courses.json against curricula.json)
- [x] El usuario puede exportar su horario tentativo como imagen PNG — VERIFIED (export_to_png() uses self.grab(), schedule_tab._on_export() with QFileDialog + QMessageBox)

### Verdict: PASS
