# MatriculaUP - Planificador Inteligente de Horarios

Sistema de planificación de horarios universitarios con gestión de cursos obligatorios por carrera y ciclo.

## Características Principales

### 1. Gestión de Carreras y Cursos Obligatorios

- **Selección de carrera**: Carga automática del plan de estudios desde archivos JSON
- **Visualización global**: Muestra TODOS los cursos obligatorios en una sola vista
- **Marcado rápido**: Sistema de checkboxes para marcar cursos completados
- **Filtro por ciclo**: Herramienta opcional para marcar/desmarcar cursos por ciclo académico
- **Estadísticas en tiempo real**: Muestra cursos llevados vs. pendientes

**Carreras soportadas:**
- Economía (Plan 2017/2022)
- Finanzas (Plan 2018/2021)

### 2. Búsqueda y Selección de Cursos

- **Búsqueda inteligente**: Por nombre de curso o docente
- **Filtros avanzados**:
  - Solo cursos obligatorios
  - Solo cursos pendientes (obligatorios no llevados)
- **Selección múltiple**: Añade varias secciones a la vez
- **Formato limpio**: Vista simplificada de secciones sin información redundante

### 3. Planificación de Horarios

- **3 horarios simultáneos**: Compara diferentes combinaciones
- **Detección automática de conflictos**: Identifica solapamientos de horario
- **Límite de créditos**: Validación automática (máximo 25 créditos)
- **Visualización semanal mejorada**:
  - Rango horario: 7:30 AM - 11:30 PM
  - Separación de clases y exámenes
  - Resaltado visual de conflictos

### 4. Exportación y Persistencia

- **Exportar a Excel**: Guarda horarios individuales
- **Exportar a PNG**: Imágenes de alta calidad de la visualización semanal
- **Guardar progreso**: Almacena horarios, créditos, cursos llevados y carrera seleccionada
- **Cargar progreso**: Restaura sesiones anteriores

## Requisitos

### Dependencias

```
gradio
pandas
openpyxl
matplotlib
pillow
```

### Instalación

```bash
# Crear entorno conda
conda create -n up python=3.10
conda activate up

# Instalar dependencias
pip install -r requirements.txt
```

## Uso

### Ejecutar la aplicación

```bash
conda activate up
python scripts/matricula_app.py
```

La aplicación se abrirá en `http://127.0.0.1:7860`

### Flujo de trabajo recomendado

1. **Configuración inicial**
   - Seleccionar carrera del dropdown
   - Hacer clic en "Cargar Carrera"
   - Cargar archivo Excel con horarios disponibles

2. **Marcar cursos llevados**
   - Marcar checkboxes de cursos ya completados
   - Opcionalmente usar "Marcar por Ciclo" para seleccionar ciclos completos
   - Ver estadísticas actualizadas en tiempo real

3. **Buscar y añadir cursos**
   - Usar filtros "Solo obligatorios" o "Solo pendientes"
   - Buscar por nombre o docente
   - Seleccionar secciones disponibles
   - Añadir a uno de los 3 horarios

4. **Gestionar conflictos**
   - Revisar conflictos detectados automáticamente
   - Usar "Reemplazar conflictos" si es necesario
   - Visualizar horarios semanales

5. **Guardar y exportar**
   - Guardar progreso (horarios + cursos llevados)
   - Exportar horarios a Excel
   - Exportar visualizaciones a PNG

## Estructura del Proyecto

```
MatriculaUP/
├── input/                          # Archivos de entrada
│   ├── economia2017.json          # Plan de estudios Economía
│   ├── finanzas2018.json          # Plan de estudios Finanzas
│   └── Horarios_UP_V6_Perfecto.xlsx  # Horarios disponibles
├── output/                         # Archivos generados
├── scripts/
│   └── matricula_app.py           # Aplicación principal
├── MEJORAS.md                      # Documentación de mejoras
├── README.md                       # Este archivo
└── requirements.txt                # Dependencias Python
```

## Formato de Datos

### JSON de Currículo

```json
{
  "title": "FLUJOGRAMA DE LA CARRERA...",
  "faculty": "FACULTAD DE ECONOMÍA Y FINANZAS",
  "cycles": ["CICLO CERO", "PRIMER CICLO", ...],
  "courses": [
    {
      "name": "Economía General I",
      "code": "ECO",
      "credits": "5",
      "cycle_recommended": "PRIMER CICLO"
    }
  ]
}
```

### Archivo de Progreso

```json
{
  "schedules": {
    "1": [...],
    "2": [...],
    "3": [...]
  },
  "credits": {
    "1": 18.0,
    "2": 0.0,
    "3": 0.0
  },
  "taken": ["economia general i", "matematicas i", ...],
  "current_career": "Economía"
}
```

## Mejoras Recientes

### v2.0 (Diciembre 2025)

**UX Mejorada:**
- ✅ Sistema de marcado global de cursos (no ciclo por ciclo)
- ✅ Visualización de TODOS los cursos obligatorios a la vez
- ✅ Selector de ciclo como herramienta opcional, no obligatoria
- ✅ Formato limpio de secciones sin información redundante

**Correcciones:**
- ✅ Error de `boxstyle` en matplotlib Rectangle
- ✅ Mejora en parsing de secciones (formato con pipe separator)
- ✅ Type hints completos (100% coverage)
- ✅ Validación robusta de datos

**Funcionalidades:**
- ✅ Exportación a PNG de alta calidad
- ✅ Rango horario extendido (7:30 AM - 11:30 PM)
- ✅ Detección mejorada de conflictos
- ✅ Filtros avanzados de búsqueda

Ver [MEJORAS.md](MEJORAS.md) para detalles completos.

## Extensibilidad

### Añadir nuevas carreras

1. Crear archivo JSON en `input/` con el formato especificado
2. Añadir mapeo en el código:

```python
CAREER_CURRICULUM_MAP = {
    "Economía": "economia2017.json",
    "Finanzas": "finanzas2018.json",
    "Administración": "administracion2023.json",  # Nueva carrera
}
```

## Próximas Mejoras Sugeridas

1. **Recomendador automático**: Algoritmo que sugiera combinaciones óptimas de horarios
2. **Filtro por ciclo**: Mostrar solo cursos recomendados para un ciclo específico
3. **Exportar a calendario**: Integración con Google Calendar/iCal
4. **Vista de prerequisitos**: Mostrar cursos prerequisito no completados
5. **Comparación de horarios**: Vista lado a lado de los 3 horarios
6. **Validación de prerequisitos**: Advertir si faltan cursos previos
7. **Más carreras**: Expandar a todas las carreras de la universidad

## Créditos

**Versión**: 2.0
**Fecha**: Diciembre 2025
**Stack**: Python, Gradio, Pandas, Matplotlib

---

Para reportar bugs o sugerir mejoras, crear un issue en el repositorio.
