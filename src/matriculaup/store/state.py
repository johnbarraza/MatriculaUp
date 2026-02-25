from typing import List, Tuple
from PySide6.QtCore import QObject, Signal

from matriculaup.models.course import Course, Section

class ScheduleState(QObject):
    # This signal will trigger every time the state modifies
    # Signature means it emits the entire (Course, Section) list
    on_sections_changed = Signal(list)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.sections: List[Tuple[Course, Section]] = []
        
    def add_section(self, course: Course, section: Section):
        # Prevent adding the exact same section twice
        for c, s in self.sections:
            if c.codigo == course.codigo and s.seccion == section.seccion:
                return # Already exists
                
        self.sections.append((course, section))
        self.on_sections_changed.emit(self.sections)
        
    def remove_section(self, course_codigo: str, section_seccion: str):
        # Filtering out the designated section
        initial_length = len(self.sections)
        self.sections = [
            (c, s) for c, s in self.sections
            if not (c.codigo == course_codigo and s.seccion == section_seccion)
        ]
        
        # Only emit if a change actually occurred
        if len(self.sections) != initial_length:
            self.on_sections_changed.emit(self.sections)
            
    def get_sections(self) -> List[Tuple[Course, Section]]:
        return self.sections
