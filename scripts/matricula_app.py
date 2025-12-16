import gradio as gr
import pandas as pd
import json
import os
import unicodedata
from datetime import datetime, timedelta
from typing import Dict, List, Set, Tuple, Optional
import io
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from PIL import Image
WORKSPACE_ROOT = os.path.dirname(os.path.dirname(__file__))


# Mapeo de carreras a sus archivos JSON de cursos obligatorios
CAREER_CURRICULUM_MAP = {
    "Economía": "economia2017.json",
    "Finanzas": "finanzas2018.json",
}


def parse_credits(value) -> float:
    """Convierte un valor a float, manejando formatos variados."""
    s = str(value).strip().replace(',', '.')
    try:
        return float(s)
    except:
        return 0.0


def normalize_str(s: str) -> str:
    """Normaliza string removiendo acentos y pasando a minúsculas."""
    return ''.join(
        c for c in unicodedata.normalize('NFD', str(s).lower())
        if unicodedata.category(c) != 'Mn'
    )


def match_keywords(text: str, keywords: List[str]) -> bool:
    """Verifica si todos los keywords están en el texto normalizado."""
    text_norm = normalize_str(text)
    return all(kw in text_norm for kw in keywords)


class CurriculumData:
    """Gestiona los datos de currículo de una carrera."""

    def __init__(self, json_path: str):
        self.courses = []
        self.title = ""
        self.faculty = ""
        self.cycles = []
        self.load_from_json(json_path)

    def load_from_json(self, json_path: str) -> bool:
        """Carga datos de currículo desde JSON."""
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            self.title = data.get('title', '')
            self.faculty = data.get('faculty', '')
            self.cycles = data.get('cycles', [])
            self.courses = data.get('courses', [])
            return True
        except Exception as e:
            print(f"Error cargando {json_path}: {e}")
            return False

    def get_course_names(self) -> List[str]:
        """Retorna lista de nombres de cursos normalizados."""
        return [normalize_str(c.get('name', '')) for c in self.courses]

    def get_courses_by_cycle(self, cycle: str) -> List[dict]:
        """Retorna cursos de un ciclo específico."""
        return [c for c in self.courses if c.get('cycle_recommended') == cycle]

    def get_course_info(self, course_name_normalized: str) -> Optional[dict]:
        """Busca información de un curso por nombre normalizado."""
        for course in self.courses:
            if normalize_str(course.get('name', '')) == course_name_normalized:
                return course
        return None


