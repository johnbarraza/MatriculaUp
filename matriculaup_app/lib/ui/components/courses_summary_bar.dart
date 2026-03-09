// matriculaup_app/lib/ui/components/courses_summary_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';
import 'schedule_explorer_panel.dart';

class CoursesSummaryBar extends StatefulWidget {
  const CoursesSummaryBar({super.key});

  @override
  State<CoursesSummaryBar> createState() => _CoursesSummaryBarState();
}

class _CoursesSummaryBarState extends State<CoursesSummaryBar> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final selections = state.selectedSections;
    final hasSelections = selections.isNotEmpty;

    final totalCredits = selections.fold<int>(0, (sum, sel) {
      return sum + (double.tryParse(sel.course.creditos) ?? 0.0).round();
    });
    final weeklyHours = state.weeklyHours;
    final gapHours = state.weeklyGapHours;
    final classDays = state.classDaysCount;
    final freeDays = state.freeDaysCount;
    final count = selections.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.blue.shade100, width: 1.5),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (always visible) ──────────────────────────────────────
          InkWell(
            onTap: hasSelections
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: hasSelections
                    ? Colors.blue.shade50
                    : Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.table_rows_outlined,
                    size: 14,
                    color: hasSelections
                        ? Colors.blue.shade700
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 7),
                  if (!hasSelections)
                    Text(
                      'Sin cursos seleccionados — busca en el panel izquierdo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else ...[
                    Text(
                      '$count ${count == 1 ? 'curso' : 'cursos'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _chip('$totalCredits cr.', Colors.blue.shade700),
                    const SizedBox(width: 4),
                    _chip(
                      '${weeklyHours.toStringAsFixed(1)} h/sem',
                      Colors.teal.shade700,
                    ),
                    if (gapHours > 0) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Horas libres entre clases del mismo día',
                        child: _chip(
                          '${gapHours.toStringAsFixed(1)} h hueco',
                          Colors.orange.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    _chip('$classDays d con clases', Colors.indigo.shade700),
                    const SizedBox(width: 4),
                    _chip('$freeDays d libres', Colors.green.shade700),
                  ],
                  const Spacer(),
                  if (hasSelections)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? 'Ocultar' : 'Mostrar',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // ── Course table (collapsible) ───────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            child: (_expanded && hasSelections)
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final useSidePanel = width >= 1050;
                      if (useSidePanel) {
                        return SizedBox(
                          height: 280,
                          child: Row(
                            children: [
                              Expanded(child: _buildTable(state, selections)),
                              const VerticalDivider(width: 1),
                              const SizedBox(
                                width: 340,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: ScheduleExplorerPanel(embedded: true),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          _buildTable(state, selections),
                          const Divider(height: 1),
                          const SizedBox(
                            height: 260,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: ScheduleExplorerPanel(embedded: true),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTable(ScheduleState state, List<CourseSelection> selections) {
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 190),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              // Ensure scroll area is at least as wide as the panel so that
              // Center can actually push the DataTable to the middle.
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Center(
                child: DataTable(
                  headingRowHeight: 24,
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 34,
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  dividerThickness: 0.5,
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: 12,
                        child: Text(
                          '',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'CURSO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'SEC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'DOCENTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'CR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    DataColumn(
                      numeric: true,
                      label: Text(
                        'CUPOS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const DataColumn(label: SizedBox.shrink()),
                  ],
                  rows: selections.map((sel) {
                    final isHidden = state.isCourseHidden(sel.course.codigo);
                    final isLocked = state.isCourseLocked(sel.course.codigo);
                    final courseColor = _courseColor(sel.course.codigo);

                    return DataRow(
                      color: WidgetStateProperty.resolveWith((states) {
                        if (isHidden) return Colors.grey.shade50;
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.blue.shade50.withValues(alpha: 0.5);
                        }
                        return null;
                      }),
                      cells: [
                        // Color dot
                        DataCell(
                          Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isHidden
                                    ? Colors.grey.shade300
                                    : courseColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        // Course name
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 210),
                            child: Text(
                              sel.course.nombre,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isHidden
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade800,
                                decoration: isHidden
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.grey.shade400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Section
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isHidden
                                  ? Colors.grey.shade100
                                  : courseColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sel.section.seccion,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isHidden
                                    ? Colors.grey.shade400
                                    : courseColor
                                          .withValues(alpha: 1.0)
                                          .withRed(
                                            (courseColor.r * 0.7).round(),
                                          )
                                          .withGreen(
                                            (courseColor.g * 0.7).round(),
                                          )
                                          .withBlue(
                                            (courseColor.b * 0.7).round(),
                                          ),
                              ),
                            ),
                          ),
                        ),
                        // Professor
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              _formatProfName(sel.section.docentes),
                              style: TextStyle(
                                fontSize: 11,
                                color: isHidden
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Credits
                        DataCell(
                          Text(
                            sel.course.creditos,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isHidden
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        // Cupos
                        DataCell(
                          Text(
                            _formatSectionCupos(sel.section),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isHidden
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                        // Action buttons
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _actionButton(
                                icon: isLocked ? Icons.lock : Icons.lock_open,
                                color: isLocked
                                    ? Colors.amber.shade700
                                    : Colors.blueGrey.shade500,
                                tooltip: isLocked
                                    ? 'Curso obligatorio para explorador'
                                    : 'Marcar como obligatorio',
                                onPressed: () =>
                                    state.toggleCourseLock(sel.course.codigo),
                              ),
                              _actionButton(
                                icon: isHidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: isHidden
                                    ? Colors.grey.shade400
                                    : Colors.blue.shade600,
                                tooltip: isHidden
                                    ? 'Mostrar en horario'
                                    : 'Ocultar del horario',
                                onPressed: () => state.toggleCourseVisibility(
                                  sel.course.codigo,
                                ),
                              ),
                              _actionButton(
                                icon: Icons.close_rounded,
                                color: Colors.red.shade400,
                                tooltip: 'Quitar curso',
                                onPressed: () => state.removeSection(
                                  sel.course,
                                  sel.section,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ), // Center
            ), // ConstrainedBox minWidth
          ), // horizontal scroll
        ), // vertical scroll
      ), // ConstrainedBox maxHeight
    ); // LayoutBuilder
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Color _courseColor(String codigo) {
    final hue = (codigo.hashCode % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.6, 0.9).toColor();
  }

  String _formatProfName(List<String> docentes) {
    if (docentes.isEmpty) return '—';
    final first = docentes.first;
    final lastName = first.contains(',')
        ? first.split(',').first.trim()
        : first.trim();
    final formatted = lastName
        .split(' ')
        .map(
          (w) => w.isNotEmpty
              ? w[0].toUpperCase() + w.substring(1).toLowerCase()
              : '',
        )
        .join(' ');
    return docentes.length > 1
        ? '$formatted +${docentes.length - 1}'
        : formatted;
  }

  String _formatSectionCupos(Section section) {
    final cupos =
        section.sesiones
            .map((s) => s.cupos)
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    if (cupos.isEmpty) return 's/d';
    if (cupos.length == 1) return '${cupos.first}';
    return '${cupos.first}-${cupos.last}';
  }
}
