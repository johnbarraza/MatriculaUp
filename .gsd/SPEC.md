# MatriculaUp

## What This Is

Aplicación de escritorio para planificar la matrícula universitaria en la Universidad del Pacífico. Extrae la oferta de cursos de PDFs oficiales a JSON estructurado y permite a los estudiantes armar horarios tentativos, detectar conflictos y cruzar con su plan de estudios. Diseñada para distribuirse con los datos ya extraídos para que otros estudiantes puedan usarla sin necesidad de procesar PDFs.

## Core Value

El estudiante puede ver todos los cursos ofertados del ciclo, seleccionar secciones y detectar conflictos de horario — sin abrir un solo PDF.

## Requirements

### Validated

- ✓ Extracción de PDFs de oferta académica con pdfplumber — existing (`scripts/pdf_to_csv.ipynb`)
- ✓ Modelo de curso multi-sesión (CLASE, FINAL, PARCIAL, PRÁCTICA, CANCELADA, PRACDIRIGIDA, PRACCALIFICADA) — existing
- ✓ Detección básica de conflictos de horario — existing (`scripts/schedule-builder.py`, `scripts/matricula_app.py`)
- ✓ Datos de plan de estudios en JSON por carrera — existing (`pdfs/plan_estudios/economía/2017/economia2017.json`)
- ✓ Búsqueda y filtro de cursos — existing (Gradio app)

### Active

- [ ] Extractor corregido: prerequisitos completos sin truncar
- [ ] Extractor corregido: nombres de múltiples docentes sin cortar
- [ ] Output en JSON estructurado (reemplaza Excel/CSV) por ciclo
- [ ] App de escritorio distribuible (Tauri u opción evaluada en investigación)
- [ ] Vista de cursos ofertados del ciclo con búsqueda y filtro
- [ ] Selección de secciones con detección de conflictos de horario
- [ ] Plan de estudios opcional: elegir carrera + año de plan y ver cursos pendientes
- [ ] Distribución: app + JSON pre-extraído bundleado (v1), actualización desde GitHub (v2)

### Out of Scope

- Múltiples carreras en v1 — solo Economía 2017 para el ciclo 2026-1 inicialmente
- Integración con sistema de matrícula real de la UP — solo planificador offline
- Autenticación / cuentas de usuario — no requerido
- Extracción de roles de exámenes — foco en horarios de clases

## Context

**Ciclo objetivo v1:** 2026-1
**PDF oferta:** `pdfs/matricula/2026-1/regular/Oferta-Academica-2026-I_v1.pdf`
**PDF plan de estudios:** `pdfs/plan_estudios/economía/2017/2017_Plan-de-Estudios-Economia-2017-Cursos_30.10.2020-1.pdf`
**JSON plan existente:** `pdfs/plan_estudios/economía/2017/economia2017.json`

**Carreras disponibles en PDFs:** admin, derecho, economía, finanzas, humanidades_digitales, ingre_empre, polit_filo_eco

**Estructura de sesiones:** Un curso tiene N sesiones tipificadas. Ejemplo: un curso puede tener 2 sesiones CLASE (lunes/miércoles) + 1 PRÁCTICA (viernes). Cada sesión tiene: día, hora inicio, hora fin, aula, tipo.

**Stack existente:** Python 3.11, pdfplumber, pandas, gradio, tkinter. Extractor funciona parcialmente — bugs en prerequisitos truncados y nombres de docentes cortados.

**Problemas conocidos del extractor:**
1. Prerequisitos con lógica compuesta (Y/O) se truncan: `"138201 Microeconomía I Y (166097 Contabilidad Financiera I O "` queda incompleto
2. Nombres de docentes con apellidos compuestos se cortan: `"CASTROMATTA, Milagros Del Rosario"` aparece truncado porque "Del" no matchea el regex esperado

## Constraints

- **Distribución**: El ejecutable debe funcionar sin instalar Python — los usuarios son estudiantes sin setup técnico
- **Datos**: Los JSONs se generan una vez y se bundlean con la app; actualización opcional vía GitHub releases
- **Plataforma primaria**: Windows (la mayoría de usuarios UP usa Windows)
- **Stack extractor**: Se mantiene Python para extracción — reutiliza lógica existente

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| JSON en lugar de CSV/Excel | Datos jerárquicos (curso → N sesiones, prerequisitos anidados) no se representan bien en CSV | — Pending |
| Framework UI desktop (Tauri vs PyQt vs Electron) | Afecta distribución, tamaño de binario y reutilización del código Python existente | — Pending (a resolver en investigación) |
| Extractor separado del app | El pipeline de extracción se ejecuta una vez por ciclo; el app solo consume JSON | — Pending |

---
*Last updated: 2026-02-24 after initialization*
