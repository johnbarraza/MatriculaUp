import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';
import '../../utils/time_utils.dart';

class TimetableGrid extends StatefulWidget {
  final bool showExams;
  final GlobalKey? exportKey;

  const TimetableGrid({super.key, this.showExams = false, this.exportKey});

  final int startHour = 7;
  final int startMinute = 30;
  final int endHour = 23;
  final double minHourHeight = 30.0;
  final double maxHourHeight = 56.0;

  final List<String> days = const ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'];

  int get gridStartMins => startHour * 60 + startMinute;

  double gridHeightPx(double hourHeight) =>
      ((endHour * 60 - gridStartMins) / 60.0) * hourHeight;

  int get numFullSlots => (endHour * 60 - gridStartMins) ~/ 60;

  int get remainderMins => (endHour * 60 - gridStartMins) % 60;

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  bool _isSelecting = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final selections = state.selectedSections
        .where((s) => !state.isCourseHidden(s.course.codigo))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 780.0;
        final totalHours = (widget.endHour * 60 - widget.gridStartMins) / 60.0;
        const nonGridHeight = 58.0;
        final fitted =
            ((availableHeight - nonGridHeight) / totalHours).clamp(widget.minHourHeight, widget.maxHourHeight);
        final hourHeight = (fitted as num).toDouble();
        final gridHeightPx = widget.gridHeightPx(hourHeight);

        return SingleChildScrollView(
          child: RepaintBoundary(
            key: widget.exportKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 50),
                      ...widget.days.map(
                        (day) => Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              color: Colors.grey.shade100,
                            ),
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        height: gridHeightPx,
                        child: Stack(
                          children: [
                            ...List.generate(widget.numFullSlots + 1, (i) {
                              final mins = widget.gridStartMins + i * 60;
                              final h = mins ~/ 60;
                              final m = mins % 60;
                              return Positioned(
                                top: i * hourHeight,
                                left: 0,
                                right: 0,
                                child: Text(
                                  '$h:${m.toString().padLeft(2, '0')}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      ...widget.days.map((day) {
                        final daySessions = <Widget>[];

                        for (final selection in selections) {
                          for (final session in selection.section.sesiones) {
                            if (session.dia != day || session.tipo == SessionType.cancelada) {
                              continue;
                            }

                            final isExam =
                                session.tipo == SessionType.finalExam ||
                                session.tipo == SessionType.parcial ||
                                session.tipo == SessionType.exSustitutorio ||
                                session.tipo == SessionType.exRezagado;

                            if ((widget.showExams && isExam) ||
                                (!widget.showExams && !isExam)) {
                              daySessions.add(
                                _buildSessionBlock(
                                  context,
                                  state,
                                  selection,
                                  session,
                                  hourHeight,
                                ),
                              );
                            }
                          }
                        }

                        return Expanded(
                          child: GestureDetector(
                            onPanStart: (details) {
                              final rowIndex = (details.localPosition.dy / hourHeight).floor();
                              final hour = widget.startHour + rowIndex;
                              if (hour >= widget.startHour && hour < widget.endHour) {
                                _isSelecting = !state.isTimeSlotSelected(day, hour);
                                state.toggleTimeSlot(day, hour, _isSelecting);
                              }
                            },
                            onPanUpdate: (details) {
                              final rowIndex = (details.localPosition.dy / hourHeight).floor();
                              final hour = widget.startHour + rowIndex;
                              if (hour >= widget.startHour && hour < widget.endHour) {
                                if (state.isTimeSlotSelected(day, hour) != _isSelecting) {
                                  state.toggleTimeSlot(day, hour, _isSelecting);
                                }
                              }
                            },
                            child: Container(
                              height: gridHeightPx,
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.grey.shade200),
                                  right: BorderSide(color: Colors.grey.shade200),
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  for (int i = 0; i < widget.numFullSlots; i++)
                                    Positioned(
                                      top: i * hourHeight,
                                      left: 0,
                                      right: 0,
                                      height: hourHeight,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: state.isTimeSlotSelected(day, widget.startHour + i)
                                              ? Colors.greenAccent.withValues(alpha: 0.2)
                                              : Colors.transparent,
                                          border: Border(
                                            top: BorderSide(color: Colors.grey.shade200),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (widget.remainderMins > 0)
                                    Positioned(
                                      top: widget.numFullSlots * hourHeight,
                                      left: 0,
                                      right: 0,
                                      height: (widget.remainderMins / 60.0) * hourHeight,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: Colors.grey.shade200),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ...daySessions,
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionBlock(
    BuildContext context,
    ScheduleState state,
    CourseSelection selection,
    Session session,
    double hourHeight,
  ) {
    final startMins = TimeUtils.timeToMinutes(session.horaInicio);
    final gridStartMins = widget.gridStartMins;

    double topOffset = ((startMins - gridStartMins) / 60.0) * hourHeight;
    double blockHeight =
        (TimeUtils.durationMinutes(session.horaInicio, session.horaFin) / 60.0) * hourHeight;

    if (topOffset < 0) {
      blockHeight += topOffset;
      topOffset = 0;
    }
    if (blockHeight <= 0) return const SizedBox.shrink();

    final hue = (selection.course.codigo.hashCode % 360).toDouble();
    final blockColor = HSVColor.fromAHSV(1.0, hue, 0.6, 0.9).toColor();

    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      height: blockHeight,
      child: Material(
        color: blockColor,
        borderRadius: BorderRadius.circular(4),
        elevation: 1,
        child: InkWell(
          onTap: () {},
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 52;
              final medium = constraints.maxHeight < 72;
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selection.course.nombre,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!compact)
                          Text(
                            'Sec ${selection.section.seccion} | ${session.tipo.value}',
                            style: const TextStyle(fontSize: 8, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '${session.horaInicio} - ${session.horaFin}',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!medium && session.aula.isNotEmpty)
                          Text(
                            session.aula.toUpperCase().contains('VIRTUAL')
                                ? 'Virtual'
                                : session.aula,
                            style: const TextStyle(fontSize: 7, color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (!medium && selection.section.docentes.isNotEmpty)
                          Text(
                            _formatProfName(selection.section.docentes),
                            style: const TextStyle(
                              fontSize: 7,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 12, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          state.removeSection(selection.course, selection.section),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatProfName(List<String> docentes) {
    if (docentes.isEmpty) return '';
    final first = docentes.first;
    final lastName =
        first.contains(',') ? first.split(',').first.trim() : first.trim();
    final formatted = lastName
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '')
        .join(' ');
    return docentes.length > 1 ? '$formatted +${docentes.length - 1}' : formatted;
  }
}
