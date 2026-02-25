// matriculaup_app/lib/ui/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/data_loader.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';
import 'package:matriculaup_app/ui/components/course_search_list.dart';
import 'package:matriculaup_app/ui/components/selected_courses_panel.dart';
import 'package:matriculaup_app/ui/components/timetable_grid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showExams = false;
  // Left-panel tab: 0 = search, 1 = selected courses
  int _leftTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final courses = state.allCourses;
    final credits = state.currentCredits;
    final maxCredits = state.maxCredits;
    final hasFreeTime = state.hasTimeSlotSelection;

    return Scaffold(
      // ── AppBar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('MatriculaUp'),
        actions: [
          // Clear time slots
          if (hasFreeTime)
            Tooltip(
              message: 'Limpiar selección de horario',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => state.clearTimeSlots(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt,
                        size: 16,
                        color: Colors.greenAccent,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Horario Filtrado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.greenAccent,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.close, size: 14, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          // Credit counter
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showCreditLimitDialog(context, state),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$credits / $maxCredits cr.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: credits >= maxCredits ? Colors.red.shade200 : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12),
                ],
              ),
            ),
          ),
          // Plan A / B / C switcher
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('A')),
              ButtonSegment<int>(value: 1, label: Text('B')),
              ButtonSegment<int>(value: 2, label: Text('C')),
            ],
            selected: <int>{state.activeScheduleIndex},
            onSelectionChanged: (s) => state.switchSchedule(s.first),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: Row(
        children: [
          // ── Left Panel ─────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              child: courses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.upload_file),
                            onPressed: () async {
                              List<Course>? loaded =
                                  await DataLoader.pickAndLoadCourses();
                              if (loaded != null && context.mounted) {
                                context.read<ScheduleState>().setCourses(
                                  loaded,
                                );
                              }
                            },
                            label: const Text('Cargar Horarios JSON'),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.school),
                            onPressed: () async {
                              final curriculum =
                                  await DataLoader.pickAndLoadCurriculum();
                              if (curriculum != null && context.mounted) {
                                context.read<ScheduleState>().setCurriculum(
                                  curriculum,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Plan de estudios "${curriculum.title}" cargado (Opcional)',
                                    ),
                                  ),
                                );
                              }
                            },
                            label: const Text(
                              'Cargar Plan de Estudios (Opcional)',
                            ),
                          ),
                          if (state.curriculum != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Plan activo: ${state.curriculum!.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Tab row: Search | Selected
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _leftTab = 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  color: _leftTab == 0
                                      ? Colors.blue.shade700
                                      : Colors.grey[300],
                                  child: Text(
                                    'Buscar cursos',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _leftTab == 0
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _leftTab = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  color: _leftTab == 1
                                      ? Colors.blue.shade700
                                      : Colors.grey[300],
                                  child: Text(
                                    'Seleccionados (${state.selectedSections.length})',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _leftTab == 1
                                          ? Colors.white
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Tab content
                        Expanded(
                          child: IndexedStack(
                            index: _leftTab,
                            children: const [
                              CourseSearchList(),
                              SingleChildScrollView(
                                child: SelectedCoursesPanel(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // ── Right Panel: Timetable ───────────────────────────────────
          Expanded(
            flex: 7,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Semana Regular'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Exámenes'),
                        ),
                      ],
                      selected: <bool>{_showExams},
                      onSelectionChanged: (s) =>
                          setState(() => _showExams = s.first),
                    ),
                  ),
                  Expanded(child: TimetableGrid(showExams: _showExams)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Credit Limit Dialog ───────────────────────────────────────────────────
  Future<void> _showCreditLimitDialog(
    BuildContext context,
    ScheduleState state,
  ) async {
    final controller = TextEditingController(text: state.maxCredits.toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Límite de Créditos'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Máximo de créditos',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) state.setMaxCredits(val);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
