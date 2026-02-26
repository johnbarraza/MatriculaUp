// matriculaup_app/lib/store/schedule_state.dart
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
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

  // ── Curriculum (Plan de Estudios) ────────────────────────────────────────
  Curriculum? _curriculum;
  Curriculum? get curriculum => _curriculum;

  void setCurriculum(Curriculum? curriculum) {
    _curriculum = curriculum;
    notifyListeners();
  }

  // ── Credit Limit ─────────────────────────────────────────────────────────
  int maxCredits = 25;

  int get currentCredits => selectedSections.fold(0, (sum, sel) {
    final parsed = double.tryParse(sel.course.creditos) ?? 0.0;
    return sum + parsed.round();
  });

  /// Total weekly hours of CLASE + PRÁCTICA sessions in the current schedule.
  /// Each session's duration is (horaFin - horaInicio) in hours, rounded to 0.5.
  double get weeklyHours {
    double total = 0;
    final claseTypes = {SessionType.clase, SessionType.practica};
    for (final sel in selectedSections) {
      for (final session in sel.section.sesiones) {
        if (claseTypes.contains(session.tipo)) {
          final mins = TimeUtils.durationMinutes(
            session.horaInicio,
            session.horaFin,
          );
          total += mins / 60.0;
        }
      }
    }
    return total;
  }

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
  /// Determines if two session types belong to the same academic week
  /// and therefore can clash.
  bool _canConflict(Session s1, Session s2) {
    bool isS1Exam = s1.tipo == 'PARCIAL' || s1.tipo == 'FINAL';
    bool isS2Exam = s2.tipo == 'PARCIAL' || s2.tipo == 'FINAL';

    // Both are regular classes -> YES
    if (!isS1Exam && !isS2Exam) return true;

    // Both are exams -> Only conflict if they are the SAME type of exam
    if (isS1Exam && isS2Exam) return s1.tipo == s2.tipo;

    // One is regular, one is exam (they happen in different weeks) -> NO
    return false;
  }

  /// Returns true if the given section overlaps with any session in the current plan.
  bool conflictsWithSchedule(Section section) {
    for (var currentSel in selectedSections) {
      for (var newSession in section.sesiones) {
        for (var currentSession in currentSel.section.sesiones) {
          if (!_canConflict(newSession, currentSession)) continue;

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

  /// Checks if [section] conflicts with currently selected sections and returns
  /// the name of the conflicting course, or null if there is no conflict.
  String? getConflictReason(Section section) {
    for (var currentSel in selectedSections) {
      for (var newSession in section.sesiones) {
        for (var currentSession in currentSel.section.sesiones) {
          if (!_canConflict(newSession, currentSession)) continue;

          if (newSession.dia == currentSession.dia) {
            if (TimeUtils.hasOverlap(
              newSession.horaInicio,
              newSession.horaFin,
              currentSession.horaInicio,
              currentSession.horaFin,
            )) {
              return currentSel.course.nombre;
            }
          }
        }
      }
    }
    return null;
  }

  // ── Free-Time Selection (Grid Drag) ───────────────────────────────────────
  /// Maps a day (e.g. 'LUN') to a set of hours (e.g. {9, 10, 11}) that the user
  /// has selected on the grid as "preferred times".
  final Map<String, Set<int>> selectedTimeSlots = {};

  void toggleTimeSlot(String day, int hour, bool isSelected) {
    if (isSelected) {
      selectedTimeSlots.putIfAbsent(day, () => {}).add(hour);
    } else {
      selectedTimeSlots[day]?.remove(hour);
      if (selectedTimeSlots[day]?.isEmpty ?? false) {
        selectedTimeSlots.remove(day);
      }
    }
    notifyListeners();
  }

  void clearTimeSlots() {
    selectedTimeSlots.clear();
    notifyListeners();
  }

  bool isTimeSlotSelected(String day, int hour) {
    return selectedTimeSlots[day]?.contains(hour) ?? false;
  }

  /// Returns true if the user has at least one active time slot selection.
  bool get hasTimeSlotSelection => selectedTimeSlots.isNotEmpty;

  /// Returns true if ALL sessions of [section] fall entirely within the selected
  /// time slots. If no slots are selected, returns true (no restriction).
  bool fitsInSelectedTimeSlots(Section section) {
    if (!hasTimeSlotSelection) return true;

    for (var session in section.sesiones) {
      final startHour = TimeUtils.timeToMinutes(session.horaInicio) ~/ 60;
      final endHour =
          (TimeUtils.timeToMinutes(session.horaFin) - 1) ~/
          60; // -1 to not count exact end hour if it's :00

      for (int h = startHour; h <= endHour; h++) {
        if (!isTimeSlotSelected(session.dia, h)) {
          return false; // Found an hour that wasn't selected
        }
      }
    }
    return true; // All hours across all sessions were selected
  }
}
