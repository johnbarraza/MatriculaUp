# MatriculaUp Roadmap

**Project:** MatriculaUp — University course schedule planner
**Core Value:** El estudiante puede ver todos los cursos ofertados del ciclo, seleccionar secciones y detectar conflictos de horario — sin abrir un solo PDF.

**Phases:** 4
**Depth:** quick (3-5 phases)
**Total Requirements:** 20 v1
**Coverage:** 20/20 requirements mapped

---

## Phases

- [x] **Phase 1: Extraction Pipeline Fix & Validation** - Fix PDF extraction bugs and validate data quality before app development (completed 2026-02-25)
- [x] **Phase 2: Desktop App Core (Search, Plan, Persist)** - Build PySide6 app with course search, schedule builder, conflict detection, and data persistence (completed 2026-02-25)
- [x] **Phase 3: Curriculum Integration & Export** - Add curriculum filter and PNG schedule export (completed 2026-02-25)
- [x] **Phase 4: Windows Distribution** - Create installer and bundle app as standalone .exe (completed 2026-02-25)

---

## Milestone v1.1 (UI/UX Refinements & Conflict Prevention)

- [ ] **Phase 5: Interactive Schedule & Conflict Prevention** - Side-by-side interactive timetable during search, visual conflict warnings before adding, and duplicate course prevention.
- [ ] **Phase 6: Advanced Views & Dynamic Data** - Break timetable into Regular (Mon-Sat) and Exam (Final/Parcial) views, improve grid labeling, and allow loading custom external JSON files from the UI.

---

## Phase Details

### Phase 1: Extraction Pipeline Fix & Validation

**Goal:** Fix pdfplumber extraction bugs and generate validated JSON data files (courses.json, curricula.json) ready for bundling with the app.

**Depends on:** Nothing (first phase)

**Requirements:** EXT-01, EXT-02, EXT-03, EXT-04, EXT-05

**Success Criteria** (what must be TRUE when this phase completes):

1. El extractor procesa el PDF de oferta académica 2026-1 y genera courses.json con todos los cursos, secciones y sesiones sin truncar ni faltar datos
2. Los prerequisitos con lógica compuesta (Y/O) se capturan completos — no hay truncación en multi-línea (valida que no terminen con "Y (" incompleto)
3. Los nombres de docentes con apellidos compuestos (Del, De La, De Los, etc.) se capturan completos en formato "LASTNAME, Firstname With Prepositions"
4. El JSON cumple esquema validado: estructura curso → secciones → sesiones con todos los campos requeridos (horario 24h, aula, tipo de sesión)
5. El extractor genera curricula.json (plan Economía 2017) con cursos organizados por ciclo académico y tipos (obligatorio, electivo)

**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Test scaffolding (TDD Red phase): pytest fixtures, failing unit tests for prerequisite buffer and Spanish name regex
- [ ] 01-02-PLAN.md — Courses extractor: migrate v6 notebook to scripts/extractors/courses.py, fix prerequisite truncation + Spanish surname regex, generate courses_2026-1.json
- [ ] 01-03-PLAN.md — Curriculum extractor: implement scripts/extractors/curriculum.py, generate curricula_economia2017.json by academic cycle
- [ ] 01-04-PLAN.md — Schema validation: implement validators.py with jsonschema, wire into both extractors, validate real output files

---

### Phase 2: Desktop App Core (Search, Plan, Persist)

**Goal:** Build a functional PySide6 desktop application that allows students to search courses, build schedules, detect conflicts, and save their work.

**Depends on:** Phase 1 (needs validated JSON data)

**Requirements:** NAV-01, NAV-02, NAV-03, PLAN-01, PLAN-02, PLAN-03, PLAN-04, PERS-01, PERS-02

**Success Criteria** (what must be TRUE when this phase completes):

1. El usuario puede buscar cursos por nombre, código o docente en una interfaz de búsqueda con resultados instantáneos
2. El usuario puede filtrar resultados por tipo de sesión (CLASE, PRÁCTICA, FINAL, PARCIAL, etc.)
3. El usuario ve detalles de cada curso: secciones disponibles, horarios exactos, docentes y prerequisitos
4. El usuario puede seleccionar una sección de un curso y agregarla a su horario tentativo
5. El usuario ve una grilla semanal visual (lunes-viernes, 7:30-23:30) con colores diferentes por curso
6. Cuando dos sesiones seleccionadas se superponen en horario, la app muestra alerta visual y detalla el conflicto exacto
7. El usuario puede remover cursos de su horario tentativo
8. El horario tentativo se guarda automáticamente en AppData del usuario y persiste al cerrar y reabrirGradio app

**Plans:** 4/4 plans complete

Plans:
- [x] 02-01-PLAN.md — Foundation & Data Layer (Data Models, Persistence Shell)
- [x] 02-02-PLAN.md — Course Search UI (Search Layout, Tree View)
- [x] 02-03-PLAN.md — Timetable Grid & Conflict Detection (Logic and Visual Grid)
- [x] 02-04-PLAN.md — Integration & State (Global State, Wiring, Auto-save)

---

### Phase 3: Curriculum Integration & Export

**Goal:** Add curriculum awareness (filter courses by required/elective status) and allow students to export schedules as PNG images.

**Depends on:** Phase 2 (extends existing app)

**Requirements:** PLAN-05, PLAN-06, PLAN-07, EXP-01

**Success Criteria** (what must be TRUE when this phase completes):

