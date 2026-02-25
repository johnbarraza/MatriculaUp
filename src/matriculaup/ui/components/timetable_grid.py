from typing import List, Tuple
from PySide6.QtWidgets import QWidget
from PySide6.QtGui import QPainter, QColor, QFont, QPen, QBrush
from PySide6.QtCore import Qt, QRectF, Signal

from src.matriculaup.models.course import Course, Section, Session

class TimetableGrid(QWidget):
    
    # Emit when a block is middle-clicked or right-clicked for removal
    section_removed = Signal(Course, Section)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(600, 600)
        
        self.days = ["LUN", "MAR", "MIE", "JUE", "VIE", "SAB"]
        self.start_hour = 7   # 7:00 AM
        self.end_hour = 23    # 11:00 PM (23:00)
        
        self.header_height = 40
        self.time_col_width = 50
        
        self.selected_sections: List[Tuple[Course, Section]] = []
        
        # Simple color palette for assigning to courses
        self.palette = [
            QColor(230, 240, 255), QColor(255, 230, 230), QColor(230, 255, 230),
            QColor(255, 245, 230), QColor(245, 230, 255), QColor(230, 255, 250)
        ]

    def set_sections(self, sections: List[Tuple[Course, Section]]):
        """Update the internal state and trigger a repaint."""
        self.selected_sections = sections
        self.update()  # Queues a paintEvent

    def _time_to_y(self, time_str: str, row_height: float) -> float:
        """Converts an HH:MM string to a Y-coordinate on the canvas based on start_hour."""
        try:
            h, m = map(int, time_str.split(':'))
            # Total hours since self.start_hour
            hours_elapsed = (h - self.start_hour) + (m / 60.0)
            return self.header_height + (hours_elapsed * row_height)
        except ValueError:
            return self.header_height

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)
        
        width = self.width()
        height = self.height()
        
        # Calculate dimensions
        col_width = (width - self.time_col_width) / len(self.days)
        total_hours = self.end_hour - self.start_hour
        row_height = (height - self.header_height) / total_hours
        
        # 1. Background Fill
        painter.fillRect(0, 0, width, height, Qt.white)
        
        # 2. Draw Headers (Days)
        painter.setPen(QPen(Qt.black))
        painter.setFont(QFont("Arial", 10, QFont.Bold))
        for i, day in enumerate(self.days):
            x = self.time_col_width + (i * col_width)
            rect = QRectF(x, 0, col_width, self.header_height)
            painter.drawText(rect, Qt.AlignCenter, day)
            
        # 3. Draw Time Rows & Grid Lines
        painter.setFont(QFont("Arial", 8))
        for hour in range(self.start_hour, self.end_hour + 1):
            y = self.header_height + ((hour - self.start_hour) * row_height)
            
            # Time Label
            label = f"{hour:02d}:00"
            rect = QRectF(0, y - 10, self.time_col_width - 5, 20)
            painter.drawText(rect, Qt.AlignRight | Qt.AlignVCenter, label)
            
            # Horizontal Line (solid for hours)
            painter.setPen(QPen(Qt.lightGray, 1, Qt.SolidLine))
            painter.drawLine(self.time_col_width, y, width, y)
            
            # Half-hour line (dashed)
            y_half = y + (row_height / 2)
            if hour < self.end_hour:
                painter.setPen(QPen(Qt.lightGray, 1, Qt.DashLine))
                painter.drawLine(self.time_col_width, y_half, width, y_half)
                
        # Draw Vertical Grid Lines
        painter.setPen(QPen(Qt.lightGray, 1, Qt.SolidLine))
        painter.drawLine(self.time_col_width, 0, self.time_col_width, height)
        for i in range(1, len(self.days)):
            x = self.time_col_width + (i * col_width)
            painter.drawLine(x, 0, x, height)

        # 4. Draw Selected Course Sessions
        painter.setPen(QPen(Qt.black, 1))
        
        for idx, (course, section) in enumerate(self.selected_sections):
            bg_color = self.palette[idx % len(self.palette)]
            
            for session in section.sesiones:
                if session.dia not in self.days:
                    continue
                    
                day_idx = self.days.index(session.dia)
                
                # Calculate coordinates
                x = self.time_col_width + (day_idx * col_width)
                y_start = self._time_to_y(session.hora_inicio, row_height)
                y_end = self._time_to_y(session.hora_fin, row_height)
                
                block_height = y_end - y_start
                
                # Draw Box
                rect = QRectF(x + 2, y_start, col_width - 4, block_height)
                painter.setBrush(QBrush(bg_color))
                painter.drawRoundedRect(rect, 4, 4)
                
                # Draw Text (Course Code, Type, Room)
                painter.setPen(QPen(Qt.black))
                painter.setFont(QFont("Arial", 8, QFont.Bold))
                text_rect = rect.adjusted(4, 4, -4, -4)
                
                info = f"{course.codigo}\nSec {section.seccion}\n{session.tipo.value}\n{session.aula}"
                painter.drawText(text_rect, Qt.AlignTop | Qt.AlignLeft | Qt.TextWordWrap, info)

    def mousePressEvent(self, event):
        """Detect right-clicks to remove a course block."""
        if event.button() == Qt.RightButton:
            pos = event.position()
            x = pos.x()
            y = pos.y()
            
            # Recalculate dimensions identically to paintEvent
            width = self.width()
            height = self.height()
            col_width = (width - self.time_col_width) / len(self.days)
            total_hours = self.end_hour - self.start_hour
            row_height = (height - self.header_height) / total_hours
            
            # Find which block was clicked
            for course, section in self.selected_sections:
                for session in section.sesiones:
                    if session.dia not in self.days:
                        continue
                    
                    day_idx = self.days.index(session.dia)
                    block_x = self.time_col_width + (day_idx * col_width)
                    y_start = self._time_to_y(session.hora_inicio, row_height)
                    y_end = self._time_to_y(session.hora_fin, row_height)
                    
                    # Check if click is inside this session's block
                    if block_x <= x <= block_x + col_width and y_start <= y <= y_end:
                        self.section_removed.emit(course, section)
                        return

    def export_to_png(self, filepath: str) -> bool:
        """
        Renders the current timetable grid to a PNG file.
        Uses self.grab() to capture the exact on-screen widget content.
        Returns True on success, False on failure.
        """
        try:
            pixmap = self.grab()
            return pixmap.save(filepath, "PNG")
        except Exception as e:
            print(f"Export error: {e}")
            return False

