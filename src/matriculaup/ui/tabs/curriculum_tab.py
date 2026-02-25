from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QComboBox, 
    QTableWidget, QTableWidgetItem, QHeaderView, QLabel
)
from PySide6.QtGui import QColor, QFont
from PySide6.QtCore import Qt

from matriculaup.models.curriculum import Curriculum
from matriculaup.models.course import Course, Section
from typing import List

class CurriculumTab(QWidget):
    def __init__(self, curriculum: Curriculum, available_courses: List[Course], parent=None):
        super().__init__(parent)
        self.curriculum = curriculum
        self.available_courses = available_courses
        
        # Fast lookup set for course codes currently offered this semester
        self.offered_codes = {c.codigo for c in available_courses}
        
        layout = QVBoxLayout(self)
        
        # 1. Top Filter Bar
        filter_layout = QHBoxLayout()
        filter_layout.addWidget(QLabel("Seleccionar Ciclo:"))
        
        self.cycle_combo = QComboBox()
        # Add all cycles to the dropdown
        for ciclo in self.curriculum.ciclos:
            self.cycle_combo.addItem(ciclo.nombre, userData=ciclo)
            
        self.cycle_combo.currentIndexChanged.connect(self._on_cycle_changed)
        filter_layout.addWidget(self.cycle_combo)
        filter_layout.addStretch()
        
        layout.addLayout(filter_layout)
        
        # 2. Results Table
        self.table = QTableWidget()
        self.table.setColumnCount(4)
        self.table.setHorizontalHeaderLabels(["Código", "Nombre del Curso", "Créditos", "Estado (2026-1)"])
        self.table.horizontalHeader().setSectionResizeMode(1, QHeaderView.Stretch)
        self.table.setEditTriggers(QTableWidget.NoEditTriggers)
        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        
        layout.addWidget(self.table)
        
        # Trigger initial load
        if self.curriculum.ciclos:
            self._render_table(self.curriculum.ciclos[0])
            
    def _on_cycle_changed(self, index: int):
        ciclo = self.cycle_combo.itemData(index)
        if ciclo:
            self._render_table(ciclo)
            
    def _render_table(self, ciclo):
        """Draws the curriculum courses for the given cycle, marking them available or unavailable."""
        self.table.setRowCount(len(ciclo.cursos))
        
        for row, course in enumerate(ciclo.cursos):
            is_offered = course.codigo in self.offered_codes
            
            # Setup items
            item_code = QTableWidgetItem(course.codigo)
            item_name = QTableWidgetItem(course.nombre)
            item_cred = QTableWidgetItem(course.creditos)
            
            status_text = "🟢 Disponible" if is_offered else "🔴 No Dictado"
            item_status = QTableWidgetItem(status_text)
            
            # Formatting
            font = QFont()
            font.setBold(is_offered)
            color = QColor(220, 255, 220) if is_offered else QColor(255, 230, 230)
            
            for item in (item_code, item_name, item_cred, item_status):
                if is_offered:
                    item.setFont(font)
                item.setBackground(color)
                
            self.table.setItem(row, 0, item_code)
            self.table.setItem(row, 1, item_name)
            self.table.setItem(row, 2, item_cred)
            self.table.setItem(row, 3, item_status)