1. El usuario puede seleccionar su carrera y año de plan de estudios (ej. Economía 2017, 3er ciclo) desde un dropdown en la app
2. Una vez seleccionado el plan, los cursos del ciclo están marcados visualmente indicando si son obligatorios, electivos u otros
3. La app muestra qué cursos del plan de estudios están disponibles en la oferta actual del ciclo
4. El usuario puede exportar su horario tentativo como imagen PNG con nombres de cursos, horarios y docentes, lista para compartir

**Status**: ✅ Complete

**Plans:** 2/2 plans complete

Plans:
- [x] 03-01-PLAN.md — Curriculum Integration (Models, Filter UI Tab)
- [x] 03-02-PLAN.md — Export to PNG (QPixmap Rendering, File Prompt)

---

### Phase 4: Windows Distribution

**Goal:** Package the app as a Windows installer (.exe) with bundled data files, enabling students to install and run without Python.

**Depends on:** Phase 2 (app must be stable), Phase 3 (all features complete)

**Requirements:** DIST-01, DIST-02

**Success Criteria** (what must be TRUE when this phase completes):

1. La app se distribuye como instalador .exe que incluye ejecutable, librerías Python, y JSONs pre-extraídos
2. El usuario final instala el .exe en una PC Windows sin Python pre-instalado y la app funciona sin dependencias externas
3. El instalador crea acceso directo en menú Inicio y permite desinstalación estándar
4. El archivo de datos del usuario (horario guardado, carrera seleccionada) persiste correctamente después de actualizar la app a una versión nueva

**Status**: ✅ Complete

**Plans:** 2/2 plans complete

Plans:
- [x] 04-01-PLAN.md — PyInstaller Configuration (Path resolution & build script)
- [x] 04-02-PLAN.md — Windows Installer Distribution (Inno Setup automation)

---

### Phase 5: Interactive Schedule & Conflict Prevention (v1.1)

**Goal:** Enhance the core scheduling experience by merging search and timetable views, and actively preventing users from creating invalid schedules (crosses or duplicate courses).

**Depends on:** Phase 4 (builds on v1 core)

**Requirements:** NAV-04 (Side-by-side view), PLAN-08 (Duplicate prevention), PLAN-09 (Pre-selection conflict hints)

**Success Criteria** (what must be TRUE when this phase completes):

1. El usuario puede ver su horario semanal interactivo en la misma pantalla/vista mientras busca y explora cursos nuevos.
2. Si el usuario intenta agregar una sección de un curso que ya tiene en su horario (incluso si es otra sección deferente), la app bloquea la acción y muestra un aviso.
3. En la lista de resultados de búsqueda, las secciones que cruzan con el horario actual del usuario se marcan visualmente (ej. fondo rojo o ícono de alerta) antes de que el usuario intente agregarlas.

**Status**: 🏃 In Progress

**Plans:** 0/2 plans complete

Plans:
- [ ] 05-01-PLAN.md — Interactive Side-by-Side Schedule
- [ ] 05-02-PLAN.md — Duplicate Prevention & Visual Conflict Hints

---

### Phase 6: Advanced Views & Dynamic Data (v1.1)

**Goal:** Improve timetable readability by separating exam weeks from regular classes, displaying full course names, and allowing users to load external cycle data.

**Depends on:** Phase 5 (UI refactoring)

**Requirements:** UI-01 (Exam views), UI-02 (Grid labels), DATA-01 (External JSON loading)

**Success Criteria** (what must be TRUE when this phase completes):

1. El horario semanal tiene pestañas/vistas independientes para "Clases y Prácticas" (Lun-Sab) y "Exámenes" (Parcial y Final). Las sesiones se distribuyen a sus respectivas vistas.
2. Los bloques dibujados en la grilla visualizan el nombre corto/código del curso además del tipo de sesión, mejorando la legibilidad.
3. La aplicación cuenta con un botón/opción en la interfaz que abre un diálogo de archivos para cargar un archivo `.json` de oferta académica (ej. 2026-2) sin necesidad de recompilar la app.

**Status**: ⬜ Not Started

**Plans:** TBD

---

## Progress Tracking

| Phase | Goal | Requirements | Success Criteria |
|-------|------|--------------|------------------|
| 1 - Extraction Fix | 4/4 | Complete   | 2026-02-25 |
| 2 - Desktop App Core | 4/4 | Complete | 2026-02-25 |
| 3 - Curriculum & Export | Curriculum filter, PNG export | 4 (PLAN-05 to PLAN-07, EXP-01) | 4 criteria |
| 4 - Distribution | Windows installer, .exe bundle | 2 (DIST-01, DIST-02) | 4 criteria | Complete 2026-02-25 |

**Coverage:** 20/20 requirements ✓ All v1 requirements mapped, no orphans.

---

## Phase Dependencies

```
Phase 1: Extraction Fix & Validation
    ↓
Phase 2: Desktop App Core (consumes validated JSON from Phase 1)
    ↓
Phase 3: Curriculum & Export (extends Phase 2)
    ↓
Phase 4: Distribution (bundles Phases 1-3)
```

---

## Notes

- **Phase 1 is critical path:** All phases depend on extraction data quality. Multi-line prerequisite truncation, Spanish name parsing, and missing rows must be solved at extraction time before bundling.
- **Phase 2 delivers MVP:** Search + Schedule + Conflict detection + Persistence = core value proposition (plan without PDFs).
- **Phase 3 adds curriculum context:** For students who want to verify courses against their academic plan.
- **Phase 4 enables distribution:** PyInstaller + Inno Setup produces standalone .exe; tested on clean Windows VM without Python.
- **Research flags:** Phase 1 requires validation of PDF structure assumptions (current extraction assumes Economía 2017 format; other careers may differ). Phase 2 requires PyInstaller hidden import testing on clean Windows VM.

---

*Roadmap created: 2026-02-24*
*Ready for planning: yes*
