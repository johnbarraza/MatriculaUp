# Requirements: MatriculaUp

**Defined:** 2026-02-24
**Core Value:** El estudiante puede ver todos los cursos ofertados del ciclo, seleccionar secciones y detectar conflictos de horario — sin abrir un solo PDF.

## v1 Requirements

### Extractor

- [x] **EXT-01**: El extractor procesa el PDF de oferta académica y genera un `courses.json` con todos los cursos, secciones y sesiones del ciclo
- [x] **EXT-02**: Los prerequisitos con lógica compuesta (Y/O multi-fila) se parsean completos sin truncar
- [x] **EXT-03**: Los nombres de docentes con apellidos compuestos (Del, De La, De Los) se capturan completos
- [x] **EXT-04**: El JSON generado es validado contra un esquema definido (estructura completa: curso → secciones → sesiones)
- [x] **EXT-05**: El extractor procesa el PDF del plan de estudios Economía 2017 y genera `curriculum_economia2017.json` con cursos por ciclo académico

### App — Búsqueda y Navegación

- [ ] **NAV-01**: El usuario puede buscar cursos por nombre, código o docente
- [ ] **NAV-02**: El usuario puede filtrar cursos por tipo de sesión (CLASE, PRÁCTICA, etc.)
- [ ] **NAV-03**: El usuario puede ver los detalles de un curso: secciones disponibles, horarios, docentes y prerequisitos

### App — Planeador de Horario

- [ ] **PLAN-01**: El usuario puede seleccionar una sección de un curso para agregarla a su horario tentativo
- [ ] **PLAN-02**: El usuario ve una grilla semanal visual (timetable) con los cursos seleccionados
- [ ] **PLAN-03**: La app detecta y alerta cuando dos sesiones seleccionadas se superponen en horario
- [ ] **PLAN-04**: El usuario puede remover un curso de su horario tentativo

### App — Plan de Estudios

- [ ] **PLAN-05**: El usuario puede seleccionar opcionalmente su carrera y año de plan de estudios
- [ ] **PLAN-06**: Con el plan activo, los cursos del ciclo se marcan visualmente según si son obligatorios, electivos u otros
- [ ] **PLAN-07**: El usuario puede ver qué cursos del plan de estudios están disponibles este ciclo

### App — Persistencia y Exportación

- [ ] **PERS-01**: El horario tentativo seleccionado se guarda automáticamente en la carpeta del usuario (AppData) — no se pierde al cerrar la app
- [ ] **PERS-02**: Los datos del usuario (horario guardado, carrera seleccionada, cursos marcados) persisten al actualizar la app a versiones nuevas (guardado fuera del directorio de instalación)
- [ ] **EXP-01**: El usuario puede exportar su horario tentativo como imagen PNG para compartir

### App — Distribución

- [ ] **DIST-01**: La app se distribuye como instalador `.exe` para Windows que incluye el ejecutable y los JSONs pre-extraídos
- [ ] **DIST-02**: La app funciona sin tener Python instalado en el sistema del usuario

## v2 Requirements

### Actualización de datos

- **UPD-01**: La app puede verificar si hay una versión nueva de los datos (nuevo ciclo) en GitHub y descargarla
- **UPD-02**: El usuario puede actualizar los datos del ciclo sin reinstalar la app

### Prerequisitos avanzados

- **PREREQ-01**: La app evalúa si el usuario cumple los prerequisitos de un curso según los cursos que marcó como aprobados
- **PREREQ-02**: El usuario puede marcar cursos como aprobados para filtrar la oferta disponible

### Carreras adicionales

- **CARR-01**: Soporte para planes de estudios de otras carreras (Finanzas, Admin, Derecho, etc.)
- **CARR-02**: El usuario puede planificar cursos de doble carrera simultáneamente

## Out of Scope

| Feature | Reason |
|---------|--------|
| Integración con sistema de matrícula real (UP Autoservicio) | Requiere acceso API no público; fuera del objetivo offline |
| App móvil (Android/iOS) | Distribución desktop-first; mobile agrega complejidad sin validar demanda |
| Autenticación / cuentas en la nube | Offline-first; sincronización en la nube no requerida en v1 |
| Optimización automática de horario (algoritmo) | Complejidad alta; validar demanda real post-lanzamiento |
| Múltiples ciclos simultáneos en v1 | Foco 2026-1 para validar; multi-ciclo es v2 |
| Extracción de roles de exámenes en v1 | Foco en horarios de clases; exámenes son complementarios |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EXT-01 | Phase 1: Extraction | Complete |
| EXT-02 | Phase 1: Extraction | Complete |
| EXT-03 | Phase 1: Extraction | Complete |
| EXT-04 | Phase 1: Extraction | Complete |
| EXT-05 | Phase 1: Extraction | Complete |
| NAV-01 | Phase 2: Desktop App Core | Pending |
| NAV-02 | Phase 2: Desktop App Core | Pending |
| NAV-03 | Phase 2: Desktop App Core | Pending |
| PLAN-01 | Phase 2: Desktop App Core | Pending |
| PLAN-02 | Phase 2: Desktop App Core | Pending |
| PLAN-03 | Phase 2: Desktop App Core | Pending |
| PLAN-04 | Phase 2: Desktop App Core | Pending |
| PLAN-05 | Phase 3: Curriculum & Export | Pending |
| PLAN-06 | Phase 3: Curriculum & Export | Pending |
| PLAN-07 | Phase 3: Curriculum & Export | Pending |
| PERS-01 | Phase 2: Desktop App Core | Pending |
| PERS-02 | Phase 2: Desktop App Core | Pending |
| EXP-01 | Phase 3: Curriculum & Export | Pending |
| DIST-01 | Phase 4: Distribution | Pending |
| DIST-02 | Phase 4: Distribution | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0 ✓

---

*Requirements defined: 2026-02-24*
*Traceability updated: 2026-02-24 after roadmap creation*
