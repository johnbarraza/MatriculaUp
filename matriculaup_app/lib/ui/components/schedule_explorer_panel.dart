import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';
import '../../utils/time_utils.dart';

enum _GenerationMode { maximize, complete }

class ScheduleExplorerPanel extends StatefulWidget {
  const ScheduleExplorerPanel({
    super.key,
    this.embedded = false,
    this.closeOnApply = false,
  });

  final bool embedded;
  final bool closeOnApply;

  @override
  State<ScheduleExplorerPanel> createState() => _ScheduleExplorerPanelState();
}

class _ScheduleExplorerPanelState extends State<ScheduleExplorerPanel> {
  static const int _maxOptions = 800;
  static const _regularTypes = {
    SessionType.clase,
    SessionType.practica,
    SessionType.pracDirigida,
    SessionType.pracCalificada,
    SessionType.laboratorio,
  };
  static const _fixedExamTypes = {SessionType.parcial, SessionType.finalExam};

  bool _excludeZeroCupos = true;
  bool _isGenerating = false;
  List<_ScheduleOption> _options = const [];
  _GenerationMode _generationMode = _GenerationMode.maximize;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final selectedCodes = state.selectedSections.map((s) => s.course.codigo).toSet();

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${selectedCodes.length} cursos',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<_GenerationMode>(
                  value: _generationMode,
                  isDense: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _generationMode = v);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: _GenerationMode.maximize,
                      child: Text('Migajero'),
                    ),
                    DropdownMenuItem(
                      value: _GenerationMode.complete,
                      child: Text('Maes'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text('Cupos > 0', style: TextStyle(fontSize: 11)),
              Transform.scale(
                scale: 0.78,
                child: Switch(
                  value: _excludeZeroCupos,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => _excludeZeroCupos = v),
                ),
              ),
              ElevatedButton(
                onPressed: _isGenerating ? null : () => _generateOptions(state),
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Generar', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildOptionsPane(state)),
      ],
    );

    if (!widget.embedded) return body;

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_mosaic_outlined,
                    size: 14, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Explorador de combinaciones',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: 'Como funciona',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.help_outline, size: 16),
                  onPressed: () => _showHelpDialog(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildOptionsPane(ScheduleState state) {
    final topOptions = _options.take(10).toList(growable: false);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: topOptions.isEmpty
          ? const Center(
              key: ValueKey('empty'),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Explora horarios tentativos con tus cursos actuales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            )
          : ListView.builder(
              key: const ValueKey('results'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: topOptions.length,
              itemBuilder: (context, i) {
                final o = topOptions[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 160 + ((i * 14).clamp(0, 140) as int)),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) {
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 8),
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Opcion ${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                _metricChip(
                                  '${o.selectedCourseCount}/${o.targetCourseCount} cursos',
                                  Colors.indigo.shade700,
                                ),
                                _metricChip('${o.credits} cr', Colors.blue.shade700),
                                _metricChip('${o.weeklyHours.toStringAsFixed(1)} h',
                                    Colors.teal.shade700),
                                _metricChip('${o.gapHours.toStringAsFixed(1)} h hueco',
                                    Colors.orange.shade700),
                                _metricChip(
                                  '${o.classDaysCount} d clase',
                                  Colors.indigo.shade700,
                                ),
                                _metricChip(
                                  '${o.freeDaysCount} d libres',
                                  Colors.green.shade700,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Usar opcion',
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            onPressed: () {
                              state.replaceActiveSchedule(o.selections);
                              if (widget.closeOnApply && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _metricChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 9),
      ),
    );
  }

  Future<void> _generateOptions(ScheduleState state) async {
    final targetCodes = state.selectedSections.map((sel) => sel.course.codigo).toSet();
    final lockedCodes = state.lockedCourseCodes;

    if (targetCodes.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitas al menos 2 cursos seleccionados.')),
      );
      return;
    }

    setState(() => _isGenerating = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final selectedCourses = state.allVisibleCourses
        .where((c) => targetCodes.contains(c.codigo))
        .toList()
      ..sort((a, b) => a.secciones.length.compareTo(b.secciones.length));
    final targetCount = selectedCourses.length;

    final options = <_ScheduleOption>[];
    final chosen = <CourseSelection>[];

    void backtrack(int idx) {
      if (options.length >= _maxOptions) return;
      if (idx == selectedCourses.length) {
        if (chosen.isEmpty) return;
        options.add(_buildOption(chosen, targetCount));
        return;
      }

      final c = selectedCourses[idx];
      final isLocked = lockedCodes.contains(c.codigo);
      for (final section in c.secciones) {
        if (_excludeZeroCupos && !_sectionHasAvailableCupos(section)) continue;
        if (_conflictsWithChosen(section, chosen)) continue;
        if (!state.fitsInSelectedTimeSlots(section)) continue;
        chosen.add(CourseSelection(course: c, section: section));
        backtrack(idx + 1);
        chosen.removeLast();
      }
      if (_generationMode == _GenerationMode.maximize && !isLocked) {
        backtrack(idx + 1);
      }
    }

    backtrack(0);

    options.sort((a, b) {
      if (_generationMode == _GenerationMode.maximize) {
        final byCourses = b.selectedCourseCount.compareTo(a.selectedCourseCount);
        if (byCourses != 0) return byCourses;
      }
      final byGap = a.gapHours.compareTo(b.gapHours);
      if (byGap != 0) return byGap;
      return a.weeklyHours.compareTo(b.weeklyHours);
    });

    setState(() {
      _options = options;
      _isGenerating = false;
    });

    if (options.isEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron combinaciones sin cruces.')),
      );
    }
  }

  bool _sectionHasAvailableCupos(Section section) {
    final cupos = section.sesiones.map((s) => s.cupos).whereType<int>().toList();
    if (cupos.isEmpty) return true;
    return cupos.any((c) => c > 0);
  }

  bool _conflictsWithChosen(Section candidate, List<CourseSelection> chosen) {
    for (final sel in chosen) {
      for (final n in candidate.sesiones) {
        for (final c in sel.section.sesiones) {
          if (!_canConflict(n, c)) continue;
          if (n.dia != c.dia) continue;
          if (TimeUtils.hasOverlap(
            n.horaInicio,
            n.horaFin,
            c.horaInicio,
            c.horaFin,
          )) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _canConflict(Session s1, Session s2) {
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
    if (s1Regular && s2Regular) return true;
    final s1Exam = _fixedExamTypes.contains(s1.tipo);
    final s2Exam = _fixedExamTypes.contains(s2.tipo);
    if (s1Exam && s2Exam) return s1.tipo == s2.tipo;
    return false;
  }

  _ScheduleOption _buildOption(
    List<CourseSelection> selections,
    int targetCourseCount,
  ) {
    final copy = List<CourseSelection>.from(selections);

    double weeklyHours = 0;
    int credits = 0;
    final byDay = <String, List<(int start, int end)>>{};

    for (final sel in copy) {
      credits += (double.tryParse(sel.course.creditos) ?? 0).round();
      for (final s in sel.section.sesiones) {
        if (!_regularTypes.contains(s.tipo)) continue;
        final start = TimeUtils.timeToMinutes(s.horaInicio);
        final end = TimeUtils.timeToMinutes(s.horaFin);
        weeklyHours += (end - start) / 60.0;
        byDay.putIfAbsent(s.dia, () => []).add((start, end));
      }
    }

    double gapHours = 0;
    for (final slots in byDay.values) {
      slots.sort((a, b) => a.$1.compareTo(b.$1));
      for (int i = 1; i < slots.length; i++) {
        final gap = slots[i].$1 - slots[i - 1].$2;
        if (gap > 0) gapHours += gap / 60.0;
      }
    }

    const windowHours = 75.0;
    final freeHours =
        ((windowHours - weeklyHours).clamp(0, windowHours) as num).toDouble();
    const summaryDays = {'LUN', 'MAR', 'MIE', 'JUE', 'VIE', 'SAB'};
    final classDaysCount = byDay.keys
        .map((d) => d.toUpperCase().trim())
        .where(summaryDays.contains)
        .toSet()
        .length;
    final freeDaysCount = ((6 - classDaysCount).clamp(0, 6) as num).toInt();

    return _ScheduleOption(
      selections: copy,
      selectedCourseCount: copy.length,
      targetCourseCount: targetCourseCount,
      credits: credits,
      weeklyHours: weeklyHours,
      gapHours: gapHours,
      freeHours: freeHours,
      classDaysCount: classDaysCount,
      freeDaysCount: freeDaysCount,
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Como funciona el explorador'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Candado (curso obligatorio):',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Marca cursos que si o si debes llevar. '
                'El explorador mantiene ese curso, aunque cambie la seccion.',
              ),
              SizedBox(height: 10),
              Text(
                '2. Modos de generar:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Migajero: intenta meter la maxima cantidad de cursos '
                'sin cruces (ideal si no sabes cuales lograras matricular).',
              ),
              SizedBox(height: 2),
              Text(
                'Maes: solo muestra combinaciones que incluyan todos tus cursos.',
              ),
              SizedBox(height: 10),
              Text(
                '3. Casos tipicos:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Si quieres X cursos en cualquier horario: usa Maes.',
              ),
              SizedBox(height: 2),
              Text(
                'Si quieres ver en que horarios hay opciones: usa ambos y compara.',
              ),
              SizedBox(height: 2),
              Text(
                'Si quieres la maxima cantidad de cursos aunque el horario quede feo: usa Migajero.',
              ),
              SizedBox(height: 10),
              Text(
                '4. Cupos > 0:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Si esta activado, ignora secciones con cupo cero.',
              ),
              SizedBox(height: 10),
              Text(
                '5. Importante:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Los cupos que ves son referenciales y no se actualizan en tiempo real. '
                'El explorador esta pensado para reaccionar rapido en tu ventana de matricula '
                '(por ejemplo, 20 minutos) y ayudarte a pivotear si te quedas sin cupo.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleOption {
  final List<CourseSelection> selections;
  final int selectedCourseCount;
  final int targetCourseCount;
  final int credits;
  final double weeklyHours;
  final double gapHours;
  final double freeHours;
  final int classDaysCount;
  final int freeDaysCount;

  const _ScheduleOption({
    required this.selections,
    required this.selectedCourseCount,
    required this.targetCourseCount,
    required this.credits,
    required this.weeklyHours,
    required this.gapHours,
    required this.freeHours,
    required this.classDaysCount,
    required this.freeDaysCount,
  });
}


