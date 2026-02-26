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

  String? _coursesLabel;
  String? get coursesLabel => _coursesLabel;

  void setCourses(List<Course> courses, {String? label}) {
    _allCourses = courses;
    _coursesLabel = label;
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

  /// Session types that represent regular academic weeks (classes/labs).
  static const _regularTypes = {
    SessionType.clase,
    SessionType.practica,
    SessionType.pracDirigida,
    SessionType.pracCalificada,
    SessionType.laboratorio,
  };

  /// Session types that represent fixed exam weeks (parcial/final).
  static const _fixedExamTypes = {
    SessionType.parcial,
    SessionType.finalExam,
  };

  /// Determines if two sessions can possibly clash.
  ///
  /// Rules:
  /// - CANCELADA: always ignored (no conflict with anything).
  /// - EXSUSTITUTORIO / EXREZAGADO: shown on the timetable but never block
  ///   adding a course (their schedule is provisional).
  /// - Regular (CLASE/PRÁCTICA/…) vs Regular → check overlap.
  /// - Exam (PARCIAL/FINAL) vs same exam type → check overlap.
  /// - Regular vs Exam → never conflict (different weeks).
  /// - PARCIAL vs FINAL → never conflict (different exam weeks).
  bool _canConflict(Session s1, Session s2) {
    // Sessions that never block anything
    const neverConflict = {
      SessionType.cancelada,
      SessionType.exSustitutorio,
      SessionType.exRezagado,
      SessionType.unknown,
    };
    if (neverConflict.contains(s1.tipo) || neverConflict.contains(s2.tipo)) {
      return false;
    }

    final s1Regular = _regularTypes.contains(s1.tipo);
    final s2Regular = _regularTypes.contains(s2.tipo);

    // Both regular → can conflict
    if (s1Regular && s2Regular) return true;

    final s1Exam = _fixedExamTypes.contains(s1.tipo);
    final s2Exam = _fixedExamTypes.contains(s2.tipo);

    // Both fixed exams → only conflict if same exam type (PARCIAL≠FINAL week)
    if (s1Exam && s2Exam) return s1.tipo == s2.tipo;

    // Cross-bucket (regular vs exam) → different weeks, no conflict
    return false;
  }

  /// Returns true if [section] has any EXSUSTITUTORIO or EXREZAGADO session.
  /// Used to show a UI warning that those exam slots are provisional.
  bool hasFlexibleExam(Section section) {
    return section.sesiones.any(
      (s) =>
          s.tipo == SessionType.exSustitutorio ||
          s.tipo == SessionType.exRezagado,
    );
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
