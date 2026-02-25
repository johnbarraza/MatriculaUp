from typing import List
from PySide6.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLineEdit, QComboBox, QLabel, QPushButton
from PySide6.QtCore import Qt, Signal

from matriculaup.models.course import Course, Section
from matriculaup.ui.components.course_tree import CourseTree

class SearchTab(QWidget):
    
    # Emits when the user wants to add a specific section to their schedule
    section_added = Signal(Course, Section)
    
    def __init__(self, courses: List[Course], parent=None):
        super().__init__(parent)
        self.courses = courses
        
        # Main layout
        layout = QVBoxLayout(self)
        
        # Top filter bar
        filter_layout = QHBoxLayout()
        
        # Search input
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("Buscar por código, curso, o docente (ej. 'economía', 'Perez')...")
        self.search_input.textChanged.connect(self._on_search_changed)
        
        # Type filter dropdown (Optional: for later narrowing)
        self.type_combo = QComboBox()
        self.type_combo.addItems(["Todos los tipos", "CLASE", "PRÁCTICA", "LABORATORIO"])
        # In a more advanced implementation, this combo box would also filter the tree view.
        
        filter_layout.addWidget(QLabel("Búsqueda:"))
        filter_layout.addWidget(self.search_input, stretch=1)
        filter_layout.addWidget(QLabel("Filtrar por:"))
        filter_layout.addWidget(self.type_combo)
        
        layout.addLayout(filter_layout)
        
        # Tree view of courses
        self.course_tree = CourseTree(self.courses)
        self.course_tree.section_added.connect(self.section_added.emit)
        
        layout.addWidget(self.course_tree)
        
    def _on_search_changed(self, text: str):
        # Relay the search text to the custom tree filter
        self.course_tree.filter_tree(text)