class MatriculaApp:
    """Lógica principal de la aplicación de matrícula."""

    def __init__(self):
        self.courses_df: Optional[pd.DataFrame] = None
        self.schedules: Dict[int, List[dict]] = {1: [], 2: [], 3: []}
        self.credits: Dict[int, float] = {1: 0.0, 2: 0.0, 3: 0.0}
        self.taken_courses: Set[str] = set()
        self.current_career: Optional[str] = None
        self.curriculum: Optional[CurriculumData] = None

        # Conjuntos de tipos de sesión
        self.CLASES_SET = {"CLASE", "PRÁCTICA", "PRÁCTICAS", "PRACDIRIGI"}
        self.EXAMENES_SET = {"FINAL", "PARCIAL"}

        # Conjuntos normalizados (sin acentos/espacios, en mayúsculas) para comparaciones robustas
        self._CLASES_NORM = {normalize_str(x).upper() for x in self.CLASES_SET}
        self._EXAMENES_NORM = {normalize_str(x).upper() for x in self.EXAMENES_SET}

        # Cache para imágenes de horarios (evita regenerar si no hay cambios)
        self._schedule_image_cache: Dict[int, Tuple[Optional[Image.Image], Optional[Image.Image], str]] = {}
        # Cache de búsquedas de cursos
        self._course_search_cache: Dict[str, List[str]] = {}
        # Cache de secciones por curso
        self._sections_cache: Dict[str, List[str]] = {}

    def set_career(self, career: str) -> Tuple[str, List[str], List[str]]:
        """Establece la carrera actual y carga su currículo."""
        self.current_career = career

        if career not in CAREER_CURRICULUM_MAP:
            return f"Carrera '{career}' no tiene currículo definido", [], []

        json_filename = CAREER_CURRICULUM_MAP[career]
        json_path = os.path.join(WORKSPACE_ROOT, 'input', json_filename)

        if not os.path.exists(json_path):
            return f"No se encontró el archivo: {json_filename}", [], []

        self.curriculum = CurriculumData(json_path)
        mandatory_courses = self.curriculum.get_course_names()
        cycles = self.curriculum.cycles

        return f"✓ Carrera cargada: {career} ({len(mandatory_courses)} cursos obligatorios)", mandatory_courses, cycles

    def get_courses_by_cycle(self, cycle: str) -> List[str]:
        """Retorna nombres normalizados de cursos de un ciclo."""
        if not self.curriculum:
            return []

        courses = self.curriculum.get_courses_by_cycle(cycle)
        return [normalize_str(c.get('name', '')) for c in courses]

    def load_excel(self, file_obj=None) -> str:
        """
        Carga archivo Excel o CSV con datos de horarios.
        CSV es ~10x más rápido que Excel para archivos grandes.
        """
        try:
            # Limpiar caché al cargar nuevos datos
            self._invalidate_all_caches()

            def _try_read_csv(source):
                """Try several pandas CSV parsing modes to handle inconsistent separators/quotes."""
                # Try C engine (fast); then fall back to python engine with common separators
                attempts = [
                    {'engine': 'c', 'encoding': 'utf-8'},
                    {'engine': 'python', 'encoding': 'utf-8', 'sep': ';'},
                    {'engine': 'python', 'encoding': 'utf-8', 'sep': ','},
                    {'engine': 'python', 'encoding': 'utf-8', 'sep': None},
                ]
                for kw in attempts:
                    try:
                        # The 'low_memory' option is only supported by the C engine
                        if kw.get('engine') == 'c':
                            return pd.read_csv(source, low_memory=False, **kw)
                        else:
                            return pd.read_csv(source, **kw)
                    except Exception:
                        continue
                # Last resort: try with universal newlines and no quoting
                try:
                    return pd.read_csv(source, engine='python', quoting=3, low_memory=False)
                except Exception as e:
                    raise e

            if file_obj is None:
                # Intentar cargar CSV primero (más rápido), luego Excel
                csv_path = os.path.join(WORKSPACE_ROOT, "output", "Horarios_UP_V6_Perfecto.csv")
                xlsx_path = os.path.join(WORKSPACE_ROOT, "output", "Horarios_UP_V6_Perfecto.xlsx")

                if os.path.exists(csv_path):
                    try:
                        df = _try_read_csv(csv_path)
                    except Exception as e:
                        return f"✗ Error al cargar CSV: {e}"
                    file_type = "CSV"
                elif os.path.exists(xlsx_path):
                    df = pd.read_excel(xlsx_path, engine='openpyxl')
                    file_type = "Excel"
                else:
                    return "⚠ No se encontró archivo de horarios (CSV o Excel)"
            else:
                # Detectar tipo de archivo subido
                filename = file_obj.name if hasattr(file_obj, 'name') else str(file_obj)

                if filename.lower().endswith('.csv'):
                    try:
                        if hasattr(file_obj, 'name') and os.path.exists(file_obj.name):
                            df = _try_read_csv(file_obj.name)
                        else:
                            df = _try_read_csv(file_obj)
                    except Exception as e:
                        return f"✗ Error al cargar CSV subido: {e}"
                    file_type = "CSV"
                else:
                    if hasattr(file_obj, 'name') and os.path.exists(file_obj.name):
                        df = pd.read_excel(file_obj.name, engine='openpyxl')
                    else:
                        df = pd.read_excel(file_obj, engine='openpyxl')
                    file_type = "Excel"

            # Normalizar nombres de columnas
            df = self._normalize_columns(df)
            self.courses_df = df

            return f"✓ Datos cargados ({file_type}): {len(df)} registros"
        except Exception as e:
            return f"✗ Error al cargar: {e}"

    def _invalidate_all_caches(self):
        """Limpia todos los cachés."""
        self._schedule_image_cache.clear()
        self._course_search_cache.clear()
        self._sections_cache.clear()

    def _invalidate_schedule_cache(self, schedule_index: int):
        """Invalida el caché de imágenes para un horario específico."""
        if schedule_index in self._schedule_image_cache:
            del self._schedule_image_cache[schedule_index]

    def _normalize_columns(self, df: pd.DataFrame) -> pd.DataFrame:
        """Normaliza nombres de columnas del DataFrame."""
        df_cols = {normalize_str(c): c for c in df.columns}
        col_map = {}

        mapping = {
            'curso': 'Curso', 'nombre': 'Curso', 'course': 'Curso',
            'secc': 'Secc', 'seccion': 'Secc', 'sección': 'Secc',
            'docente': 'Docentes', 'docentes': 'Docentes', 'profesor': 'Docentes',
            'cred': 'Cred', 'creditos': 'Cred', 'créditos': 'Cred',
            'dia': 'Día', 'día': 'Día',
            'inicio': 'Horario_Inicio', 'horario_inicio': 'Horario_Inicio',
            'fin': 'Horario_Cierre', 'cierre': 'Horario_Cierre', 'horario_cierre': 'Horario_Cierre',
            'tipo': 'Tipo'
        }

        for low, orig in df_cols.items():
            if low in mapping:
                col_map[orig] = mapping[low]

        if col_map:
            df = df.rename(columns=col_map)

        # Asegurar que existan las columnas esperadas
        expected_cols = ['Curso', 'Secc', 'Docentes', 'Cred', 'Día', 'Horario_Inicio', 'Horario_Cierre', 'Tipo']
        for col in expected_cols:
            if col not in df.columns:
                df[col] = ''

        return df

    def get_mandatory_courses_status(self) -> Tuple[List[str], List[str], List[str]]:
        """
        Retorna el estado de cursos obligatorios.
        Returns: (todos, llevados, faltantes)
        """
        if not self.curriculum:
            return [], [], []

        all_mandatory = self.curriculum.get_course_names()
        taken = [c for c in all_mandatory if c in self.taken_courses]
        pending = [c for c in all_mandatory if c not in self.taken_courses]

        return all_mandatory, taken, pending

    def update_taken_courses(self, selected_courses: List[str]):
        """Actualiza el set de cursos llevados."""
        self.taken_courses = set(selected_courses)

    def list_courses(self, search_term: str = "", filter_mandatory_only: bool = False,
                     filter_pending_only: bool = False) -> List[str]:
        """
        Lista cursos disponibles con filtros opcionales (con caché).

        Args:
            search_term: Término de búsqueda
            filter_mandatory_only: Solo cursos obligatorios
            filter_pending_only: Solo cursos obligatorios pendientes
        """
        if self.courses_df is None:
            return []

        # Crear clave de caché
        cache_key = f"{search_term}|{filter_mandatory_only}|{filter_pending_only}|{len(self.taken_courses)}"

        # Verificar si está en caché
        if cache_key in self._course_search_cache:
            return self._course_search_cache[cache_key]

        df = self.courses_df
        names = sorted(df['Curso'].dropna().unique().tolist())

        # Aplicar filtro de búsqueda
        if search_term:
            kws = [w for w in normalize_str(search_term).split() if w]
            names = [n for n in names if all(kw in normalize_str(n) for kw in kws)]

        # Aplicar filtros de cursos obligatorios
        if filter_mandatory_only or filter_pending_only:
            if not self.curriculum:
                return []

            mandatory_normalized = set(self.curriculum.get_course_names())

            if filter_pending_only:
                # Solo cursos obligatorios que NO han sido llevados
                pending = mandatory_normalized - self.taken_courses
                names = [n for n in names if normalize_str(n) in pending]
            elif filter_mandatory_only:
                # Solo cursos obligatorios (llevados o no)
                names = [n for n in names if normalize_str(n) in mandatory_normalized]

        # Guardar en caché
        self._course_search_cache[cache_key] = names

        return names

    def get_sections_for_course(self, course_name: str) -> List[str]:
        """Retorna lista de secciones disponibles para un curso (con caché)."""
        if self.courses_df is None:
            return []
        # Verificar caché
        if course_name in self._sections_cache:
            return self._sections_cache[course_name]

        df = self.courses_df
        rows = df[df['Curso'] == course_name]

        # Agrupar por Secc + Docentes + Cred para evitar duplicados por día
        # (NO agrupar por 'Tipo' para no listar CLASE/PARCIAL/FINAL por separado)
        grouped = rows.groupby(['Secc', 'Docentes', 'Cred'], dropna=False)
        opts = []

        for (secc, prof, cred), g in grouped:
            display = f"Secc {secc} — {prof} ({cred} cr)"
            label = f"{course_name}__{secc}|{display}"
            opts.append(label)

        # Dedupe preserving order (some files may have near-duplicate rows causing repeated labels)
        seen = set()
        unique_opts = []
        for o in opts:
            if o not in seen:
                seen.add(o)
                unique_opts.append(o)

        opts = unique_opts

        # Guardar en caché
        self._sections_cache[course_name] = opts

        return opts

    def get_days_for_section(self, section_label: str) -> List[str]:
        """Dado un label de sección (Course__Secc|...), retorna los días/horarios asociados."""
        if self.courses_df is None or not section_label:
            return []

        # Extraer curso y secc
        if '__' in section_label:
            curso, rest = section_label.split('__', 1)
            secc = rest.split('|', 1)[0]
        else:
            return []

        df = self.courses_df
        rows = df[(df['Curso'] == curso) & (df['Secc'] == secc)]
        infos = []
        for idx, r in rows.iterrows():
            dia = r.get('Día', '')
            ini = r.get('Horario_Inicio', '')
            fin = r.get('Horario_Cierre', '')
            tipo = r.get('Tipo', '')
            if not dia and not ini and not fin:
                continue
            infos.append(f"{dia} {ini}-{fin} ({tipo})")

        # dedupe preserving order
        seen = set()
        unique = []
        for i in infos:
            if i not in seen:
                seen.add(i)
                unique.append(i)

        return unique

    def add_to_schedule(self, course_labels: List[str], schedule_index: int,
                       force_replace: bool = False) -> str:
        """Añade cursos al horario especificado."""
        if not course_labels:
            return "⚠ Selecciona al menos un curso"

        if self.courses_df is None:
            return "⚠ Carga primero los datos"

        # Construir lista de nuevos bloques a añadir (cada bloque puede tener múltiples 'slots')
        new_rows = []
        for label in course_labels:
            # Parsear el formato: "Curso__Secc|Display text"
            if '__' in label:
                parts = label.split('__', 1)
                curso = parts[0]
                if '|' in parts[1]:
                    secc = parts[1].split('|')[0]
                else:
                    secc = parts[1].split(' ')[0]
            else:
                curso = label
                secc = ''
            block_id = f"{curso}__{secc}"

            # Saltar duplicados exactos
            if any(b['block'] == block_id for b in self.schedules[schedule_index]):
                continue

            rows = self.courses_df[(self.courses_df['Curso'] == curso) & (self.courses_df['Secc'] == secc)]
            if rows.empty:
                rows = self.courses_df[self.courses_df['Curso'].str.contains(curso, na=False)]

            if not rows.empty:
                # Collect all slots (days/times) for this section
                slots = []
                for _, rr in rows.iterrows():
                    dia = rr.get('Día', '')
                    ini = rr.get('Horario_Inicio', '')
                    fin = rr.get('Horario_Cierre', '')
                    tipo = rr.get('Tipo', '')
                    if not dia and not ini and not fin:
                        continue
                    slots.append({'dia': dia, 'inicio': ini, 'fin': fin, 'tipo': tipo})

                first = rows.iloc[0]
                cred_val = parse_credits(first.get('Cred', 0))

                new_rows.append({
                    'block': block_id,
                    'curso': curso,
                    'secc': secc,
                    'prof': first.get('Docentes', ''),
                    'tipo': first.get('Tipo', ''),
                    'slots': slots,
                    'cred': cred_val
                })

        # Detectar conflictos
        conflicts = self._detect_conflicts_with_new(schedule_index, new_rows)

        if conflicts and not force_replace:
            msg_lines = ["⚠ Conflictos detectados:"]
            for nr, eb in conflicts:
                msg_lines.append(
                    f"  • Nuevo: {nr['block']} ({nr['dia']} {nr['inicio']}-{nr['fin']}) "
                    f"choca con {eb['block']} ({eb['dia']} {eb['inicio']}-{eb['fin']})"
                )
            msg_lines.append("\n✓ Marca 'Reemplazar conflictos' para forzar la inserción.")
            return "\n".join(msg_lines)

        # Si hay conflictos y force_replace=True, remover bloques conflictivos
        if conflicts and force_replace:
            self._remove_conflicting_blocks(schedule_index, conflicts)

        # Verificar límite de créditos
        sum_new_cred = sum(n.get('cred', 0.0) for n in new_rows)
        current_cred = self.credits.get(schedule_index, 0.0)

        if current_cred + sum_new_cred > 25.0:
            return f"⚠ Excede límite de 25 créditos (actual: {current_cred:.1f}, nuevos: {sum_new_cred:.1f})"

        # Insertar nuevas filas
        for nr in new_rows:
            # avoid duplicates: if a block with same id already exists, skip
            if any(b.get('block') == nr['block'] for b in self.schedules[schedule_index]):
                continue
            self.schedules[schedule_index].append(nr)
            # add credits once per section
            self.credits[schedule_index] += nr.get('cred', 0.0)

        # Invalidar caché de imágenes para este horario
        self._invalidate_schedule_cache(schedule_index)

        return f"✓ {len(new_rows)} curso(s) añadido(s)"

    def _detect_conflicts_with_new(self, schedule_index: int,
                                   new_rows: List[dict]) -> List[Tuple[dict, dict]]:
        """Detecta conflictos entre nuevos cursos y cursos existentes."""
        conflicts = []
        existing = self.schedules[schedule_index]
        # Normalize existing entries into slot lists
        def entry_slots(e):
            if 'slots' in e and isinstance(e['slots'], list):
                return e['slots']
            # legacy single-slot entries
            return [{'dia': e.get('dia'), 'inicio': e.get('inicio'), 'fin': e.get('fin'), 'tipo': e.get('tipo')}]

        for nr in new_rows:
            nr_slots = entry_slots(nr)
            for nslot in nr_slots:
                inicio_n = nslot.get('inicio')
                fin_n = nslot.get('fin')
                if not inicio_n or not fin_n:
                    continue
                try:
                    start_n = datetime.strptime(str(inicio_n), '%H:%M')
                    end_n = datetime.strptime(str(fin_n), '%H:%M')
                except:
                    continue
                tipo_n = normalize_str(nslot.get('tipo') or '').upper().strip()
                for eb in existing:
                    for eslot in entry_slots(eb):
                        tipo_e = normalize_str(eslot.get('tipo') or '').upper().strip()
                        # Solo comparar si son del mismo grupo (clases vs clases, exámenes vs exámenes)
                        same_group = (
                            (tipo_n in self._CLASES_NORM and tipo_e in self._CLASES_NORM) or
                            (tipo_n in self._EXAMENES_NORM and tipo_e in self._EXAMENES_NORM)
                        )
                        if not same_group:
                            continue
                        # Verificar mismo día
                        if str(nslot.get('dia')).upper().strip() != str(eslot.get('dia')).upper().strip():
                            continue
                        inicio_e = eslot.get('inicio')
                        fin_e = eslot.get('fin')
                        if not inicio_e or not fin_e:
                            continue
                        try:
                            s_e = datetime.strptime(str(inicio_e), '%H:%M')
                            e_e = datetime.strptime(str(fin_e), '%H:%M')
                        except:
                            continue
                        if start_n < e_e and end_n > s_e:
                            conflicts.append((nr, eb))

        return conflicts

    def _remove_conflicting_blocks(self, schedule_index: int,
                                   conflicts: List[Tuple[dict, dict]]):
        """Remueve bloques conflictivos del horario."""
        to_remove = set()
        for nr, eb in conflicts:
            to_remove.add(eb['block'])

        new_existing = []
        removed_cred = 0.0

        for eb in self.schedules[schedule_index]:
            if eb['block'] in to_remove:
                removed_cred += eb.get('cred', 0.0)
            else:
                new_existing.append(eb)

        self.schedules[schedule_index] = new_existing
        self.credits[schedule_index] = max(0.0, self.credits[schedule_index] - removed_cred)

    def detect_conflicts(self, schedule_index: int) -> Tuple[List, str]:
        """Detecta conflictos dentro de un horario."""
        rows = self.schedules.get(schedule_index, [])
        conflicts = []

        def entry_slots(e):
            if 'slots' in e and isinstance(e['slots'], list):
                return e['slots']
            if e.get('inicio') and e.get('fin'):
                return [{'dia': e.get('dia'), 'inicio': e.get('inicio'), 'fin': e.get('fin'), 'tipo': e.get('tipo')}]
            return []

        for i in range(len(rows)):
            for j in range(i+1, len(rows)):
                a, b = rows[i], rows[j]

                # comparar todas las combinaciones de slots entre ambos bloques
                for sa in entry_slots(a):
                    for sb in entry_slots(b):
                        dia_a = str(sa.get('dia') or '').upper().strip()
                        dia_b = str(sb.get('dia') or '').upper().strip()
                        if dia_a != dia_b or not dia_a:
                            continue

                        tipo_a = normalize_str(sa.get('tipo') or '').upper().strip()
                        tipo_b = normalize_str(sb.get('tipo') or '').upper().strip()

                        # Solo comparar si son del mismo grupo
                        same_group = (
                            (tipo_a in self._CLASES_NORM and tipo_b in self._CLASES_NORM) or
                            (tipo_a in self._EXAMENES_NORM and tipo_b in self._EXAMENES_NORM)
                        )
                        if not same_group:
                            continue

                        inicio_a = sa.get('inicio')
                        fin_a = sa.get('fin')
                        inicio_b = sb.get('inicio')
                        fin_b = sb.get('fin')

                        if not all([inicio_a, fin_a, inicio_b, fin_b]):
                            continue

                        try:
                            ta_s = datetime.strptime(str(inicio_a), '%H:%M')
                            ta_e = datetime.strptime(str(fin_a), '%H:%M')
                            tb_s = datetime.strptime(str(inicio_b), '%H:%M')
                            tb_e = datetime.strptime(str(fin_b), '%H:%M')
                        except:
                            continue

                        if ta_s < tb_e and ta_e > tb_s:
                            conflicts.append((a['block'], b['block'], dia_a, inicio_a, fin_a, inicio_b, fin_b))

        if not conflicts:
            return [], ""

        msg_lines = ["⚠ Conflictos en horario:"]
        for c in conflicts:
            msg_lines.append(
                f"  • {c[0]} ({c[2]} {c[3]}-{c[4]}) choca con {c[1]} ({c[2]} {c[5]}-{c[6]})"
            )

        return conflicts, "\n".join(msg_lines)

    def get_schedule_table(self, schedule_index: int) -> pd.DataFrame:
        """Retorna tabla del horario especificado."""
        rows = self.schedules.get(schedule_index, [])

        if not rows:
            return pd.DataFrame(columns=['Curso', 'Secc', 'Profesor', 'Tipo', 'Día', 'Inicio', 'Fin', 'Cred'])

        # Expand blocks with multiple slots into display rows, but show credits once per block
        display_rows = []
        for r in rows:
            cred = r.get('cred', 0.0)
            if 'slots' in r and isinstance(r['slots'], list) and r['slots']:
                slots = r['slots']
                days_display = []
                for s in slots:
                    days_display.append(f"{s.get('dia','')} {s.get('inicio','')}-{s.get('fin','')}")
                display_rows.append({
                    'Curso': r.get('curso',''),
                    'Secc': r.get('secc',''),
                    'Profesor': r.get('prof',''),
                    'Tipo': r.get('tipo',''),
                    'Día': "; ".join(days_display),
                    'Inicio': '',
                    'Fin': '',
                    'Cred': cred
                })
            else:
                display_rows.append({
                    'Curso': r.get('curso',''),
                    'Secc': r.get('secc',''),
                    'Profesor': r.get('prof',''),
                    'Tipo': r.get('tipo',''),
                    'Día': r.get('dia',''),
                    'Inicio': r.get('inicio',''),
                    'Fin': r.get('fin',''),
                    'Cred': cred
                })

        df = pd.DataFrame(display_rows)

        return df

    def remove_from_schedule(self, block_id: str, schedule_index: int) -> pd.DataFrame:
        """Remueve un curso del horario especificado."""
        newlist = []
        removed_cred = 0.0

        for b in self.schedules[schedule_index]:
            if b['block'] == block_id:
                removed_cred += b.get('cred', 0.0)
            else:
                newlist.append(b)

        self.schedules[schedule_index] = newlist
        self.credits[schedule_index] = max(0.0, self.credits[schedule_index] - removed_cred)

        # Invalidar caché de imágenes
        self._invalidate_schedule_cache(schedule_index)

        return self.get_schedule_table(schedule_index)

    def draw_week_schedule(self, schedule_index: int, save_path: Optional[str] = None) -> Tuple[Image.Image, Image.Image]:
        """
        Dibuja horario semanal mejorado (7:30 AM - 11:00 PM) con caché.
        Solo regenera si el horario cambió desde la última vez.
        """
        rows = self.schedules.get(schedule_index, [])

        # Generar hash del contenido del horario para verificar cambios
        def _row_hash(r: dict) -> str:
            # Si el bloque tiene 'slots' (sección con varios días), usar cada slot
            if 'slots' in r and isinstance(r['slots'], list):
                slots_str = '|'.join([f"{s.get('dia','')}_{s.get('inicio','')}_{s.get('fin','')}" for s in r['slots']])
                return f"{r.get('block','')}_{slots_str}"
            # Fallback legacy fields
            return f"{r.get('block','')}_{r.get('dia','')}_{r.get('inicio','')}_{r.get('fin','')}"

        schedule_hash = str(sorted([_row_hash(r) for r in rows]))

        # Verificar si tenemos caché válido
        if schedule_index in self._schedule_image_cache:
            cached_classes, cached_exams, cached_hash = self._schedule_image_cache[schedule_index]
            if cached_hash == schedule_hash and cached_classes and cached_exams:
                # Cache hit! No necesitamos regenerar
                return cached_classes, cached_exams

        # Cache miss o cambió el horario - generar nuevas imágenes
        days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO']
        day_map = {d: i for i, d in enumerate(days)}

        base_time = datetime.strptime('07:30', '%H:%M')
        end_time = datetime.strptime('23:00', '%H:%M')  # 11:00 PM
        total_minutes = int((end_time - base_time).seconds / 60)
        total_blocks = total_minutes // 30  # bloques de 30 min

        def make_fig(filter_types: str) -> Image.Image:
            """Crea figura mejorada para un tipo de sesión (CLASE o EXAM)."""
            # Configuración de estilo
            plt.style.use('default')
            fig_height = max(10, total_blocks * 0.15)
            fig, ax = plt.subplots(figsize=(16, fig_height), facecolor='white')

            cell_h = 0.35
            full_h = total_blocks * cell_h
            cell_w = 1.5

            # Colores mejorados
            bg_color = '#f8f9fa'
            grid_color = '#dee2e6'
            header_bg = '#4a5568'
            text_color = '#2d3748'

            # Fondo
            ax.add_patch(patches.Rectangle(
                (0, 0), len(days) * cell_w, full_h,
                facecolor=bg_color, zorder=0
            ))

            # Dibujar grid de días con headers mejorados
            for i, d in enumerate(days):
                x = i * cell_w
                # Columna del día
                ax.add_patch(patches.Rectangle(
                    (x, 0), cell_w, full_h,
                    fill=False, edgecolor=grid_color, linewidth=1, zorder=1
                ))
                # Header del día
                ax.add_patch(patches.Rectangle(
                    (x, full_h), cell_w, 0.6,
                    facecolor=header_bg, edgecolor='none', zorder=2
                ))
                ax.text(
                    x + cell_w/2, full_h + 0.3, d,
                    ha='center', va='center', fontsize=11,
                    fontweight='bold', color='white', zorder=3
                )

            # Dibujar líneas horizontales y etiquetas de tiempo mejoradas
            for b in range(total_blocks + 1):
                y = b * cell_h
                # Línea más gruesa cada hora
                if b % 2 == 0:
                    ax.hlines(y, 0, len(days) * cell_w, colors=grid_color, linewidth=1.5, zorder=1)
                    # Etiqueta de hora
                    t = (base_time + timedelta(minutes=b * 30)).strftime('%I:%M %p')
                    ax.text(
                        -0.15, y, t,
                        ha='right', va='center', fontsize=9,
                        color=text_color, fontweight='600'
                    )
                else:
                    ax.hlines(y, 0, len(days) * cell_w, colors=grid_color, linewidth=0.5, alpha=0.5, zorder=1)
            # Dibujar bloques de cursos con soporte para múltiples slots por bloque
            for r in rows:
                # Determine slots for this block (new format) or fallback to single slot
                if 'slots' in r and isinstance(r['slots'], list) and r['slots']:
                    r_slots = r['slots']
                else:
                    r_slots = [{'dia': r.get('dia', ''), 'inicio': r.get('inicio', ''), 'fin': r.get('fin', ''), 'tipo': r.get('tipo', '')}]

                # For color/overlap determination we can check if any slot overlaps
                overlap = self._check_overlap_in_schedule(r, rows, filter_types)

                # Determine colors based on filter_types and overlap
                if filter_types == 'CLASE':
                    face_color_ok = '#4dabf7'
                    face_color_conf = '#ff6b6b'
                    edge_ok = '#1971c2'
                    edge_conf = '#c92a2a'
                else:
                    face_color_ok = '#ffd43b'
                    face_color_conf = '#ff8787'
                    edge_ok = '#f59f00'
                    edge_conf = '#c92a2a'

                for slot in r_slots:
                    tipo = normalize_str(slot.get('tipo') or '').upper()
                    # Filtrar por tipo (usar conjuntos normalizados)
                    if filter_types == 'CLASE' and tipo not in self._CLASES_NORM:
                        continue
                    if filter_types == 'EXAM' and tipo not in self._EXAMENES_NORM:
                        continue

                    dia = str(slot.get('dia') or '').upper()
                    # Mapear día a índice
                    d_index = None
                    for k, v in day_map.items():
                        if dia.startswith(k[:3]):
                            d_index = v
                            break
                    if d_index is None:
                        continue

                    inicio = slot.get('inicio')
                    fin = slot.get('fin')
                    if not inicio or not fin:
                        continue
                    try:
                        st = datetime.strptime(str(inicio), '%H:%M')
                        en = datetime.strptime(str(fin), '%H:%M')
                    except:
                        continue

                    start_minutes = (st - base_time).seconds / 60
                    end_minutes = (en - base_time).seconds / 60
                    if start_minutes < 0 or end_minutes > total_minutes:
                        continue

                    start_blocks = start_minutes / 30
                    end_blocks = end_minutes / 30
                    y1 = start_blocks * cell_h
                    y2 = end_blocks * cell_h

                    # choose colors depending on whether this block has overlap
                    face_color = face_color_conf if overlap else face_color_ok
                    edge_color = edge_conf if overlap else edge_ok
                    lw = 2.5 if overlap else 2

                    x_pos = d_index * cell_w
                    rect = patches.Rectangle(
                        (x_pos + 0.05, y1), cell_w - 0.1, y2 - y1,
                        facecolor=face_color, edgecolor=edge_color,
                        linewidth=lw, alpha=0.9, zorder=3
                    )
                    ax.add_patch(rect)

                    # Texto del curso con mejor formato
                    curso_text = r.get('curso', '')
                    secc_text = r.get('secc', '')
                    height = y2 - y1

                    # Ajustar tamaño de fuente según altura
                    if height > 1.5:
                        fontsize = 9
                        ax.text(
                            x_pos + cell_w/2, y1 + height/2 + 0.15,
                            curso_text,
                            ha='center', va='center', fontsize=fontsize,
                            fontweight='bold', color='white', zorder=4,
                            wrap=True
                        )
                        ax.text(
                            x_pos + cell_w/2, y1 + height/2 - 0.15,
                            f"Secc. {secc_text}",
                            ha='center', va='center', fontsize=fontsize-1,
                            color='white', alpha=0.9, zorder=4
                        )
                    elif height > 0.7:
                        fontsize = 8
                        ax.text(
                            x_pos + cell_w/2, y1 + height/2,
                            curso_text,
                            ha='center', va='center', fontsize=fontsize,
                            fontweight='bold', color='white', zorder=4,
                            wrap=True
                        )
                    else:
                        fontsize = 7
                        short_name = curso_text[:15] + '...' if len(curso_text) > 15 else curso_text
                        ax.text(
                            x_pos + cell_w/2, y1 + height/2,
                            short_name,
                            ha='center', va='center', fontsize=fontsize,
                            color='white', zorder=4
                        )

            # Configuración de ejes
            ax.set_xlim(-0.3, len(days) * cell_w + 0.1)
            ax.set_ylim(-0.1, full_h + 0.7)
            # Invertir el eje Y para que las horas tempranas aparezcan arriba
            ax.invert_yaxis()
            ax.set_xticks([])
            ax.set_yticks([])
            ax.spines['top'].set_visible(False)
            ax.spines['right'].set_visible(False)
            ax.spines['bottom'].set_visible(False)
            ax.spines['left'].set_visible(False)

            # Título
            title_text = "Clases y Prácticas" if filter_types == 'CLASE' else "Exámenes"
            ax.text(
                len(days) * cell_w / 2, full_h + 0.9,
                title_text,
                ha='center', va='center', fontsize=14,
                fontweight='bold', color=text_color
            )

            buf = io.BytesIO()
            fig.tight_layout(pad=0.5)
            fig.savefig(buf, format='png', dpi=150, bbox_inches='tight', facecolor='white')
            plt.close(fig)
            buf.seek(0)

            img = Image.open(buf).convert('RGB')

            # Guardar si se especifica path
            if save_path:
                filename = f"{save_path}_{filter_types.lower()}.png"
                img.save(filename, 'PNG', quality=95)

            return img

        classes_img = make_fig('CLASE')
        exams_img = make_fig('EXAM')

        # Guardar en caché
        self._schedule_image_cache[schedule_index] = (classes_img, exams_img, schedule_hash)

        return classes_img, exams_img

    def _check_overlap_in_schedule(self, current: dict, all_rows: List[dict],
                                   filter_types: str) -> bool:
        """Verifica si un bloque se solapa con otros del mismo tipo."""
        # Normalize helper to return list of slots for an entry
        def slots_of(e):
            if 'slots' in e and isinstance(e['slots'], list):
                return e['slots']
            if e.get('inicio') and e.get('fin'):
                return [{'dia': e.get('dia'), 'inicio': e.get('inicio'), 'fin': e.get('fin'), 'tipo': e.get('tipo')}]
            return []

        current_slots = slots_of(current)
        if not current_slots:
            return False

        for cslot in current_slots:
            try:
                st = datetime.strptime(str(cslot.get('inicio')), '%H:%M')
                en = datetime.strptime(str(cslot.get('fin')), '%H:%M')
            except:
                continue
            dia = str(cslot.get('dia')).upper().strip()
            tipo = (cslot.get('tipo') or '').upper()

            for other in all_rows:
                if other is current:
                    continue
                for oslot in slots_of(other):
                    if str(oslot.get('dia')).upper().strip() != dia:
                        continue
                    tipo = normalize_str(oslot.get('tipo') or '').upper()
                    # Verificar mismo grupo
                    if filter_types == 'CLASE':
                        if tipo not in self._CLASES_NORM or normalize_str(otipo).upper() not in self._CLASES_NORM:
                            continue
                    elif filter_types == 'EXAM':
                        if tipo not in self._EXAMENES_NORM or normalize_str(otipo).upper() not in self._EXAMENES_NORM:
                            continue
                    try:
                        ost = datetime.strptime(str(oslot.get('inicio')), '%H:%M')
                        oen = datetime.strptime(str(oslot.get('fin')), '%H:%M')
                    except:
                        continue
                    if st < oen and en > ost:
                        return True

        return False

    def save_progress(self, filename: str = "matricula_progress.json") -> str:
        """Guarda progreso actual en archivo JSON."""
        data = {
            'schedules': self.schedules,
            'credits': self.credits,
            'taken': list(self.taken_courses),
            'current_career': self.current_career
        }

        try:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            return f"✓ Guardado en {filename}"
        except Exception as e:
            return f"✗ Error al guardar: {e}"

    def load_progress(self, filename: str = "matricula_progress.json") -> str:
        """Carga progreso desde archivo JSON."""
        if not os.path.exists(filename):
            return f"⚠ No existe {filename}"

        try:
            with open(filename, 'r', encoding='utf-8') as f:
                data = json.load(f)

            self.schedules = {int(k): v for k, v in data.get('schedules', {}).items()}
            self.credits = {int(k): v for k, v in data.get('credits', {}).items()}
            self.taken_courses = set(data.get('taken', []))

            career = data.get('current_career')
            if career:
                self.set_career(career)

            return f"✓ Progreso cargado desde {filename}"
        except Exception as e:
            return f"✗ Error al cargar: {e}"

    def export_schedule(self, schedule_index: int, filename: Optional[str] = None) -> str:
        """Exporta horario a archivo Excel."""
        df = self.get_schedule_table(schedule_index)

        if filename is None:
            filename = f"schedule_{schedule_index}.xlsx"

        try:
            df.to_excel(filename, index=False)
            return f"✓ Exportado: {filename}"
        except Exception as e:
            return f"✗ Error al exportar: {e}"


