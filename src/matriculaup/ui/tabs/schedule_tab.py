from typing import List, Tuple
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QFileDialog, QMessageBox
)
from PySide6.QtCore import Signal

from src.matriculaup.models.course import Course, Section
from src.matriculaup.ui.components.timetable_grid import TimetableGrid

class ScheduleTab(QWidget):
    # Pass the event upwards to the main AppWindow
    section_removed = Signal(Course, Section)

    def __init__(self, parent=None):
        super().__init__(parent)
        
        layout = QVBoxLayout(self)
        
        # Top bar: conflict warning + export button
        top_bar = QHBoxLayout()
        
        self.warning_label = QLabel("")
        self.warning_label.setStyleSheet("color: red; font-weight: bold;")
        top_bar.addWidget(self.warning_label, stretch=1)
        
        export_btn = QPushButton("📷 Exportar Horario a PNG")
        export_btn.setFixedWidth(210)
        export_btn.clicked.connect(self._on_export)
        top_bar.addWidget(export_btn)
        
        layout.addLayout(top_bar)
        
        # Timetable Grid
        self.grid = TimetableGrid(self)
        self.grid.section_removed.connect(self.section_removed.emit)
        layout.addWidget(self.grid)

    def update_schedule(self, selected: List[Tuple[Course, Section]], conflicts: List[Tuple[Course, Course]]):
        """Updates the grid and shows warnings if there are conflicts."""
        if conflicts:
            msgs = [f"Cruce: {c1.codigo} y {c2.codigo}" for c1, c2 in conflicts]
            self.warning_label.setText(" | ".join(msgs))
        else:
            self.warning_label.setText("")
            
        self.grid.set_sections(selected)

    def _on_export(self):
        """Open a save-file dialog then render the grid to PNG."""
        filepath, _ = QFileDialog.getSaveFileName(
            self,
            "Exportar Horario",
            "horario_2026-1.png",
            "Imágenes PNG (*.png)"
        )
        if not filepath:
            return  # user cancelled
        
        ok = self.grid.export_to_png(filepath)
        if ok:
            QMessageBox.information(self, "Exportación exitosa", f"Horario guardado en:\n{filepath}")
        else:
            QMessageBox.warning(self, "Error", "No se pudo exportar el horario. Intenta de nuevo.")


