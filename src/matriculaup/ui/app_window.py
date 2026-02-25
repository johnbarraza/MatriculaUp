import sys
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QTabWidget, QLabel
)
from src.matriculaup.ui.tabs.search_tab import SearchTab
from src.matriculaup.ui.tabs.schedule_tab import ScheduleTab
from src.matriculaup.store.state import ScheduleState
from src.matriculaup.store.persistence import PersistenceManager

class AppWindow(QMainWindow):
    def __init__(self, courses=None, schedule_data=None):
        super().__init__()
        
        self.courses = courses or []
        self.schedule_data = schedule_data or []
        
        # 1. Initialize State
        self.state = ScheduleState(self)
        self.persistence = PersistenceManager()
        
        # 2. Main widget and layout
        self.setWindowTitle("MatriculaUp - Planificador 2026-1")
        self.resize(1024, 768)
        
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout(central_widget)
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs)
        
        # 3. Setup UI components
        self._setup_tabs()
        
        # 4. Wire persistence loading
        self._load_initial_state()
        
        # 5. Connect auto-saving
        self.state.on_sections_changed.connect(self._save_state)
        
    def _load_initial_state(self):
        """Matches saved dictionaries back to Course and Section objects"""
        # Create quick lookup for fast iteration
        course_map = {c.codigo: c for c in self.courses}
        
        # Schedule data format originally: ["["123"] (Strings) 
        # New format: [{"curso": "123", "seccion": "A"}]
        for item in self.schedule_data:
            if isinstance(item, str):
                # Legacy data, skip or clear because we changed models
                print(f"Skipping legacy string schedule item: {item}")
                continue
                
            course_code = item.get("curso")
            sec_code = item.get("seccion")
            
            if course := course_map.get(course_code):
                for sec in course.secciones:
                    if sec.seccion == sec_code:
                        self.state.add_section(course, sec)
                        break

    def _save_state(self, sections):
        # We will save a list of objects like {"curso": "123", "seccion": "A"}
        data_to_save = [{"curso": c.codigo, "seccion": s.seccion} for c, s in sections]
        self.persistence.save_schedule(data_to_save)
        
    def _setup_tabs(self):
        # Tab 1: Buscar Cursos
        self.tab_search = SearchTab(self.courses)
        self.tab_search.section_added.connect(self.state.add_section)
        self.tabs.addTab(self.tab_search, "Buscar Cursos")
        
        # Tab 2: Generar Horario
        self.tab_schedule = ScheduleTab(self)
        self.tabs.addTab(self.tab_schedule, "Generar Horario")
        
        # Connect the state changes to update the visual grid
        from src.matriculaup.core.conflict_detector import ConflictDetector
        
        def _update_schedule_tab(sections):
            conflicts = ConflictDetector.find_conflicts(sections)
            self.tab_schedule.update_schedule(sections, conflicts)
            
        self.state.on_sections_changed.connect(_update_schedule_tab)
        
        # Connect section removal (right click on grid block) back to state
        self.tab_schedule.section_removed.connect(
            lambda c, s: self.state.remove_section(c.codigo, s.seccion)
        )
        
        # Tab 3: Horarios Guardados
        self.tab_saved = QWidget()
        saved_layout = QVBoxLayout(self.tab_saved)
        saved_layout.addWidget(QLabel("Tab: Horarios Guardados"))
        self.tabs.addTab(self.tab_saved, "Horarios Guardados")
