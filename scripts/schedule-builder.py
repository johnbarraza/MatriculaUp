import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import pandas as pd
from datetime import datetime, timedelta
from PIL import Image, ImageGrab
import unicodedata
from tkinter import PhotoImage

def parse_credits(value):
    s = str(value).strip().replace(',', '.')
    try:
        return float(s)
    except:
        return 0.0

def normalize_str(s):
    # Quita tildes y pasa a minúsculas
    return ''.join(
        c for c in unicodedata.normalize('NFD', str(s).lower())
        if unicodedata.category(c) != 'Mn'
    )

def match_keywords(text, keywords):
    # Devuelve True si todas las palabras clave están en el texto
    text_norm = normalize_str(text)
    return all(kw in text_norm for kw in keywords)

class ScheduleBuilder:
    def __init__(self, root):
        self.root = root
        self.root.title("Planificador de Horarios")
        self.root.state("zoomed")
        self.root.rowconfigure(0, weight=1)
        self.root.columnconfigure(0, weight=1)
        self.courses_df = None
        self.schedules_data = {}

        # Frame principal con grid
        self.main_frame = ttk.Frame(root, padding="10")
        self.main_frame.grid(row=0, column=0, sticky="nsew")
        self.main_frame.rowconfigure(0, weight=1)
        self.main_frame.columnconfigure(0, weight=0)
        self.main_frame.columnconfigure(1, weight=1)

        # ------------------- PARTE IZQUIERDA -------------------
        self.left_frame = ttk.Frame(self.main_frame)
        self.left_frame.grid(row=0, column=0, padx=5, sticky="nsew")

        # --- Agrupa búsqueda y lista de cursos ---
        search_frame = ttk.LabelFrame(self.left_frame, text="Buscar y Seleccionar Curso", padding="8")
        search_frame.grid(row=0, column=0, pady=5, columnspan=3, sticky="nsew")

        # Botón cargar datos
        ttk.Button(search_frame, text="📂 Cargar Datos", command=self.load_file).grid(
            row=0, column=0, pady=5, columnspan=2, sticky="ew"
        )

        # Barra de búsqueda con ícono
        ttk.Label(search_frame, text="🔍 Buscar Curso o Docente:").grid(row=1, column=0, pady=5, sticky=tk.W)
        self.search_var = tk.StringVar()
        self.search_var.trace('w', self.filter_courses)
        self.search_entry = ttk.Entry(search_frame, textvariable=self.search_var, width=28, font=("Segoe UI", 11))
        self.search_entry.grid(row=2, column=0, pady=5, sticky="ew", columnspan=2)

        # Botón para mostrar solo SIN cruce
        ttk.Button(search_frame, text="✅ Solo SIN cruce", command=lambda: self.filter_courses(only_no_conflict=True)).grid(
            row=2, column=2, padx=5, pady=5, sticky="ew"
        )

        # Frame para TreeView + Scrollbar
        tree_frame = ttk.LabelFrame(self.left_frame, text="Lista de Cursos", padding="5")
        tree_frame.grid(row=1, column=0, pady=5, columnspan=3, sticky="nsew")
        tree_frame.rowconfigure(0, weight=1)
        tree_frame.columnconfigure(0, weight=1)

        self.courses_scrollbar = ttk.Scrollbar(tree_frame, orient=tk.VERTICAL)
        self.courses_scrollbar.grid(row=0, column=1, sticky="ns")

        self.courses_tree = ttk.Treeview(
            tree_frame, height=16, selectmode="browse",
            yscrollcommand=self.courses_scrollbar.set, show="headings"
        )
        self.courses_tree.grid(row=0, column=0, sticky="nsew")
        self.courses_scrollbar.config(command=self.courses_tree.yview)

        # Columnas y encabezados
        self.courses_tree["columns"] = (
            "Secc", "Profesor", "Tipo", "Dia", "Inicio", "Fin", "Prerequisitos", "Cred"
        )
        for col, width, anchor in [
            ("Secc", 60, tk.CENTER), ("Profesor", 150, tk.W), ("Tipo", 80, tk.CENTER),
            ("Dia", 60, tk.CENTER), ("Inicio", 60, tk.CENTER), ("Fin", 60, tk.CENTER),
            ("Prerequisitos", 130, tk.W), ("Cred", 60, tk.E)
        ]:
            self.courses_tree.column(col, width=width, anchor=anchor)
            self.courses_tree.heading(col, text=col)

        # Botón para Agregar curso
        ttk.Button(self.left_frame, text="➕ Agregar Curso Seleccionado", command=self.add_course).grid(
            row=2, column=0, pady=8, sticky="ew"
        )
        # Botón para Eliminar curso seleccionado de la lista de cursos
        ttk.Button(self.left_frame, text="🗑️ Eliminar Curso Seleccionado del Horario", command=self.remove_selected_from_schedule).grid(
            row=2, column=1, pady=8, sticky="ew"
        )

        # --- Notebook de horarios ---
        self.notebook = ttk.Notebook(self.left_frame)
        self.notebook.grid(row=3, column=0, pady=5, columnspan=3, sticky="nsew")

        for i in range(1, 4):
            frame = ttk.Frame(self.notebook)
            self.notebook.add(frame, text=f"Horario {i}")
            
            tv = ttk.Treeview(frame, height=8, selectmode="extended")
            tv["columns"] = (
                "Secc", "Profesor", "Tipo", "Dia", "Inicio", "Fin", "Prerequisitos", "Cred"
            )
            tv.column("#0", width=220, anchor=tk.W)
            tv.column("Secc", width=60, anchor=tk.CENTER)
            tv.column("Profesor", width=150, anchor=tk.W)
            tv.column("Tipo", width=80, anchor=tk.CENTER)
            tv.column("Dia", width=60, anchor=tk.CENTER)
            tv.column("Inicio", width=60, anchor=tk.CENTER)
            tv.column("Fin", width=60, anchor=tk.CENTER)
            tv.column("Prerequisitos", width=130, anchor=tk.W)
            tv.column("Cred", width=60, anchor=tk.E)
            
            tv.heading("#0", text="Curso")
            tv.heading("Secc", text="Sec")
            tv.heading("Profesor", text="Profesor")
            tv.heading("Tipo", text="Tipo")
            tv.heading("Dia", text="Día")
            tv.heading("Inicio", text="Inicio")
            tv.heading("Fin", text="Fin")
            tv.heading("Prerequisitos", text="Prereq.")
            tv.heading("Cred", text="Créditos")
            
            tv.grid(row=0, column=0, pady=5, columnspan=3, sticky="nsew")
            
            credits_frame = ttk.LabelFrame(frame, text="Total de Créditos", padding="5")
            credits_frame.grid(row=1, column=0, pady=5, columnspan=3, sticky=(tk.W, tk.E))
            credits_label = ttk.Label(credits_frame, text="0 créditos")
            credits_label.grid(row=0, column=0)
            
            btn_remove_sel = ttk.Button(
                frame, 
                text="Eliminar Seleccionados",
                command=lambda tab=i: self.remove_selected_courses(tab)
            )
            btn_remove_sel.grid(row=2, column=0, pady=5, sticky=tk.E)
            
            btn_remove_all = ttk.Button(
                frame,
                text="Limpiar Todo Este Horario",
                command=lambda tab=i: self.clear_all_in_tab(tab)
            )
            btn_remove_all.grid(row=2, column=1, pady=5, sticky=tk.E)
            
            # Hacemos que el Frame interno se expanda también
            frame.rowconfigure(0, weight=1)
            frame.columnconfigure(0, weight=1)
            
            self.schedules_data[i] = {
                "tree": tv,
                "credits": 0.0,
                "credits_label": credits_label
            }
        
        ttk.Button(
            self.left_frame,
            text="Limpiar TODOS los Horarios",
            command=self.clear_all_tabs
        ).grid(row=6, column=0, pady=5, columnspan=2)
        
        # ----------------------------------------------------------------------
        # PARTE DERECHA: Notebook Clases / Exámenes con Canvas
        # ----------------------------------------------------------------------
        
        self.right_frame = ttk.Frame(self.main_frame)
        self.right_frame.grid(row=0, column=1, padx=5, sticky="nsew")
        
        # Este frame se expande
        self.right_frame.rowconfigure(0, weight=1)
        self.right_frame.columnconfigure(0, weight=1)
        
        self.right_notebook = ttk.Notebook(self.right_frame)
        self.right_notebook.grid(row=0, column=0, sticky="nsew")
        self.right_frame.rowconfigure(0, weight=1)
        self.right_frame.columnconfigure(0, weight=1)
        
        # -- Pestaña Clases --
        self.tab_clases = ttk.Frame(self.right_notebook)
        self.right_notebook.add(self.tab_clases, text="Clases")
        
        # Frame interno con scrollbar + canvas
        self.clases_frame = ttk.Frame(self.tab_clases)
        self.clases_frame.pack(fill="both", expand=True)
        
        self.schedule_canvas_clases = tk.Canvas(self.clases_frame, bg='white')
        self.schedule_canvas_clases.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        self.clases_scrollbar = ttk.Scrollbar(
            self.clases_frame, orient=tk.VERTICAL,
            command=self.schedule_canvas_clases.yview
        )
        self.clases_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.schedule_canvas_clases.configure(yscrollcommand=self.clases_scrollbar.set)
        
        # -- Pestaña Exámenes --
        self.tab_examenes = ttk.Frame(self.right_notebook)
        self.right_notebook.add(self.tab_examenes, text="Exámenes")
        
        self.examenes_frame = ttk.Frame(self.tab_examenes)
        self.examenes_frame.pack(fill="both", expand=True)
        
        self.schedule_canvas_examenes = tk.Canvas(self.examenes_frame, bg='white')
        self.schedule_canvas_examenes.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        self.examenes_scrollbar = ttk.Scrollbar(
            self.examenes_frame, orient=tk.VERTICAL,
            command=self.schedule_canvas_examenes.yview
        )
        self.examenes_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.schedule_canvas_examenes.configure(yscrollcommand=self.examenes_scrollbar.set)
        
        # Dibujar la grilla base
        self.create_schedule_grid(self.schedule_canvas_clases)
        self.create_schedule_grid(self.schedule_canvas_examenes)
        
        # Ajustar el scrollregion
        self.schedule_canvas_clases.config(scrollregion=self.schedule_canvas_clases.bbox("all"))
        self.schedule_canvas_examenes.config(scrollregion=self.schedule_canvas_examenes.bbox("all"))
        
        # Botón para guardar PNG
        ttk.Button(
            self.right_frame,
            text="Guardar Clases y Exámenes como PNG",
            command=self.save_both_canvases
        ).grid(row=1, column=0, padx=5, pady=5, sticky=tk.W)
        
        self.notebook.bind("<<NotebookTabChanged>>", self.on_tab_changed)

    # ----------------- create_schedule_grid -----------------
    def create_schedule_grid(self, canvas):
        canvas.delete("all")
        
        days = ['LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO']
        cell_width = 120
        cell_height = 30
        first_col_width = 80
        header_height = 40
        
        for i, day in enumerate(days):
            x = first_col_width + i * cell_width
            canvas.create_rectangle(x, 0, x + cell_width, header_height, fill='lightgray')
            canvas.create_text(x + cell_width/2, header_height/2, text=day)
        
        current_time = datetime.strptime("07:30", "%H:%M")
        end_time = datetime.strptime("23:30", "%H:%M")
        row = 0
        while current_time <= end_time:
            y = header_height + row * cell_height
            time_str = current_time.strftime("%H:%M")
            
            canvas.create_rectangle(0, y, first_col_width, y + cell_height)
            canvas.create_text(40, y + cell_height/2, text=time_str)
            
            for i in range(len(days)):
                x = first_col_width + i * cell_width
                canvas.create_rectangle(x, y, x + cell_width, y + cell_height)
            
            current_time += timedelta(minutes=30)
            row += 1

    # ----------------- load_file / filter_courses -----------------
    def load_file(self):
        file_path = filedialog.askopenfilename(
            filetypes=[("Excel files", "*.xlsx *.xls"), ("CSV files", "*.csv")]
        )
        if file_path:
            try:
                if file_path.endswith('.csv'):
                    self.courses_df = pd.read_csv(file_path)
                else:
                    self.courses_df = pd.read_excel(file_path)
                
                self.filter_courses()
                messagebox.showinfo("Éxito", "Datos cargados correctamente!")
            except Exception as e:
                messagebox.showerror("Error", f"Error al cargar archivo: {str(e)}")

    def filter_courses(self, *args, only_no_conflict=False):
        if self.courses_df is None:
            return
        for item in self.courses_tree.get_children():
            self.courses_tree.delete(item)

        search_term = normalize_str(self.search_var.get())
        keywords = [w for w in search_term.split() if w]

        filtered_df = self.courses_df.copy()
        if keywords:
            mask = filtered_df.apply(
                lambda row: (
                    match_keywords(row['Curso'], keywords) or
                    match_keywords(row['Docentes'], keywords)
                ),
                axis=1
            )
            filtered_df = filtered_df[mask]

        # Grupos de tipo
        CLASES_SET = {"CLASE", "PRÁCTICA", "PRÁCTICAS", "PRACDIRIGI"}
        EXAMENES_SET = {"FINAL", "PARCIAL"}

        # Obtener bloques ya seleccionados en el horario activo
        tab = self.get_current_tab()
        schedule_info = self.schedules_data[tab]
        sel_tree = schedule_info["tree"]
        existing_blocks = []
        for sid in sel_tree.get_children():
            v = sel_tree.item(sid)['values']
            tipo = (v[2] or "").upper().strip()
            dia = v[3]
            ini = v[4]
            fin = v[5]
            existing_blocks.append((tipo, dia, ini, fin))

        grouped = filtered_df.groupby(
            ["Curso", "Secc", "Docentes", "Cred", "Prerequisitos"],
            dropna=False
        )

        # Configura los tags de color
        self.courses_tree.tag_configure("conflict", background="#ffcccc")    # rojo claro
        self.courses_tree.tag_configure("no_conflict", background="#ccffcc") # verde claro

        for (curso, secc, prof, cred, prereq), group_data in grouped:
            # Verifica si algún bloque de este curso se cruza con los existentes SOLO dentro del mismo grupo
            has_conflict = False
            for idx, row in group_data.iterrows():
                tipo_n = (str(row["Tipo"]) or "").upper().strip()
                dia_n = str(row["Día"]).upper().strip()
                try:
                    start_n = datetime.strptime(row["Horario_Inicio"], '%H:%M')
                    end_n = datetime.strptime(row["Horario_Cierre"], '%H:%M')
                except:
                    continue
                # Determina el grupo del bloque nuevo
                if tipo_n in CLASES_SET:
                    grupo_n = "CLASE"
                elif tipo_n in EXAMENES_SET:
                    grupo_n = "EXAMEN"
                else:
                    grupo_n = "OTRO"
                for tipo_e, dia_e, ini_e, fin_e in existing_blocks:
                    if dia_n != str(dia_e).upper().strip():
                        continue
                    # Determina el grupo del bloque existente
                    if tipo_e in CLASES_SET:
                        grupo_e = "CLASE"
                    elif tipo_e in EXAMENES_SET:
                        grupo_e = "EXAMEN"
                    else:
                        grupo_e = "OTRO"
                    # Solo comparar si son del mismo grupo
                    if grupo_n != grupo_e or grupo_n == "OTRO":
                        continue
                    try:
                        start_e = datetime.strptime(ini_e, '%H:%M')
                        end_e = datetime.strptime(fin_e, '%H:%M')
                    except:
                        continue
                    if start_n < end_e and end_n > start_e:
                        has_conflict = True
                        break
                if has_conflict:
                    break

            tag = "conflict" if has_conflict else "no_conflict"
            if only_no_conflict and tag == "conflict":
                continue
            parent_id = self.courses_tree.insert(
                "",
                "end",
                text=curso,
                values=(
                    secc, prof, "", "", "", "", str(prereq), str(cred)
                ),
                tags=(tag,)
            )
            for idx, row in group_data.iterrows():
                tipo = str(row["Tipo"]) if "Tipo" in row else ""
                dia  = str(row["Día"])
                ini  = str(row["Horario_Inicio"])
                fin  = str(row["Horario_Cierre"])
                self.courses_tree.insert(
                    parent_id,
                    "end",
                    text="",
                    values=("", "", tipo, dia, ini, fin, "", ""),
                    tags=(tag,)
                )

    # ----------------- Acciones de horario (añadir, eliminar, limpiar) -----------------
    def on_tab_changed(self, event):
        self.refresh_schedule()

    def get_current_tab(self):
        return self.notebook.index(self.notebook.select()) + 1

    def add_course(self):
        if self.courses_df is None:
            return
        selected_item = self.courses_tree.selection()
        if not selected_item:
            messagebox.showwarning("Advertencia", "Seleccione un curso de la lista.")
            return

        item_id = selected_item[0]
        parent_id = self.courses_tree.parent(item_id)
        if parent_id:
            father_id = parent_id
        else:
            father_id = item_id

        father_text  = self.courses_tree.item(father_id)['text']
        father_vals  = self.courses_tree.item(father_id)['values']
        father_secc  = father_vals[0]
        father_prof  = father_vals[1]
        father_pre   = father_vals[6]
        father_cred  = father_vals[7]
        father_cred_val = parse_credits(father_cred)

        course_block_id = f"{father_text}__{father_secc}"

        child_ids = self.courses_tree.get_children(father_id)
        if not child_ids:
            child_ids = [father_id]

        new_rows = []
        for cid in child_ids:
            vals = self.courses_tree.item(cid)['values']
            if cid == father_id:
                tipo = father_vals[2]
                dia  = father_vals[3]
                ini  = father_vals[4]
                fin  = father_vals[5]
            else:
                tipo = vals[2]
                dia  = vals[3]
                ini  = vals[4]
                fin  = vals[5]
            new_rows.append({
                'Curso': father_text,
                'Secc': father_secc,
                'Docentes': father_prof,
                'Tipo': tipo,
                'Día':  dia,
                'Horario_Inicio': ini,
                'Horario_Cierre': fin
            })

        tab = self.get_current_tab()
        schedule_info = self.schedules_data[tab]
        sel_tree = schedule_info["tree"]

        # Revisar duplicado
        for sid in sel_tree.get_children():
            if sel_tree.item(sid)['text'] == course_block_id:
                messagebox.showwarning(
                    "Advertencia",
                    "Ya añadiste este curso (mismo curso y sección) en esta pestaña."
                )
                return

        # Definir grupos de tipo
        CLASES_SET = {"CLASE", "PRÁCTICA", "PRÁCTICAS", "PRACDIRIGI"}
        EXAMENES_SET = {"FINAL", "PARCIAL"}

        # Construir dataframe de bloques existentes
        existing_df = pd.DataFrame()
        for sid in sel_tree.get_children():
            cblock = sel_tree.item(sid)['text']
            v  = sel_tree.item(sid)['values']
            tipo = (v[2] or "").upper().strip()
            day = v[3]
            ini = v[4]
            fin = v[5]
            row_dict = {
                'Block': cblock,
                'Tipo': tipo,
                'Día': day,
                'Horario_Inicio': ini,
                'Horario_Cierre': fin
            }
            existing_df = pd.concat([existing_df, pd.DataFrame([row_dict])], ignore_index=True)

        # Detectar conflictos por grupo
        conflicts_clases = []
        conflicts_examenes = []
        nd = pd.DataFrame(new_rows)
        for idx_new, rn in nd.iterrows():
            tipo_n = (str(rn['Tipo']) or "").upper().strip()
            d_n = str(rn['Día']).upper().strip()
            try:
                start_n = datetime.strptime(rn['Horario_Inicio'], '%H:%M')
                end_n   = datetime.strptime(rn['Horario_Cierre'], '%H:%M')
            except:
                continue
            for idx_ex, re in existing_df.iterrows():
                tipo_e = (str(re['Tipo']) or "").upper().strip()
                d_e = str(re['Día']).upper().strip()
                if d_n != d_e:
                    continue
                try:
                    start_e = datetime.strptime(re['Horario_Inicio'], '%H:%M')
                    end_e   = datetime.strptime(re['Horario_Cierre'], '%H:%M')
                except:
                    continue
                if start_n < end_e and end_n > start_e:
                    # Solo comparar dentro del mismo grupo
                    if tipo_n in CLASES_SET and tipo_e in CLASES_SET:
                        conflicts_clases.append((rn, re))
                    elif tipo_n in EXAMENES_SET and tipo_e in EXAMENES_SET:
                        conflicts_examenes.append((rn, re))

        # Mostrar conflictos por grupo
        def show_conflict_message(conflicts, grupo_nombre):
            if conflicts:
                msg = f"Conflicto de horario en {grupo_nombre}:\n\n"
                conflict_names = set()
                for (rn, re) in conflicts:
                    conflict_names.add(
                        f" - {re['Block']} (Día {re['Día']} {re['Horario_Inicio']}-{re['Horario_Cierre']})"
                    )
                msg += "\n".join(conflict_names)
                msg += f"\n\n¿Deseas conservar el NUEVO (y quitar los viejos que chocan)?"
                res = messagebox.askyesno(f"Conflicto de horario en {grupo_nombre}", msg, icon='warning')
                if not res:
                    return False
                # Eliminar los bloques que chocan
                to_remove = set(re['Block'] for (rn, re) in conflicts)
                for sid in sel_tree.get_children():
                    c_test = sel_tree.item(sid)['text']
                    if c_test in to_remove:
                        old_cred_txt = sel_tree.item(sid)['values'][7]
                        old_cred_val = parse_credits(old_cred_txt)
                        schedule_info["credits"] -= old_cred_val
                        if schedule_info["credits"] < 0:
                            schedule_info["credits"] = 0.0
                        sel_tree.delete(sid)
            return True

        if not show_conflict_message(conflicts_clases, "Clases/Prácticas"):
            return
        if not show_conflict_message(conflicts_examenes, "Parcial/Final"):
            return

        # Insertar
        first = True
        for idx, row in nd.iterrows():
            day  = row["Día"]
            ini  = row["Horario_Inicio"]
            fin  = row["Horario_Cierre"]
            tipo = row["Tipo"]

            if first:
                row_cred_val = father_cred_val
                cred_txt = str(father_cred)
                first = False
            else:
                row_cred_val = 0.0
                cred_txt = "0"

            sel_tree.insert(
                "",
                "end",
                text=course_block_id,
                values=(
                    father_secc,
                    father_prof,
                    tipo,
                    day,
                    ini,
                    fin,
                    father_pre,
                    cred_txt
                )
            )

        schedule_info["credits"] += father_cred_val
        schedule_info["credits_label"].config(text=f"{schedule_info['credits']} créditos")

        self.refresh_schedule()

    def remove_selected_courses(self, tab):
        schedule_info = self.schedules_data[tab]
        sel_tree = schedule_info["tree"]
        
        selected_items = sel_tree.selection()
        if not selected_items:
            messagebox.showwarning("Advertencia", "Seleccione uno o varios cursos para eliminar.")
            return
        
        blocks_to_remove = set()
        for item_id in selected_items:
            block_id = sel_tree.item(item_id)['text']
            if block_id:
                blocks_to_remove.add(block_id)
        
        if not blocks_to_remove:
            messagebox.showwarning("Advertencia", "No se encontró bloque en la selección.")
            return
        
        for block_id in blocks_to_remove:
            self._remove_block_from_tab(tab, block_id)
        
        self.refresh_schedule()

    def _remove_block_from_tab(self, tab, block_id):
        schedule_info = self.schedules_data[tab]
        sel_tree = schedule_info["tree"]
        
        items_to_remove = []
        credits_to_remove = 0.0
        
        for sid in sel_tree.get_children():
            t = sel_tree.item(sid)['text']
            if t == block_id:
                items_to_remove.append(sid)
        
        for sid in items_to_remove:
            val_cred_txt = sel_tree.item(sid)['values'][7]
            cval = parse_credits(val_cred_txt)
            if cval > 0:
                credits_to_remove += cval
        
        for sid in items_to_remove:
            sel_tree.delete(sid)
        
        schedule_info["credits"] -= credits_to_remove
        if schedule_info["credits"] < 0:
            schedule_info["credits"] = 0.0
        schedule_info["credits_label"].config(text=f"{schedule_info['credits']} créditos")

    def clear_all_in_tab(self, tab):
        schedule_info = self.schedules_data[tab]
        sel_tree = schedule_info["tree"]
        
        for sid in sel_tree.get_children():
            sel_tree.delete(sid)
        
        schedule_info["credits"] = 0.0
        schedule_info["credits_label"].config(text="0 créditos")
        
        self.refresh_schedule()

    def clear_all_tabs(self):
        for tab in range(1, 4):
            self.clear_all_in_tab(tab)

    # ----------------- REFRESH / DRAW -----------------
    def refresh_schedule(self):
        # Redibuja la grilla base en ambos canvas
        self.create_schedule_grid(self.schedule_canvas_clases)
        self.create_schedule_grid(self.schedule_canvas_examenes)
        
        # Ajustar scroll
        self.schedule_canvas_clases.config(scrollregion=self.schedule_canvas_clases.bbox("all"))
        self.schedule_canvas_examenes.config(scrollregion=self.schedule_canvas_examenes.bbox("all"))
        
        tab = self.get_current_tab()
        schedule_info = self.schedules_data[tab]
        sel_tree = schedule_info["tree"]
        
        CLASES_SET = {"CLASE", "PRÁCTICA", "PRÁCTICAS", "PRACDIRIGI"}
        EXAMENES_SET = {"FINAL", "PARCIAL"}
        
        for sid in sel_tree.get_children():
            v = sel_tree.item(sid)['values']
            tipo = (v[2] or "").upper().strip()
            dia  = v[3]
            ini  = v[4]
            fin  = v[5]
            prof = v[1]
            block_id = sel_tree.item(sid)['text']
            
            if tipo in CLASES_SET:
                self.draw_schedule_block(self.schedule_canvas_clases, dia, ini, fin, block_id, prof)
            if tipo in EXAMENES_SET:
                self.draw_schedule_block(self.schedule_canvas_examenes, dia, ini, fin, block_id, prof)
        
        # Ajustar scrollregion después de dibujar los rectángulos
        self.schedule_canvas_clases.config(scrollregion=self.schedule_canvas_clases.bbox("all"))
        self.schedule_canvas_examenes.config(scrollregion=self.schedule_canvas_examenes.bbox("all"))

    def draw_schedule_block(self, canvas, dia, ini, fin, block_id, prof):
        day_mapping = {
            'LUN': 0, 'LUNES': 0,
            'MAR': 1, 'MARTES': 1,
            'MIE': 2, 'MIÉRCOLES': 2,
            'JUE': 3, 'JUEVES': 3,
            'VIE': 4, 'VIERNES': 4,
            'SAB': 5, 'SÁBADO': 5
        }
        
        d = (dia or "").upper().strip()
        if d not in day_mapping:
            return
        
        try:
            start_time = datetime.strptime(ini, '%H:%M')
            end_time   = datetime.strptime(fin, '%H:%M')
        except:
            return
        
        base_time = datetime.strptime("07:30", "%H:%M")
        start_blocks = (start_time - base_time).seconds / 1800
        end_blocks   = (end_time - base_time).seconds / 1800
        
        cell_width = 120
        cell_height = 30
        first_col_width = 80
        header_height = 40
        
        day_index = day_mapping[d]
        x1 = first_col_width + day_index * cell_width
        y1 = header_height + start_blocks * cell_height
        x2 = x1 + cell_width
        y2 = header_height + end_blocks * cell_height

        # --- COLOR SEGÚN TIPO ---
        tipo = ""
        # Buscar el tipo usando el block_id y prof
        for tab in self.schedules_data.values():
            tree = tab["tree"]
            for sid in tree.get_children():
                v = tree.item(sid)['values']
                t = (v[2] or "").upper().strip()
                p = v[1]
                b = tree.item(sid)['text']
                if b == block_id and p == prof:
                    tipo = t
                    break

        if tipo == "CLASE":
            color = '#7ecbff'  # celeste
        elif tipo in {"PRÁCTICA", "PRÁCTICAS", "PRACDIRIGI"}:
            color = '#2ecc40'  # verde oscuro
        elif tipo == "FINAL":
            color = 'red'
        elif tipo == "PARCIAL":
            color = 'red'
        else:
            color = 'gray90'
        # ------------------------

        # --- TEXTO RESUMIDO ---
        # block_id: "Nombre del Curso__Seccion"
        curso, secc = block_id.split("__", 1) if "__" in block_id else (block_id, "")
        curso = curso.strip()
        # Abrevia el nombre si es muy largo
        if len(curso) > 22:
            palabras = curso.split()
            curso_abrev = ""
            for p in palabras:
                if len(curso_abrev) + len(p) + 1 > 18:
                    curso_abrev += p[:4] + ". "
                    break
                curso_abrev += p[:8] + " "
            curso = curso_abrev.strip()
        # Sección entre paréntesis
        secc = secc.strip()
        secc_txt = f"({secc})" if secc else ""
        # Apellido del profesor (primera palabra del campo)
        apellido = ""
        if prof:
            apellido = prof.split(",")[0].strip().upper()
        txt = f"{curso} {secc_txt}, {apellido}"
        # ----------------------

        canvas.create_rectangle(x1, y1, x2, y2, fill=color, outline='black')
        canvas.create_text(
            (x1 + x2)/2,
            (y1 + y2)/2,
            text=txt,
            width=(cell_width - 12),  # Ajusta el ancho para evitar desbordes
            font=("Arial", 9, "bold")
        )

    # ----------------- GUARDAR IMAGEN (Screenshot) -----------------
    def save_both_canvases(self):
        self.save_canvas_via_screenshot(self.schedule_canvas_clases, "HorarioClases.png")
        self.save_canvas_via_screenshot(self.schedule_canvas_examenes, "HorarioExamenes.png")
        
        messagebox.showinfo(
            "Guardado",
            "Se guardaron 'HorarioClases.png' y 'HorarioExamenes.png' exitosamente."
        )

    def save_canvas_via_screenshot(self, canvas, filename):
        x = canvas.winfo_rootx()
        y = canvas.winfo_rooty()
        w = x + canvas.winfo_width()
        h = y + canvas.winfo_height()
        
        screenshot = ImageGrab.grab(bbox=(x, y, w, h))
        screenshot.save(filename, "PNG")

def main():
    root = tk.Tk()
    app = ScheduleBuilder(root)
    root.mainloop()

if __name__ == "__main__":
    main()
