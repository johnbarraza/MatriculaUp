from typing import List, Tuple
from PySide6.QtWidgets import QWidget, QVBoxLayout, QLabel

from src.matriculaup.models.course import Course, Section
from src.matriculaup.ui.components.timetable_grid import TimetableGrid

class ScheduleTab(QWidget):
    def __init__(self, parent=None):
        super().__init__(parent)
        
        layout = QVBoxLayout(self)
        
        # Header/Warning Bar
        self.warning_label = QLabel("")
        self.warning_label.setStyleSheet("color: red; font-weight: bold;")
        layout.addWidget(self.warning_label)
        
        # Timetable Grid
        self.grid = TimetableGrid(self)
        layout.addWidget(self.grid)

    def update_schedule(self, selected: List[Tuple[Course, Section]], conflicts: List[Tuple[Course, Course]]):
        """Updates the grid and shows warnings if there are conflicts."""
        if conflicts:
            # Build warning message
            msgs = []
            for c1, c2 in conflicts:
                msgs.append(f"Cruce: {c1.codigo} y {c2.codigo}")
            self.warning_label.setText(" | ".join(msgs))
        else:
            self.warning_label.setText("")
            
        # Draw on grid
        self.grid.set_sections(selected)
