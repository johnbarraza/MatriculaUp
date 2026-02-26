import 'package:flutter/material.dart';
import '../../models/calendar_event.dart';

/// Bottom sheet that shows the academic calendar grouped by month.
class AcademicCalendarSheet extends StatelessWidget {
  final AcademicCalendar calendar;

  const AcademicCalendarSheet({super.key, required this.calendar});

  static const _monthNames = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  // Color + icon per event type
  static Color _color(CalendarEventType t) => switch (t) {
    CalendarEventType.libre          => Colors.green.shade700,
    CalendarEventType.examen         => Colors.red.shade700,
    CalendarEventType.matricula      => Colors.blue.shade700,
    CalendarEventType.prematricula   => Colors.blue.shade400,
    CalendarEventType.academico      => Colors.purple.shade700,
    CalendarEventType.plazo          => Colors.orange.shade700,
    CalendarEventType.administrativo => Colors.grey.shade700,
  };

  static Color _bg(CalendarEventType t) => switch (t) {
    CalendarEventType.libre          => Colors.green.shade50,
    CalendarEventType.examen         => Colors.red.shade50,
    CalendarEventType.matricula      => Colors.blue.shade50,
    CalendarEventType.prematricula   => Colors.blue.shade50,
    CalendarEventType.academico      => Colors.purple.shade50,
    CalendarEventType.plazo          => Colors.orange.shade50,
    CalendarEventType.administrativo => Colors.grey.shade100,
  };

  static IconData _icon(CalendarEventType t) => switch (t) {
    CalendarEventType.libre          => Icons.beach_access,
    CalendarEventType.examen         => Icons.quiz_outlined,
    CalendarEventType.matricula      => Icons.how_to_reg_outlined,
    CalendarEventType.prematricula   => Icons.edit_calendar_outlined,
    CalendarEventType.academico      => Icons.school_outlined,
    CalendarEventType.plazo          => Icons.warning_amber_outlined,
    CalendarEventType.administrativo => Icons.admin_panel_settings_outlined,
  };

  String _formatDateRange(CalendarEvent event) {
    final parts = event.inicio.split('-'); // [yyyy, mm, dd]
    final day1 = int.parse(parts[2]);
    if (event.isSingleDay) return '$day1';
    final parts2 = event.fin.split('-');
    final day2 = int.parse(parts2[2]);
    // If different month, show full end date
    if (parts[1] != parts2[1]) {
      return '$day1 — ${_monthNames[int.parse(parts2[1])].substring(0, 3)} $day2';
    }
    return '$day1 — $day2';
  }

  @override
  Widget build(BuildContext context) {
    // Group events by month
    final Map<int, List<CalendarEvent>> byMonth = {};
    for (final e in calendar.eventos) {
      byMonth.putIfAbsent(e.mes, () => []).add(e);
    }
    final months = byMonth.keys.toList()..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario Académico',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        calendar.semestre,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // ── Semester dates pill ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range, size: 14, color: Colors.purple.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Clases: ${_shortDate(calendar.inicioClases)} — ${_shortDate(calendar.finClases)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // ── Event list ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: months.length,
              itemBuilder: (context, idx) {
                final month = months[idx];
                final events = byMonth[month]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        _monthNames[month].toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...events.map((e) => _EventTile(
                          event: e,
                          dateLabel: _formatDateRange(e),
                          color: _color(e.tipo),
                          bg: _bg(e.tipo),
                          icon: _icon(e.tipo),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(String iso) {
    // "2026-03-16" → "16 Mar"
    final p = iso.split('-');
    final month = _monthNames[int.parse(p[1])].substring(0, 3);
    return '${int.parse(p[2])} $month';
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final String dateLabel;
  final Color color;
  final Color bg;
  final IconData icon;

  const _EventTile({
    required this.event,
    required this.dateLabel,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge
            Container(
              width: 36,
              alignment: Alignment.center,
              child: Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            // Icon
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            // Description + type label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.descripcion,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.tipo.label,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
