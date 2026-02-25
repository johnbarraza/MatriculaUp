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
  // ── Course data ──────────────────────────────────────────────────────────
  List<Course> _allCourses = [];
  List<Course> get allCourses => _allCourses;

  void setCourses(List<Course> courses) {
    _allCourses = courses;
    notifyListeners();
  }

  // ── Credit Limit ─────────────────────────────────────────────────────────
  int maxCredits = 25;

  int get currentCredits => selectedSections.fold(0, (sum, sel) {
    final parsed = double.tryParse(sel.course.creditos) ?? 0.0;
    return sum + parsed.round();
  });

  void setMaxCredits(int limit) {
    maxCredits = limit;
    notifyListeners();
  }

  // ── Multiple Schedules (Plan A / B / C) ──────────────────────────────────
  /// 3 independent sections lists: index 0 = Plan A, 1 = Plan B, 2 = Plan C.
  final List<List<CourseSelection>> _schedules = [[], [], []];
  int _activeScheduleIndex = 0;

  int get activeScheduleIndex => _activeScheduleIndex;

  void switchSchedule(int index) {
    assert(index >= 0 && index < _schedules.length);
    _activeScheduleIndex = index;
    notifyListeners();
  }

  List<CourseSelection> get selectedSections =>
      _schedules[_activeScheduleIndex];

  // ── Add / Remove ─────────────────────────────────────────────────────────
  void addSection(Course course, Section section) {
    // Prevent same course twice in active plan
    if (selectedSections.any((s) => s.course.codigo == course.codigo)) {
      throw Exception('El curso ya está en el horario.');
    }

    // Prevent time conflict
    if (conflictsWithSchedule(section)) {
      throw Exception('Esta sección tiene cruce de horarios.');
    }

    // Enforce credit limit
    final newCredits = int.tryParse(course.creditos) ?? 0;
    if (currentCredits + newCredits > maxCredits) {
      throw Exception(
        'Límite de créditos alcanzado ($currentCredits / $maxCredits).',
      );
    }

    _schedules[_activeScheduleIndex].add(
      CourseSelection(course: course, section: section),
    );
    notifyListeners();
  }

  void removeSection(Course course, Section section) {
    _schedules[_activeScheduleIndex].removeWhere(
      (sel) =>
          sel.course.codigo == course.codigo &&
          sel.section.seccion == section.seccion,
    );
    notifyListeners();
  }

  // ── Conflict Check ───────────────────────────────────────────────────────
  /// Returns true if the given section overlaps with any session in the current plan.
  bool conflictsWithSchedule(Section section) {
    for (var currentSel in selectedSections) {
      for (var newSession in section.sesiones) {
        for (var currentSession in currentSel.section.sesiones) {
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

  // ── Free-Time Preferences ─────────────────────────────────────────────────
  /// Optional preferred start/end bounds (in "HH:MM" format).
  /// If set, sessions outside these hours count as conflicts.
  String? preferredStart; // e.g. "09:00"
  String? preferredEnd; // e.g. "17:00"

  void setFreeTimePrefs(String? start, String? end) {
    preferredStart = start;
    preferredEnd = end;
    notifyListeners();
  }

  /// Returns true if ANY session of [section] falls outside the preferred window.
  bool conflictsWithFreeTimePrefs(Section section) {
    final ps = preferredStart;
    final pe = preferredEnd;
    if (ps == null || pe == null) return false;

    for (var session in section.sesiones) {
      // Session starts before preferred window begins
      if (TimeUtils.timeToMinutes(session.horaInicio) <
          TimeUtils.timeToMinutes(ps)) {
        return true;
      }
      // Session ends after preferred window ends
      if (TimeUtils.timeToMinutes(session.horaFin) >
          TimeUtils.timeToMinutes(pe)) {
        return true;
      }
    }
    return false;
  }
}
