import sys
from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QTabWidget, QLabel
)
from src.matriculaup.ui.tabs.search_tab import SearchTab
from src.matriculaup.ui.tabs.schedule_tab import ScheduleTab

class AppWindow(QMainWindow):
    def __init__(self, courses=None, schedule_data=None):
        super().__init__()
        
        self.courses = courses or []
        self.schedule_data = schedule_data or []
        
        self.setWindowTitle("MatriculaUp - Planificador 2026-1")
        self.resize(1024, 768)
        
        # Main widget and layout
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout(central_widget)
        
        # Tabs
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs)
        
        self._setup_tabs()
        
    def _setup_tabs(self):
        # Tab 1: Buscar Cursos
        self.tab_search = SearchTab(self.courses)
        self.tabs.addTab(self.tab_search, "Buscar Cursos")
        
        # Tab 2: Generar Horario
        self.tab_schedule = ScheduleTab(self)
        self.tabs.addTab(self.tab_schedule, "Generar Horario")
        
        # Tab 3: Horarios Guardados
        self.tab_saved = QWidget()
        saved_layout = QVBoxLayout(self.tab_saved)
        saved_layout.addWidget(QLabel("Tab: Horarios Guardados"))
        self.tabs.addTab(self.tab_saved, "Horarios Guardados")
