import re
from typing import List, Optional
from PySide6.QtWidgets import QTreeView, QMenu, QHeaderView
from PySide6.QtGui import QStandardItemModel, QStandardItem, QAction
from PySide6.QtCore import Qt, Signal

from src.matriculaup.models.course import Course, Section

class CourseTree(QTreeView):
    # Emit signal when a section is selected to be added to the schedule
    section_added = Signal(Course, Section)

    def __init__(self, courses: List[Course]):
        super().__init__()
        self.courses = courses
        self.all_courses = courses
        
        self.model = QStandardItemModel()
        self.model.setHorizontalHeaderLabels(["Curso / Sección", "Código", "Créditos", "Docentes", "Observaciones"])
        self.setModel(self.model)
        
        # Configure the TreeView appearance
        self.setEditTriggers(QTreeView.NoEditTriggers)
        self.setSelectionBehavior(QTreeView.SelectRows)
        self.setAlternatingRowColors(True)
        self.header().setSectionResizeMode(0, QHeaderView.ResizeToContents)
        
        # Add context menu
        self.setContextMenuPolicy(Qt.CustomContextMenu)
        self.customContextMenuRequested.connect(self._show_context_menu)
        
        self.populate_tree(self.courses)

    def populate_tree(self, courses: List[Course]):
        """Populates the QTreeView with a hierarchical view of Courses -> Sections."""
        self.model.removeRows(0, self.model.rowCount())
        
        for course in courses:
            # Create the Course (Parent) level item
            course_item = QStandardItem(f"{course.nombre}")
            course_item.setData(course, Qt.UserRole)  # Store the object for reference
            
            code_item = QStandardItem(course.codigo)
            credits_item = QStandardItem(course.creditos)
            empty_item1 = QStandardItem("")
            empty_item2 = QStandardItem("")
            
            # Make the course level bold
            font = course_item.font()
            font.setBold(True)
            course_item.setFont(font)
            code_item.setFont(font)
            credits_item.setFont(font)

            # Add the row to the root model
            self.model.appendRow([course_item, code_item, credits_item, empty_item1, empty_item2])
            
            # Create the Section (Child) level items
            for section in course.secciones:
                section_item = QStandardItem(f"Sección {section.seccion}")
                section_item.setData(section, Qt.UserRole) # Store object for reference
                
                s_empty1 = QStandardItem("")
                s_empty2 = QStandardItem("")
                
                docentes = " / ".join(section.docentes) if section.docentes else "No asignado"
                docentes_item = QStandardItem(docentes)
                
                obs_item = QStandardItem(section.observaciones)
                
                course_item.appendRow([section_item, s_empty1, s_empty2, docentes_item, obs_item])

    def filter_tree(self, search_text: str):
        """Filters the displayed courses by matching the search_text against name, code, or professor."""
        if not search_text.strip():
            self.populate_tree(self.all_courses)
            return
            
        search_text = search_text.lower()
        filtered_courses = []
        
        for course in self.all_courses:
            match_found = False
            
            # Check course-level fields
            if search_text in course.nombre.lower() or search_text in course.codigo.lower():
                match_found = True
            else:
                # Check section-level fields (like professors)
                for section in course.secciones:
                    for doc in section.docentes:
                        if search_text in doc.lower():
                            match_found = True
                            break
                    if match_found:
                        break
                        
            if match_found:
                filtered_courses.append(course)
                
        self.populate_tree(filtered_courses)
        
        # When filtering, expanding all can make results easier to see
        if len(filtered_courses) < 20:
            self.expandAll()

    def _show_context_menu(self, position):
        """Builds and displays the context menu when right-clicking an item."""
        index = self.indexAt(position)
        if not index.isValid():
            return
            
        item = self.model.itemFromIndex(index)
        
        # Data is stored in UserRole on the first column of each row
        first_col_idx = index.sibling(index.row(), 0)
        first_col_item = self.model.itemFromIndex(first_col_idx)
        data = first_col_item.data(Qt.UserRole)
        
        # Only show action if the user right-clicked a Section
        if isinstance(data, Section):
            menu = QMenu()
            add_action = QAction("Agregar al horario", self)
            
            # Find the parent Course object
            parent_item = first_col_item.parent()
            course_data = parent_item.data(Qt.UserRole)
            
            add_action.triggered.connect(lambda: self._trigger_section_added(course_data, data))
            menu.addAction(add_action)
            menu.exec(self.viewport().mapToGlobal(position))
            
    def _trigger_section_added(self, course: Course, section: Section):
        """Emits the signal that a section was chosen."""
        self.section_added.emit(course, section)
