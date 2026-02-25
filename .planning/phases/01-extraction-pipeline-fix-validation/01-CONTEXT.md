# Phase 1: Extraction Pipeline Fix & Validation - Context

**Gathered:** 2026-02-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Corregir el extractor Python existente (pdfplumber) y generar dos archivos JSON estructurados:
- `input/courses_2026-1.json` — oferta académica del ciclo 2026-1 (de `pdfs/matricula/2026-1/regular/Oferta-Academica-2026-I_v1.pdf`)
- `input/curricula_economia2017.json` — plan de estudios Economía 2017 (de `pdfs/plan_estudios/economía/2017/2017_Plan-de-Estudios-Economia-2017-Cursos_30.10.2020-1.pdf`)

El extractor es un script CLI Python que corre una vez por ciclo. No hay UI en esta fase.

</domain>

<decisions>
## Implementation Decisions

### Esquema JSON

- Estructura anidada completa: `curso → secciones[] → sesiones[]`
- Campos por curso: codigo, nombre, creditos, prerequisitos (árbol estructurado), secciones[]
- Campos por sección: seccion (letra), docentes[], observaciones, sesiones[]
- Campos por sesión: tipo (CLASE/PRÁCTICA/FINAL/PARCIAL/CANCELADA/PRACDIRIGIDA/PRACCALIFICADA), dia, hora_inicio, hora_fin, aula
- Prerequisitos como árbol estructurado: `{"op": "AND"|"OR", "items": [{"code": "138201", "name": "Microeconomía I"} | recurse]}`
- Si un prerequisito no se puede parsear a árbol: guardar como `{"raw": "texto original completo", "parsed": false}` — no perder datos
- Dos archivos separados: `courses_2026-1.json` y `curricula_economia2017.json`

### Invocación del extractor

- Un script unificado: `scripts/extract.py` con args de CLI
- Uso: `python scripts/extract.py --type courses --pdf pdfs/matricula/2026-1/regular/Oferta-Academica-2026-I_v1.pdf`
- Uso: `python scripts/extract.py --type curriculum --pdf pdfs/plan_estudios/economía/2017/2017_Plan-de-Estudios-Economia-2017-Cursos_30.10.2020-1.pdf`
- Output siempre va a la carpeta `input/` (ya existe en el repo)
- Nombre de archivo output incluye el ciclo/plan: `courses_2026-1.json`, `curricula_economia2017.json`
- Reemplaza el notebook `pdf_to_csv.ipynb` — nuevo `scripts/extract.py` es el único punto de entrada productivo

### Manejo de errores

- Filas que no se pueden parsear: saltar y loggear (no fallar la extracción completa)
- Log de filas problemáticas mostrado al final del run
- Progreso durante ejecución: `Página X/Y procesada...` + resumen final: `N cursos, M secciones, K advertencias`
- Prerequisitos no parseables: guardar raw string con flag `"parsed": false` — nunca descartar

### Validación del output

- Reporte en consola al terminar: `✅ courses.json: 234 cursos, 18 secciones promedio, 2 advertencias`
- Detección de truncación por patrones incompletos: si un prerequisito termina con `"Y ("` o `"O ("` sin cerrar → flaggeado como truncado
- Criterio de éxito: < 1% de errores (filas con problemas / total de filas)
- Si > 1% de errores → la extracción retorna exit code 1 y muestra advertencia prominente

### Claude's Discretion

- Exacto formato del log de errores
- Cómo manejar páginas del PDF sin tabla (páginas de encabezado, portada)
- Algoritmo exacto de detección de bordes de tabla en pdfplumber
- Estructura interna del script (clases vs funciones)

</decisions>

<specifics>
## Specific Ideas

- El notebook existente `pdf_to_csv.ipynb` tiene lógica v6 con regex para docentes — el nuevo script debe preservar esa lógica pero corregir los bugs específicos de apellidos compuestos y prerequisitos truncados
- El bug de docentes: regex `([A-ZÑÁÉÍÓÚ][A-Za-zÑÁÉÍÓÚñáéíóú\s\-\.]+,[\s]+[A-ZÑÁÉÍÓÚ][A-Za-zÑÁÉÍÓÚñáéíóú\s\-\.]+)` falla con "Del", "De La", "De Los" porque son minúsculas. El fix debe aceptar preposiciones de nombre en minúsculas dentro del nombre propio.
- El bug de prerequisitos: se cortan cuando la celda multi-fila del PDF se split en rows de tabla. El fix debe acumular filas de prerequisitos hasta detectar el inicio de una sección/clase.
- JSON ya existente `pdfs/plan_estudios/economía/2017/economia2017.json` puede servir como referencia de estructura para `curricula_economia2017.json`

</specifics>

<deferred>
## Deferred Ideas

- Soporte para otros ciclos (2025-II, etc.) — el script debe ser parametrizable pero el foco de testing es 2026-1
- Extracción de roles de exámenes — out of scope para v1
- Múltiples carreras en curricula — solo Economía 2017 en v1

</deferred>

---

*Phase: 01-extraction-pipeline-fix-validation*
*Context gathered: 2026-02-24*
