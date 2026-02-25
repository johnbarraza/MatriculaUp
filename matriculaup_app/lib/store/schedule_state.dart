// matriculaup_app/lib/store/schedule_state.dart
import 'package:flutter/foundation.dart';
import '../models/course.dart';

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
}
