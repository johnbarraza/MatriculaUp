// matriculaup_app/lib/utils/ics_exporter.dart
import 'dart:convert';
import 'dart:typed_data';

import '../models/course.dart';
import '../models/calendar_event.dart';
import '../store/schedule_state.dart';

/// Generates a complete iCalendar (.ics) file from the current schedule.
///
/// Structure:
/// 1. All-day banner events for each exam period (e.g. "📝 Semana de Parciales")
/// 2. All-day holiday events (tipo: libre)
/// 3. Regular weekly sessions (CLASE/PRÁCTICA/LAB/…) split into RRULE segments
///    that skip exam weeks — so no classes appear during parciales/finales.
/// 4. Individual exam events (PARCIAL/FINAL) — only for courses that have that
///    session type, anchored to the correct day within the exam period.
class IcsExporter {
  // ── Session type buckets ───────────────────────────────────────────────────

  static const _regularTypes = {
    SessionType.clase,
    SessionType.practica,
    SessionType.pracDirigida,
    SessionType.pracCalificada,
    SessionType.laboratorio,
  };

  static const _examTypes = {
    SessionType.parcial,
    SessionType.finalExam,
  };

  // ── Day-of-week mappings ───────────────────────────────────────────────────

  static const _dayToIcal = {
    'LUN': 'MO',
    'MAR': 'TU',
    'MIE': 'WE',
    'JUE': 'TH',
    'VIE': 'FR',
    'SAB': 'SA',
    'DOM': 'SU',
  };

