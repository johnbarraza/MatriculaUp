// matriculaup_app/lib/store/schedule_state.dart
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../utils/time_utils.dart';

class CourseSelection {
  final Course course;
  final Section section;

  CourseSelection({required this.course, required this.section});
}

class ScheduleState extends ChangeNotifier {
  List<Course> _allCourses = [];
  final List<CourseSelection> _selectedSections = [];

  List<Course> get allCourses => _allCourses;
  List<CourseSelection> get selectedSections => _selectedSections;

  void setCourses(List<Course> courses) {
    _allCourses = courses;
    notifyListeners();
  }

  void addSection(Course course, Section section) {
    // Prevent adding the same course twice
    if (_selectedSections.any((s) => s.course.codigo == course.codigo)) {
      throw Exception('El curso ya está en el horario.');
    }

    _selectedSections.add(CourseSelection(course: course, section: section));
    notifyListeners();
  }

  void removeSection(Course course, Section section) {
    _selectedSections.removeWhere(
      (selection) =>
          selection.course.codigo == course.codigo &&
          selection.section.seccion == section.seccion,
    );
    notifyListeners();
  }

  /// Returns true if the given section overlaps with any already selected section.
  bool conflictsWithSchedule(Section section) {
    for (var currentSelection in _selectedSections) {
      for (var newSession in section.sesiones) {
        for (var currentSession in currentSelection.section.sesiones) {
          if (newSession.dia == currentSession.dia) {
            if (TimeUtils.hasOverlap(
              newSession.horaInicio,
              newSession.horaFin,
              currentSession.horaInicio,
              currentSession.horaFin,
            )) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }
}
