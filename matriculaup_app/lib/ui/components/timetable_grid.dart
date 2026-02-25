// matriculaup_app/lib/ui/components/timetable_grid.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';
import '../../utils/time_utils.dart';

class TimetableGrid extends StatefulWidget {
  final bool showExams;

  const TimetableGrid({super.key, this.showExams = false});

  final int startHour = 7;
  final int endHour = 23;
  final double hourHeight = 60.0;

  final List<String> days = const ['LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'];

  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  bool _isSelecting = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final selections = state.selectedSections;

    return Column(
      children: [
        // Days Header
        Row(
          children: [
            const SizedBox(width: 50), // Time column spacer
            ...widget.days.map(
              (day) => Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade100,
                  ),
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Grid Body
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Column
                SizedBox(
                  width: 50,
                  height:
                      (widget.endHour - widget.startHour + 1) *
                      widget.hourHeight,
                  child: Stack(
                    children: List.generate(
                      (widget.endHour - widget.startHour + 1),
                      (index) {
                        return Positioned(
                          top: index * widget.hourHeight,
                          left: 0,
                          right: 0,
                          child: Text(
                            '${widget.startHour + index}:00',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Days Columns
                ...widget.days.map((day) {
                  // Find sessions for this day
                  final daySessions = <Widget>[];

                  for (var selection in selections) {
                    for (var session in selection.section.sesiones) {
                      if (session.dia == day) {
                        bool isExam =
                            session.tipo == SessionType.finalExam ||
                            session.tipo == SessionType.parcial;
                        if ((widget.showExams && isExam) ||
                            (!widget.showExams && !isExam)) {
                          daySessions.add(
                            _buildSessionBlock(
                              context,
                              state,
                              selection,
                              session,
                            ),
                          );
                        }
                      }
                    }
                  }

                  return Expanded(
                    child: GestureDetector(
                      onPanStart: (details) {
                        final hour =
                            widget.startHour +
                            (details.localPosition.dy ~/ widget.hourHeight);
                        if (hour >= widget.startHour &&
                            hour <= widget.endHour) {
                          _isSelecting = !state.isTimeSlotSelected(day, hour);
                          state.toggleTimeSlot(day, hour, _isSelecting);
                        }
                      },
                      onPanUpdate: (details) {
                        final hour =
                            widget.startHour +
                            (details.localPosition.dy ~/ widget.hourHeight);
                        if (hour >= widget.startHour &&
                            hour <= widget.endHour) {
                          if (state.isTimeSlotSelected(day, hour) !=
                              _isSelecting) {
                            state.toggleTimeSlot(day, hour, _isSelecting);
                          }
                        }
                      },
                      child: Container(
                        height:
                            (widget.endHour - widget.startHour + 1) *
                            widget.hourHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade200),
                            right: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Background grid lines and selected slots
                            ...List.generate(
                              (widget.endHour - widget.startHour + 1),
                              (index) {
                                final h = widget.startHour + index;
                                final isSelected = state.isTimeSlotSelected(
                                  day,
                                  h,
                                );

                                return Positioned(
                                  top: index * widget.hourHeight,
                                  left: 0,
                                  right: 0,
                                  height: widget.hourHeight,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.greenAccent.withValues(
                                              alpha: 0.2,
                                            )
                                          : Colors.transparent,
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Session Blocks
                            ...daySessions,
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionBlock(
    BuildContext context,
    ScheduleState state,
    CourseSelection selection,
    Session session,
  ) {
    int startMins = TimeUtils.timeToMinutes(session.horaInicio);
    int gridStartMins = widget.startHour * 60;

    // Calculate offset from top of grid
    double topOffset = ((startMins - gridStartMins) / 60.0) * widget.hourHeight;
    double durationMins = TimeUtils.durationMinutes(
      session.horaInicio,
      session.horaFin,
    ).toDouble();
    double blockHeight = (durationMins / 60.0) * widget.hourHeight;

    // Generate a consistent color based on course code
    final colorHash = selection.course.codigo.hashCode;
    final hue = (colorHash % 360).toDouble();
    final blockColor = HSVColor.fromAHSV(1.0, hue, 0.6, 0.9).toColor();

    return Positioned(
      top: topOffset,
      left: 2,
      right: 2,
      height: blockHeight,
      child: Material(
        color: blockColor,
        borderRadius: BorderRadius.circular(4),
        elevation: 2,
        child: InkWell(
          onTap: () {
            // Future: Show details dialog
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selection.course.nombre,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Sec ${selection.section.seccion} · ${session.tipo.value}',
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                    Text(
                      '${session.horaInicio} – ${session.horaFin}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (session.aula.isNotEmpty)
                      Text(
                        session.aula,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white70,
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
                  icon: const Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white70,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    state.removeSection(selection.course, selection.section);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