  static const _dayToWeekday = {
    'LUN': DateTime.monday,
    'MAR': DateTime.tuesday,
    'MIE': DateTime.wednesday,
    'JUE': DateTime.thursday,
    'VIE': DateTime.friday,
    'SAB': DateTime.saturday,
    'DOM': DateTime.sunday,
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  static Uint8List generateBytes(
    List<CourseSelection> selections,
    AcademicCalendar? calendar,
  ) =>
      Uint8List.fromList(utf8.encode(generate(selections, calendar)));

  static String generate(
    List<CourseSelection> selections,
    AcademicCalendar? calendar,
  ) {
    final buf = StringBuffer();

    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//MatriculaUp//MatriculaUp//ES');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');
    buf.writeln('X-WR-CALNAME:Horario Académico MatriculaUp');
    buf.writeln('X-WR-TIMEZONE:America/Lima');

    // ── Parse semester bounds ──────────────────────────────────────────────
    final semStart = _parseDate(calendar?.inicioClases);
    final semEnd   = _parseDate(calendar?.finClases);

    // ── Build exam period descriptors from calendar ────────────────────────
    // allDayEnd is extended so the banner always covers a full 7-day week.
    // searchEnd is the same extended range used to find the matching weekday.
    final examPeriods = <_ExamPeriod>[];

    if (calendar != null) {
      for (final ev in calendar.eventos) {
        if (ev.tipo != CalendarEventType.examen) continue;
        final desc  = ev.descripcion.toUpperCase();
        final start = _parseDate(ev.inicio);
        if (start == null) continue;
        final rawEnd    = _parseDate(ev.fin) ?? start;
        // Guarantee a full 7-day search/banner window.
        final extEnd    = _laterOf(rawEnd, start.add(const Duration(days: 6)));

        SessionType? type;
        if (desc.contains('PARCIAL')) {
          type = SessionType.parcial;
        } else if (desc.contains('FINAL')) {
          type = SessionType.finalExam;
        }
        if (type == null) continue;

        examPeriods.add(_ExamPeriod(
          sessionType: type,
          label:       ev.descripcion,
          bannerStart: start,
          bannerEnd:   extEnd,     // inclusive – used for DTEND+1 in all-day
          searchStart: start,
          searchEnd:   extEnd,
        ));
      }
    }

    // ── 1. All-day exam-week banner events ─────────────────────────────────
    for (final ep in examPeriods) {
      final dtEnd = ep.bannerEnd.add(const Duration(days: 1)); // exclusive
      buf.writeln('BEGIN:VEVENT');
      buf.writeln('UID:matriculaup-examweek-${ep.sessionType.name}@matriculaup');
      buf.writeln('DTSTAMP:${_dtUtc(DateTime.now().toUtc())}Z');
      buf.writeln('DTSTART;VALUE=DATE:${_date(ep.bannerStart)}');
      buf.writeln('DTEND;VALUE=DATE:${_date(dtEnd)}');
      buf.writeln('SUMMARY:📝 ${ep.label}');
      buf.writeln('TRANSP:TRANSPARENT');
      buf.writeln('END:VEVENT');
    }

    // ── 2. All-day holiday events ──────────────────────────────────────────
    if (calendar != null) {
      for (final ev in calendar.eventos) {
        if (ev.tipo != CalendarEventType.libre) continue;
        final start = _parseDate(ev.inicio);
        if (start == null) continue;
        final end   = _parseDate(ev.fin) ?? start;
        final dtEnd = end.add(const Duration(days: 1)); // exclusive

        buf.writeln('BEGIN:VEVENT');
        buf.writeln('UID:matriculaup-holiday-${ev.inicio}@matriculaup');
        buf.writeln('DTSTAMP:${_dtUtc(DateTime.now().toUtc())}Z');
        buf.writeln('DTSTART;VALUE=DATE:${_date(start)}');
        buf.writeln('DTEND;VALUE=DATE:${_date(dtEnd)}');
        buf.writeln('SUMMARY:🎌 ${ev.descripcion}');
        buf.writeln('TRANSP:TRANSPARENT');
        buf.writeln('END:VEVENT');
      }
    }

    // ── Exam periods that fall within the semester (need RRULE splitting) ──
    final inSemesterExams = examPeriods
        .where((ep) =>
            semStart != null &&
            semEnd   != null &&
            !ep.bannerStart.isAfter(semEnd) &&
            !ep.bannerEnd.isBefore(semStart))
        .toList()
      ..sort((a, b) => a.bannerStart.compareTo(b.bannerStart));

    // ── 3 & 4. Course session events ──────────────────────────────────────
    int uid = 0;
    for (final sel in selections) {
      for (final session in sel.section.sesiones) {
        final isRegular = _regularTypes.contains(session.tipo);
        final isExam    = _examTypes.contains(session.tipo);
        if (!isRegular && !isExam) continue;

        final icalDay = _dayToIcal[session.dia.toUpperCase()];
        final weekday  = _dayToWeekday[session.dia.toUpperCase()];
        if (icalDay == null || weekday == null) continue;

        final sh = int.tryParse(session.horaInicio.split(':').firstOrNull ?? '') ?? 0;
        final sm = int.tryParse(session.horaInicio.split(':').lastOrNull  ?? '') ?? 0;
        final eh = int.tryParse(session.horaFin.split(':').firstOrNull    ?? '') ?? 0;
        final em = int.tryParse(session.horaFin.split(':').lastOrNull     ?? '') ?? 0;

        if (isRegular) {
          // ── Split RRULE around exam weeks ────────────────────────────────
          // Build a list of [DTSTART, UNTIL] segments that skip exam weeks.
          final segments = _buildSegments(
            semStart, semEnd, weekday, inSemesterExams,
          );

          for (final seg in segments) {
            uid++;
            final dtS = DateTime(seg.$1.year, seg.$1.month, seg.$1.day, sh, sm);
            final dtE = DateTime(seg.$1.year, seg.$1.month, seg.$1.day, eh, em);
            final until = _dtUtc(_endOfDay(seg.$2).toUtc());
            _writeEvent(
              buf: buf,
              uid: 'matriculaup-reg-$uid-${sel.course.codigo}',
              eventStart: dtS,
              eventEnd:   dtE,
              title: '${sel.course.nombre} (${session.tipo.value})',
              location:    session.aula,
              description: _desc(sel, session),
              rrule: 'RRULE:FREQ=WEEKLY;BYDAY=$icalDay;UNTIL=${until}Z',
            );
          }

          // Fallback: no calendar data → single open-ended RRULE
          if (segments.isEmpty && semStart == null) {
            uid++;
            final anchor = _nextWeekday(DateTime.now(), weekday);
            final dtS = DateTime(anchor.year, anchor.month, anchor.day, sh, sm);
            final dtE = DateTime(anchor.year, anchor.month, anchor.day, eh, em);
            _writeEvent(
              buf: buf,
              uid: 'matriculaup-reg-$uid-${sel.course.codigo}',
              eventStart: dtS,
              eventEnd:   dtE,
              title: '${sel.course.nombre} (${session.tipo.value})',
              location:    session.aula,
              description: _desc(sel, session),
              rrule: 'RRULE:FREQ=WEEKLY;BYDAY=$icalDay',
            );
          }
        } else {
          // ── Single exam event ────────────────────────────────────────────
          final ep = examPeriods
              .where((e) => e.sessionType == session.tipo)
              .firstOrNull;
          if (ep == null) continue;

          final examDate =
              _findWeekdayInRange(ep.searchStart, ep.searchEnd, weekday);
          if (examDate == null) continue;

          uid++;
          final dtS = DateTime(examDate.year, examDate.month, examDate.day, sh, sm);
          final dtE = DateTime(examDate.year, examDate.month, examDate.day, eh, em);

          _writeEvent(
            buf: buf,
            uid: 'matriculaup-exam-$uid-${sel.course.codigo}',
            eventStart: dtS,
            eventEnd:   dtE,
            title: '${sel.course.nombre} (${session.tipo.value})',
            location:    session.aula,
            description: _desc(sel, session),
          );
        }
      }
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  // ── Segment builder ────────────────────────────────────────────────────────

  /// Splits [semStart..semEnd] into RRULE segments that skip each exam period.
  /// Returns a list of (DTSTART date, UNTIL date) pairs.
  static List<(DateTime, DateTime)> _buildSegments(
    DateTime? semStart,
    DateTime? semEnd,
    int weekday,
    List<_ExamPeriod> sortedExams,
  ) {
    if (semStart == null || semEnd == null) return [];

    final segs = <(DateTime, DateTime)>[];
    DateTime cursor = semStart;

    for (final ep in sortedExams) {
      // Segment ends the day before this exam week begins.
      final segEnd = ep.bannerStart.subtract(const Duration(days: 1));
      if (!cursor.isAfter(segEnd)) {
        final first = _nextWeekday(cursor, weekday);
        if (!first.isAfter(segEnd)) segs.add((first, segEnd));
      }
      // Resume after exam week ends.
      cursor = ep.bannerEnd.add(const Duration(days: 1));
    }

    // Tail segment after the last exam period.
    if (!cursor.isAfter(semEnd)) {
      final first = _nextWeekday(cursor, weekday);
      if (!first.isAfter(semEnd)) segs.add((first, semEnd));
    }

    return segs;
  }

  // ── VEVENT writer ──────────────────────────────────────────────────────────

  static void _writeEvent({
    required StringBuffer buf,
    required String uid,
    required DateTime eventStart,
    required DateTime eventEnd,
    required String title,
    required String location,
    required String description,
    String? rrule,
  }) {
    buf.writeln('BEGIN:VEVENT');
    buf.writeln('UID:$uid@matriculaup');
    buf.writeln('DTSTAMP:${_dtUtc(DateTime.now().toUtc())}Z');
    buf.writeln('DTSTART;TZID=America/Lima:${_dt(eventStart)}');
    buf.writeln('DTEND;TZID=America/Lima:${_dt(eventEnd)}');
    if (rrule != null) buf.writeln(rrule);
    buf.writeln('SUMMARY:$title');
    if (location.isNotEmpty) buf.writeln('LOCATION:$location');
    buf.writeln('DESCRIPTION:$description');
    buf.writeln('END:VEVENT');
  }

  // ── Misc helpers ───────────────────────────────────────────────────────────

  static String _desc(CourseSelection sel, Session s) =>
      'Sección ${sel.section.seccion}\\n'
      'Docentes: ${sel.section.docentes.join(', ')}\\n'
      'Código: ${sel.course.codigo}\\n'
      'Tipo: ${s.tipo.value}';

  static DateTime _nextWeekday(DateTime from, int weekday) =>
      from.add(Duration(days: (weekday - from.weekday) % 7));

  static DateTime? _findWeekdayInRange(DateTime s, DateTime e, int wd) {
    for (DateTime d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      if (d.weekday == wd) return d;
    }
    return null;
  }

  static DateTime _laterOf(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  static DateTime? _parseDate(String? s) =>
      s == null || s.isEmpty ? null : DateTime.tryParse(s);

  // UTC datetime string: 20260504T235959
  static String _dtUtc(DateTime dt) =>
      '${_p4(dt.year)}${_p2(dt.month)}${_p2(dt.day)}'
      'T${_p2(dt.hour)}${_p2(dt.minute)}${_p2(dt.second)}';

  // Local datetime string (same format, used with TZID)
  static String _dt(DateTime dt) => _dtUtc(dt);

  // Date-only string: 20260504
  static String _date(DateTime dt) =>
      '${_p4(dt.year)}${_p2(dt.month)}${_p2(dt.day)}';

  static String _p2(int n) => n.toString().padLeft(2, '0');
  static String _p4(int n) => n.toString().padLeft(4, '0');
}

// ── Internal data classes ──────────────────────────────────────────────────────

class _ExamPeriod {
  final SessionType sessionType;
  final String label;
  final DateTime bannerStart; // first day of exam week (inclusive)
  final DateTime bannerEnd;   // last day of exam week (inclusive, ≥ start+6)
  final DateTime searchStart; // same as bannerStart
  final DateTime searchEnd;   // same as bannerEnd

  const _ExamPeriod({
    required this.sessionType,
    required this.label,
    required this.bannerStart,
    required this.bannerEnd,
    required this.searchStart,
    required this.searchEnd,
  });
}