# Instancia global de la aplicación
app_logic = MatriculaApp()


def build_ui():
    """Construye la interfaz de usuario con Gradio."""

    with gr.Blocks(title="MatriculaUP - Planificador de Horarios") as demo:
        gr.Markdown(
            """
            # 📚 MatriculaUP — Planificador Inteligente de Horarios
            ### Sistema de planificación con gestión de cursos obligatorios por carrera y ciclo
            """
        )

        with gr.Row():
            # ===== PANEL IZQUIERDO: Controles =====
            with gr.Column(scale=1):
                with gr.Accordion("⚙️ Configuración Inicial", open=True):
                    career = gr.Dropdown(
                        choices=list(CAREER_CURRICULUM_MAP.keys()),
                        label="🎓 Seleccionar Carrera",
                        value=None,
                        info="Elige tu carrera para cargar cursos obligatorios"
                    )
                    btn_load_career = gr.Button("Cargar Carrera", variant="primary", size="sm")
                    career_status = gr.Textbox(label="Estado", interactive=False, show_label=False)

                    upload = gr.File(
                        label="📁 Archivo de horarios (CSV recomendado - 10x más rápido)",
                        file_types=[".csv", ".xlsx", ".xls"]
                    )
                    btn_load = gr.Button("Cargar Datos de Horarios", size="sm")
                    status = gr.Textbox(label="Estado", interactive=False, show_label=False)

                with gr.Accordion("✅ Cursos Obligatorios - Marcar Llevados", open=True):
                    gr.Markdown("**Marca todos los cursos que ya has completado (sin importar el orden o ciclo)**")

                    mandatory_stats = gr.Markdown("", elem_classes="stats-box")

                    with gr.Row():
                        btn_mark_by_cycle = gr.Button("📅 Marcar por Ciclo", size="sm", scale=1)
                        btn_clear_all = gr.Button("🔄 Limpiar Todo", size="sm", scale=1, variant="stop")

                    cycle_selector = gr.Dropdown(
                        choices=[],
                        label="Seleccionar ciclo para marcar/desmarcar",
                        value=None,
                        visible=False,
                        info="Elige un ciclo para marcar todos sus cursos"
                    )

                    with gr.Row():
                        btn_select_cycle = gr.Button("✓ Marcar ciclo", size="sm", visible=False)
                        btn_deselect_cycle = gr.Button("✗ Desmarcar ciclo", size="sm", visible=False)

                    taken_multiselect = gr.CheckboxGroup(
                        choices=[],
                        label="Todos los cursos obligatorios (marca los que ya llevaste)",
                        value=[],
                        interactive=True
                    )

                with gr.Accordion("🔍 Búsqueda de Cursos", open=True):
                    search = gr.Textbox(
                        label="Buscar",
                        placeholder="Ej: Economía, García, Microeconomía...",
                        info="Busca por nombre de curso o docente"
                    )

                    with gr.Row():
                        filter_mandatory = gr.Checkbox(label="Solo obligatorios", value=False, scale=1)
                        filter_pending = gr.Checkbox(label="Solo pendientes", value=False, scale=1)

                    course_dropdown = gr.Dropdown(
                        choices=[],
                        label="📖 Cursos encontrados",
                        multiselect=False
                    )

                    section_dropdown = gr.Dropdown(
                        choices=[],
                        label="🔖 Secciones disponibles",
                        multiselect=True,
                        info="Puedes seleccionar múltiples secciones"
                    )
                    section_info = gr.Markdown("", label="Detalles de la sección", visible=True)

                with gr.Accordion("➕ Añadir al Horario", open=True):
                    add_schedule = gr.Radio(
                        label="📋 Horario destino",
                        choices=["1", "2", "3"],
                        value="1"
                    )

                    replace_conflicts = gr.Checkbox(
                        label="Reemplazar conflictos automáticamente",
                        value=False,
                        info="Elimina cursos en conflicto al añadir nuevos"
                    )

                    btn_add = gr.Button("➕ Añadir al Horario", variant="primary", size="lg")

                with gr.Accordion("💾 Guardar/Cargar Progreso", open=False):
                    with gr.Row():
                        btn_save = gr.Button("💾 Guardar", variant="secondary", scale=1)
                        btn_load_progress = gr.Button("📂 Cargar", scale=1)

                with gr.Accordion("🗑️ Eliminar Cursos", open=False):
                    remove_dd1 = gr.Dropdown(choices=[], label="Horario 1")
                    btn_remove1 = gr.Button("🗑️ Eliminar", size="sm")

                    remove_dd2 = gr.Dropdown(choices=[], label="Horario 2")
                    btn_remove2 = gr.Button("🗑️ Eliminar", size="sm")

                    remove_dd3 = gr.Dropdown(choices=[], label="Horario 3")
                    btn_remove3 = gr.Button("🗑️ Eliminar", size="sm")

            # ===== PANEL DERECHO: Visualización =====
            with gr.Column(scale=2):
                with gr.Tabs():
                    with gr.TabItem("📅 Horario 1", id="tab1"):
                        df1 = gr.Dataframe(
                            value=pd.DataFrame(),
                            label="Cursos en Horario 1",
                            interactive=False,
                            wrap=True
                        )
                        with gr.Row():
                            text1 = gr.Markdown("**Créditos:** 0.0 / 25.0")
                            btn_export1 = gr.Button("📥 Exportar Excel", size="sm")

                    with gr.TabItem("📅 Horario 2", id="tab2"):
                        df2 = gr.Dataframe(
                            value=pd.DataFrame(),
                            label="Cursos en Horario 2",
                            interactive=False,
                            wrap=True
                        )
                        with gr.Row():
                            text2 = gr.Markdown("**Créditos:** 0.0 / 25.0")
                            btn_export2 = gr.Button("📥 Exportar Excel", size="sm")

                    with gr.TabItem("📅 Horario 3", id="tab3"):
                        df3 = gr.Dataframe(
                            value=pd.DataFrame(),
                            label="Cursos en Horario 3",
                            interactive=False,
                            wrap=True
                        )
                        with gr.Row():
                            text3 = gr.Markdown("**Créditos:** 0.0 / 25.0")
                            btn_export3 = gr.Button("📥 Exportar Excel", size="sm")

                gr.Markdown("---")
                gr.Markdown("### 📊 Vista Semanal (7:30 AM - 11:00 PM)")

                current_schedule_view = gr.Radio(
                    label="Ver horario",
                    choices=["1", "2", "3"],
                    value="1",
                    info="Selecciona qué horario visualizar"
                )

                with gr.Row():
                    classes_img = gr.Image(label="🎓 Clases y Prácticas", type="pil", interactive=False)
                    exams_img = gr.Image(label="📝 Exámenes", type="pil", interactive=False)

                with gr.Row():
                    btn_save_classes_png = gr.Button("💾 Guardar Clases como PNG", size="sm")
                    btn_save_exams_png = gr.Button("💾 Guardar Exámenes como PNG", size="sm")

        # ========== CALLBACKS ==========

        def blocks_choices(idx: int) -> List[str]:
            """Helper: retorna lista de bloques para dropdown de eliminación."""
            # return unique block ids (one per section)
            blocks = [b.get('block') for b in app_logic.schedules.get(idx, [])]
            seen = set()
            out = []
            for b in blocks:
                if b not in seen:
                    seen.add(b)
                    out.append(b)
            return out

        def handle_load_career(selected_career):
            """Maneja la carga de una carrera."""
            if not selected_career:
                return "⚠ Selecciona una carrera", gr.update(), gr.update(), ""

            msg, all_courses, cycles = app_logic.set_career(selected_career)

            # Mostrar TODOS los cursos obligatorios de la carrera
            all_m, taken, pending = app_logic.get_mandatory_courses_status()
            stats_text = f"**Llevados:** {len(taken)} / {len(all_courses)} | **Pendientes:** {len(pending)}"

            return (
                msg,
                gr.update(choices=cycles, value=None),
                gr.update(choices=all_courses, value=list(app_logic.taken_courses)),
                stats_text
            )

        btn_load_career.click(
            handle_load_career,
            inputs=[career],
            outputs=[career_status, cycle_selector, taken_multiselect, mandatory_stats]
        )

        def toggle_cycle_selector():
            """Muestra/oculta el selector de ciclo."""
            return gr.update(visible=True), gr.update(visible=True), gr.update(visible=True)

        btn_mark_by_cycle.click(
            toggle_cycle_selector,
            inputs=[],
            outputs=[cycle_selector, btn_select_cycle, btn_deselect_cycle]
        )

        def clear_all_taken():
            """Limpia todos los cursos marcados."""
            app_logic.update_taken_courses([])
            all_m, taken, pending = app_logic.get_mandatory_courses_status()
            stats_text = f"**Llevados:** {len(taken)} / {len(all_m)} | **Pendientes:** {len(pending)}"
            return gr.update(value=[]), stats_text

        btn_clear_all.click(
            clear_all_taken,
            inputs=[],
            outputs=[taken_multiselect, mandatory_stats]
        )

        def select_cycle_courses(cycle):
            """Marca todos los cursos del ciclo seleccionado."""
            if not cycle or not app_logic.curriculum:
                return gr.update(), ""

            courses_in_cycle = app_logic.get_courses_by_cycle(cycle)
            # Añadir cursos del ciclo a los ya marcados
            app_logic.update_taken_courses(list(app_logic.taken_courses | set(courses_in_cycle)))

            all_m, taken, pending = app_logic.get_mandatory_courses_status()
            stats_text = f"**Llevados:** {len(taken)} / {len(all_m)} | **Pendientes:** {len(pending)}"

            return gr.update(value=list(app_logic.taken_courses)), stats_text

        def deselect_cycle_courses(cycle):
            """Desmarca todos los cursos del ciclo seleccionado."""
            if not cycle or not app_logic.curriculum:
                return gr.update(), ""

            courses_in_cycle = set(app_logic.get_courses_by_cycle(cycle))
            # Remover cursos del ciclo de los marcados
            app_logic.update_taken_courses(list(app_logic.taken_courses - courses_in_cycle))

            all_m, taken, pending = app_logic.get_mandatory_courses_status()
            stats_text = f"**Llevados:** {len(taken)} / {len(all_m)} | **Pendientes:** {len(pending)}"

            return gr.update(value=list(app_logic.taken_courses)), stats_text

        btn_select_cycle.click(
            select_cycle_courses,
            inputs=[cycle_selector],
            outputs=[taken_multiselect, mandatory_stats]
        )

        btn_deselect_cycle.click(
            deselect_cycle_courses,
            inputs=[cycle_selector],
            outputs=[taken_multiselect, mandatory_stats]
        )

        def handle_load_data(uploaded):
            """Maneja la carga de datos de horarios."""
            msg = app_logic.load_excel(uploaded)
            opts = app_logic.list_courses("")

            classes_img_b, exams_img_b = app_logic.draw_week_schedule(1)

            return (
                msg,
                gr.update(choices=opts, value=None),
                gr.update(choices=blocks_choices(1), value=None),
                gr.update(choices=blocks_choices(2), value=None),
                gr.update(choices=blocks_choices(3), value=None),
                gr.update(value=""),
                classes_img_b,
                exams_img_b
            )

        btn_load.click(
            handle_load_data,
            inputs=[upload],
            outputs=[status, course_dropdown, remove_dd1, remove_dd2, remove_dd3, section_info, classes_img, exams_img]
        )

        def update_taken_courses(selected):
            """Actualiza lista de cursos llevados."""
            app_logic.update_taken_courses(selected)

            all_m, taken, pending = app_logic.get_mandatory_courses_status()
            stats_text = f"**Total llevados:** {len(taken)} / {len(all_m)} | **Pendientes:** {len(pending)}"

            return stats_text

        taken_multiselect.change(
            update_taken_courses,
            inputs=[taken_multiselect],
            outputs=[mandatory_stats]
        )

        def search_change(t, filter_m, filter_p):
            """Maneja cambios en búsqueda."""
            opts = app_logic.list_courses(t, filter_m, filter_p)
            return gr.update(choices=opts, value=None)

        search.change(
            search_change,
            inputs=[search, filter_mandatory, filter_pending],
            outputs=[course_dropdown]
        )

        filter_mandatory.change(
            search_change,
            inputs=[search, filter_mandatory, filter_pending],
            outputs=[course_dropdown]
        )

        filter_pending.change(
            search_change,
            inputs=[search, filter_mandatory, filter_pending],
            outputs=[course_dropdown]
        )

        def on_course_select(course):
            """Maneja selección de curso."""
            if not course:
                return gr.update(choices=[], value=[]), gr.update(value="")

            secs = app_logic.get_sections_for_course(course)
            return gr.update(choices=secs, value=[]), gr.update(value="")

        course_dropdown.change(
            on_course_select,
            inputs=[course_dropdown],
            outputs=[section_dropdown, section_info]
        )

        def on_section_select(selected):
            """Cuando se selecciona una o más secciones, mostrar días/horarios."""
            if not selected:
                return gr.update(value="")
            # selected puede ser lista o string
            items = selected if isinstance(selected, list) else [selected]
            parts = []
            for s in items:
                days = app_logic.get_days_for_section(s)
                header = s.split('|', 1)[-1]
                if days:
                    parts.append(f"**{header}**")
                    for d in days:
                        parts.append(f"- {d}")
                else:
                    parts.append(f"**{header}** — Sin horarios disponibles")
            return gr.update(value="\n".join(parts))

        section_dropdown.change(
            on_section_select,
            inputs=[section_dropdown],
            outputs=[section_info]
        )

        def add_and_refresh(selected_sections, sched, replace):
            """Añade secciones al horario y refresca vistas."""
            idx = int(sched)
            msg = app_logic.add_to_schedule(selected_sections, idx, force_replace=bool(replace))

            # Detectar conflictos
            _, conflicts_msg = app_logic.detect_conflicts(idx)
            if conflicts_msg:
                msg = f"{msg}\n\n{conflicts_msg}"

            classes_img_b, exams_img_b = app_logic.draw_week_schedule(idx)

            return (
                app_logic.get_schedule_table(1), f"**Créditos:** {app_logic.credits[1]:.1f} / 25.0",
                app_logic.get_schedule_table(2), f"**Créditos:** {app_logic.credits[2]:.1f} / 25.0",
                app_logic.get_schedule_table(3), f"**Créditos:** {app_logic.credits[3]:.1f} / 25.0",
                msg,
                classes_img_b, exams_img_b,
                gr.update(choices=blocks_choices(1), value=None),
                gr.update(choices=blocks_choices(2), value=None),
                gr.update(choices=blocks_choices(3), value=None)
            )

        btn_add.click(
            add_and_refresh,
            inputs=[section_dropdown, add_schedule, replace_conflicts],
            outputs=[
                df1, text1, df2, text2, df3, text3, status,
                classes_img, exams_img,
                remove_dd1, remove_dd2, remove_dd3
            ]
        )

        def update_schedule_view(sched_idx):
            """Actualiza la visualización del horario seleccionado."""
            idx = int(sched_idx)
            classes_img_b, exams_img_b = app_logic.draw_week_schedule(idx)
            return classes_img_b, exams_img_b

        current_schedule_view.change(
            update_schedule_view,
            inputs=[current_schedule_view],
            outputs=[classes_img, exams_img]
        )

        def save_schedule_images(sched_idx):
            """Guarda las imágenes del horario como PNG."""
            idx = int(sched_idx)
            save_path = f"horario_{idx}"
            app_logic.draw_week_schedule(idx, save_path=save_path)
            return f"✓ Horarios guardados: {save_path}_clase.png y {save_path}_exam.png"

        btn_save_classes_png.click(
            lambda s: save_schedule_images(s),
            inputs=[current_schedule_view],
            outputs=[status]
        )

        btn_save_exams_png.click(
            lambda s: save_schedule_images(s),
            inputs=[current_schedule_view],
            outputs=[status]
        )

        def save_progress_click():
            """Guarda progreso."""
            return app_logic.save_progress()

        btn_save.click(save_progress_click, inputs=[], outputs=[status])

        def load_progress_click():
            """Carga progreso."""
            msg = app_logic.load_progress()

            # Actualizar cursos llevados si hay carrera cargada
            if app_logic.curriculum:
                cycles = app_logic.curriculum.cycles
                all_m, taken, pending = app_logic.get_mandatory_courses_status()
                stats_text = f"**Total llevados:** {len(taken)} / {len(all_m)} | **Pendientes:** {len(pending)}"
            else:
                cycles = []
                stats_text = ""

            return (
                app_logic.get_schedule_table(1), f"**Créditos:** {app_logic.credits[1]:.1f} / 25.0",
                app_logic.get_schedule_table(2), f"**Créditos:** {app_logic.credits[2]:.1f} / 25.0",
                app_logic.get_schedule_table(3), f"**Créditos:** {app_logic.credits[3]:.1f} / 25.0",
                msg,
                app_logic.draw_week_schedule(1)[0],
                app_logic.draw_week_schedule(1)[1],
                gr.update(choices=blocks_choices(1), value=None),
                gr.update(choices=blocks_choices(2), value=None),
                gr.update(choices=blocks_choices(3), value=None),
                gr.update(choices=cycles, value=None),
                stats_text
            )

        btn_load_progress.click(
            load_progress_click,
            inputs=[],
            outputs=[
                df1, text1, df2, text2, df3, text3, status,
                classes_img, exams_img,
                remove_dd1, remove_dd2, remove_dd3,
                cycle_selector, mandatory_stats
            ]
        )

        # Exports
        def export1():
            return app_logic.export_schedule(1)

        def export2():
            return app_logic.export_schedule(2)

        def export3():
            return app_logic.export_schedule(3)

        btn_export1.click(export1, inputs=[], outputs=[status])
        btn_export2.click(export2, inputs=[], outputs=[status])
        btn_export3.click(export3, inputs=[], outputs=[status])

        # Removes
        def remove_sched1(block_id):
            if not block_id:
                return (
                    app_logic.get_schedule_table(1),
                    f"**Créditos:** {app_logic.credits[1]:.1f} / 25.0",
                    "⚠ Selecciona un bloque",
                    None, None,
                    gr.update(choices=blocks_choices(1), value=None)
                )

            app_logic.remove_from_schedule(block_id, 1)
            classes_img_b, exams_img_b = app_logic.draw_week_schedule(1)

            return (
                app_logic.get_schedule_table(1),
                f"**Créditos:** {app_logic.credits[1]:.1f} / 25.0",
                f"✓ Eliminado: {block_id}",
                classes_img_b, exams_img_b,
                gr.update(choices=blocks_choices(1), value=None)
            )

        def remove_sched2(block_id):
            if not block_id:
                return (
                    app_logic.get_schedule_table(2),
                    f"**Créditos:** {app_logic.credits[2]:.1f} / 25.0",
                    "⚠ Selecciona un bloque",
                    None, None,
                    gr.update(choices=blocks_choices(2), value=None)
                )

            app_logic.remove_from_schedule(block_id, 2)
            classes_img_b, exams_img_b = app_logic.draw_week_schedule(2)

            return (
                app_logic.get_schedule_table(2),
                f"**Créditos:** {app_logic.credits[2]:.1f} / 25.0",
                f"✓ Eliminado: {block_id}",
                classes_img_b, exams_img_b,
                gr.update(choices=blocks_choices(2), value=None)
            )

        def remove_sched3(block_id):
            if not block_id:
                return (
                    app_logic.get_schedule_table(3),
                    f"**Créditos:** {app_logic.credits[3]:.1f} / 25.0",
                    "⚠ Selecciona un bloque",
                    None, None,
                    gr.update(choices=blocks_choices(3), value=None)
                )

            app_logic.remove_from_schedule(block_id, 3)
            classes_img_b, exams_img_b = app_logic.draw_week_schedule(3)

            return (
                app_logic.get_schedule_table(3),
                f"**Créditos:** {app_logic.credits[3]:.1f} / 25.0",
                f"✓ Eliminado: {block_id}",
                classes_img_b, exams_img_b,
                gr.update(choices=blocks_choices(3), value=None)
            )

        btn_remove1.click(
            remove_sched1,
            inputs=[remove_dd1],
            outputs=[df1, text1, status, classes_img, exams_img, remove_dd1]
        )

        btn_remove2.click(
            remove_sched2,
            inputs=[remove_dd2],
            outputs=[df2, text2, status, classes_img, exams_img, remove_dd2]
        )

        btn_remove3.click(
            remove_sched3,
            inputs=[remove_dd3],
            outputs=[df3, text3, status, classes_img, exams_img, remove_dd3]
        )

    return demo


if __name__ == '__main__':
    demo = build_ui()
    port = int(os.environ.get('GRADIO_SERVER_PORT', '7860'))
    demo.launch(share=False, server_name="127.0.0.1", server_port=port)
