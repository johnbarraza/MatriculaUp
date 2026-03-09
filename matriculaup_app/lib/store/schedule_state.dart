// matriculaup_app/lib/store/schedule_state.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../models/curriculum.dart';
import '../models/calendar_event.dart';
import '../utils/time_utils.dart';

const _kSessionKey = 'session_v1';

class CourseSelection {
  final Course course;
  final Section section;

  CourseSelection({required this.course, required this.section});
}

class ScheduleState extends ChangeNotifier {
  // ── Persistence ───────────────────────────────────────────────────────────
  /// True once loadSession() has completed. Saves are blocked until then to
  /// avoid overwriting a valid session with empty data on cold start.
  bool _initialized = false;
  Timer? _saveTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_initialized) _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _saveSession);
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode({
        'activeIdx': _activeScheduleIndex,
        'maxCredits': maxCredits,
        'schedules': List.generate(
          3,
          (i) => {
            'sels': _schedules[i]
                .map((s) => {'code': s.course.codigo, 'sec': s.section.seccion})
                .toList(),
            'hidden': _hiddenCourses[i].toList(),
            'locked': _lockedCourses[i].toList(),
          },
        ),
      });
      await prefs.setString(_kSessionKey, data);
    } catch (_) {
      // Non-critical — ignore save errors
    }
  }

  /// Restores the last session from storage. Must be called after
  /// allVisibleCourses is populated. Sets _initialized = true when done.
  Future<void> loadSession(List<Course> allCourses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;

        final maxC = json['maxCredits'] as int?;
        if (maxC != null) maxCredits = maxC;

        final activeIdx = json['activeIdx'] as int?;
        if (activeIdx != null && activeIdx >= 0 && activeIdx < 3) {
          _activeScheduleIndex = activeIdx;
        }

        final schedulesJson = json['schedules'] as List<dynamic>?;
        if (schedulesJson != null) {
          for (int i = 0; i < schedulesJson.length && i < 3; i++) {
            final sMap = schedulesJson[i] as Map<String, dynamic>;

            final hidden = sMap['hidden'] as List<dynamic>?;
            if (hidden != null) {
              _hiddenCourses[i] = Set<String>.from(hidden.cast<String>());
            }

            final locked = sMap['locked'] as List<dynamic>?;
            if (locked != null) {
              _lockedCourses[i] = Set<String>.from(locked.cast<String>());
            }

            final sels = sMap['sels'] as List<dynamic>?;
            if (sels != null) {
              for (final sel in sels) {
                final m = sel as Map<String, dynamic>;
                final code = m['code'] as String?;
                final secId = m['sec'] as String?;
                if (code == null || secId == null) continue;

                Course? course;
                for (final c in allCourses) {
                  if (c.codigo == code) {
                    course = c;
                    break;
                  }
                }
                if (course == null) continue;

                Section? section;
                for (final s in course.secciones) {
                  if (s.seccion == secId) {
                    section = s;
                    break;
                  }
                }
                if (section == null) continue;

                _schedules[i].add(
                  CourseSelection(course: course, section: section),
                );
              }
            }
          }
        }
      }
    } catch (_) {
      // Start fresh on any error
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Wipes the saved session (used from Settings).
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
    } catch (_) {}
  }

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

  // ── EFE Course data ───────────────────────────────────────────────────────
  List<Course> _efeCourses = [];
  List<Course> get efeCourses => _efeCourses;

  String? _efeCoursesLabel;
  String? get efeCoursesLabel => _efeCoursesLabel;

  void setEfeCourses(List<Course> courses, {String? label}) {
    _efeCourses = courses;
    _efeCoursesLabel = label;
    notifyListeners();
  }

  void clearEfeCourses() {
    _efeCourses = [];
    _efeCoursesLabel = null;
    notifyListeners();
  }

  /// Combined list of regular + EFE courses for search and display.
  List<Course> get allVisibleCourses => [..._allCourses, ..._efeCourses];

  // ── Academic Calendar ────────────────────────────────────────────────────
  AcademicCalendar? _calendar;
  AcademicCalendar? get calendar => _calendar;

  void setCalendar(AcademicCalendar? cal) {
    _calendar = cal;
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

  /// Total weekly gap hours between CLASE/PRÁCTICA sessions on the same day.
  /// A "gap" is any dead time between two non-adjacent sessions on the same day
  /// (e.g. class ends 11:00, next class starts 15:00 → 4 h gap).
  double get weeklyGapHours {
    final claseTypes = {SessionType.clase, SessionType.practica};

    // Collect all relevant sessions grouped by day
    final Map<String, List<(int start, int end)>> byDay = {};
    for (final sel in selectedSections) {
      for (final session in sel.section.sesiones) {
        if (!claseTypes.contains(session.tipo)) continue;
        final start = TimeUtils.timeToMinutes(session.horaInicio);
        final end = TimeUtils.timeToMinutes(session.horaFin);
        byDay.putIfAbsent(session.dia, () => []).add((start, end));
      }
    }

    double totalGapMins = 0;
    for (final slots in byDay.values) {
      // Sort by start time
      slots.sort((a, b) => a.$1.compareTo(b.$1));
      // Sum gaps between consecutive sessions
      for (int i = 1; i < slots.length; i++) {
        final gap = slots[i].$1 - slots[i - 1].$2;
        if (gap > 0) totalGapMins += gap;
      }
    }
    return totalGapMins / 60.0;
  }

  /// Number of days (LUN-SAB) that have at least one regular session.
  int get classDaysCount {
    const summaryDays = {'LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'};
    final daysWithClasses = <String>{};

    for (final sel in selectedSections) {
      for (final session in sel.section.sesiones) {
        if (!_regularTypes.contains(session.tipo)) continue;
        final day = session.dia.toUpperCase().trim();
        if (summaryDays.contains(day)) {
          daysWithClasses.add(day);
        }
      }
    }
    return daysWithClasses.length;
  }

  /// Number of free days (LUN-SAB) without regular sessions.
  int get freeDaysCount => 6 - classDaysCount;

  void setMaxCredits(int limit) {
    maxCredits = limit;
    notifyListeners();
  }

  // ── Multiple Schedules (Plan A / B / C) ──────────────────────────────────
  /// 3 independent sections lists: index 0 = Plan A, 1 = Plan B, 2 = Plan C.
  final List<List<CourseSelection>> _schedules = [[], [], []];
  final List<Set<String>> _hiddenCourses = [{}, {}, {}];
  final List<Set<String>> _lockedCourses = [{}, {}, {}];
  int _activeScheduleIndex = 0;

  int get activeScheduleIndex => _activeScheduleIndex;

  void switchSchedule(int index) {
    assert(index >= 0 && index < _schedules.length);
    _activeScheduleIndex = index;
    notifyListeners();
  }

  List<CourseSelection> get selectedSections =>
      _schedules[_activeScheduleIndex];

  bool isCourseHidden(String courseCode) =>
      _hiddenCourses[_activeScheduleIndex].contains(courseCode);

  Set<String> get lockedCourseCodes =>
      Set<String>.from(_lockedCourses[_activeScheduleIndex]);

  bool isCourseLocked(String courseCode) =>
      _lockedCourses[_activeScheduleIndex].contains(courseCode);

  void toggleCourseLock(String courseCode) {
    if (!_lockedCourses[_activeScheduleIndex].remove(courseCode)) {
      _lockedCourses[_activeScheduleIndex].add(courseCode);
    }
    notifyListeners();
  }

  void toggleCourseVisibility(String courseCode) {
    if (!_hiddenCourses[_activeScheduleIndex].remove(courseCode)) {
      _hiddenCourses[_activeScheduleIndex].add(courseCode);
    }
    notifyListeners();
  }

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
    _hiddenCourses[_activeScheduleIndex].remove(course.codigo);
    _lockedCourses[_activeScheduleIndex].remove(course.codigo);
    notifyListeners();
  }

  /// Replaces the active plan with [selections] in one operation.
  /// Intended for schedule generators/explorers that produce full combinations.
  void replaceActiveSchedule(List<CourseSelection> selections) {
    _schedules[_activeScheduleIndex] = List<CourseSelection>.from(selections);
    _hiddenCourses[_activeScheduleIndex].clear();
    _lockedCourses[_activeScheduleIndex].removeWhere(
      (code) => !selections.any((sel) => sel.course.codigo == code),
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
  static const _fixedExamTypes = {SessionType.parcial, SessionType.finalExam};

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
