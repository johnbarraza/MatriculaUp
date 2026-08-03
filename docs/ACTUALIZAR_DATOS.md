# Cómo actualizar los datos de cursos

Guía para colaboradores que quieran actualizar los JSONs de cursos regulares o EFEs para un nuevo ciclo académico.

---

## Requisitos previos

```bash
pip install -r requirements.txt
```

Python 3.10+ requerido. Dependencias principales: `pdfplumber`, `pandas`, `openpyxl`.

---

## Archivos que se actualizan

| Archivo destino | Descripción |
|---|---|
| `matriculaup_app/assets/default_courses.json` | Cursos regulares (siempre este nombre) |
| `matriculaup_app/assets/efe_courses_CICLO_vX.json` | EFEs del ciclo |

---

## 1. Cursos regulares

### Obtener el PDF
Descarga el PDF de oferta académica del portal de la UP.  
Ejemplo: `Oferta-Academica-2026-II-V3-22.07.pdf`

Colócalo en:
```
pdfs/matricula/2026-2/regular/
```

### Extraer
Desde la raíz del repositorio:
```bash
python scripts/extract.py --type courses \
  --pdf pdfs/matricula/2026-2/regular/Oferta-Academica-2026-II-V3-22.07.pdf
```

El JSON se guarda en `input/courses_2026-2_v3.json` (o similar).

### Copiar al proyecto Flutter
```bash
cp input/courses_2026-2_v3.json matriculaup_app/assets/default_courses.json
```

El nombre **siempre** es `default_courses.json` — no es necesario cambiar código.

---

## 2. Cursos EFE

Los EFEs requieren **dos archivos fuente**: un PDF de horarios y un Excel de sesiones SSU.

### Obtener archivos
Colócalos en `pdfs/matricula/2026-2/EFEs/`:
- `Horarios-ofertados-matricula-2026-II-planes-antiguos.pdf`
- `Sesiones SSU 2026-II.xlsx`

### Paso 1 — Extraer del PDF + Excel
```bash
python scripts/extractors/efe_ssu.py
```

Por defecto lee `pdfs/matricula/2026-2/EFEs/` y escribe `pdfs/matricula/2026-2/EFEs/efe_ssu_2026-2_v1.json`.

Para un ciclo distinto, edita las constantes `DEFAULT_CYCLE` y `DEFAULT_EFE_DIR` al inicio de `efe_ssu.py`, o pasa argumentos `--pdf`, `--xlsx`, `--output`.

### Paso 2 — Convertir al formato de la app
```bash
python scripts/extractors/efe_to_courses.py
```

Genera `input/efe_courses_2026-2_v1.json`.

### Paso 3 — Verificar (opcional)
```bash
python scripts/verify_efe.py
```

### Copiar al proyecto Flutter
```bash
cp input/efe_courses_2026-2_v1.json matriculaup_app/assets/efe_courses_2026-2_v1.json
```

---

## 3. Registrar el nuevo EFE en la app

Si el **nombre del archivo EFE cambió** (nuevo ciclo o versión), hay que actualizar dos lugares:

### `matriculaup_app/pubspec.yaml`
```yaml
assets:
  - assets/default_courses.json
  - assets/efe_courses_2026-2_v1.json   # ← cambiar aquí
```

### `matriculaup_app/lib/data/data_loader.dart` — línea ~57
```dart
final contents = await rootBundle.loadString(
  'assets/efe_courses_2026-2_v1.json',  // ← cambiar aquí
);
```

Para cursos regulares **no hay nada que cambiar en el código**.

---

## 4. Publicar

```bash
git add matriculaup_app/assets/ matriculaup_app/pubspec.yaml \
        matriculaup_app/lib/data/data_loader.dart
git commit -m "data: actualizar cursos CICLO vX"
git push origin main
```

GitHub Actions compila y despliega automáticamente en GitHub Pages.

---

## Estructura de carpetas de referencia

```
pdfs/
  matricula/
    2026-2/
      regular/        ← PDFs de oferta académica regular
      EFEs/           ← PDF de EFEs + Excel SSU

input/               ← JSONs generados por los scripts (no se commitean)

matriculaup_app/
  assets/
    default_courses.json        ← cursos regulares activos
    efe_courses_2026-2_v1.json  ← EFEs activos
```

---

## Preguntas / problemas

Abre un issue en [github.com/johnbarraza/MatriculaUp](https://github.com/johnbarraza/MatriculaUp) o contacta al autor.
