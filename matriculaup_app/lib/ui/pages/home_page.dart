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
    final hasFreeTime =
        state.preferredStart != null && state.preferredEnd != null;

    return Scaffold(
      // ── AppBar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        title: const Text('MatriculaUp'),
        actions: [
          // Free-time bounds picker
          Tooltip(
            message: 'Filtro de horario preferido',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showFreeTimeDialog(context, state),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: hasFreeTime ? Colors.greenAccent : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasFreeTime
                          ? '${state.preferredStart} – ${state.preferredEnd}'
                          : 'Horario libre',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasFreeTime
                            ? Colors.greenAccent
                            : Colors.white70,
                      ),
                    ),
                    if (hasFreeTime) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => state.setFreeTimePrefs(null, null),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white54,
                        ),
                      ),
                    ],
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
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        onPressed: () async {
                          List<Course>? loaded =
                              await DataLoader.pickAndLoadCourses();
                          if (loaded != null && context.mounted) {
                            context.read<ScheduleState>().setCourses(loaded);
                          }
                        },
                        label: const Text('Cargar Archivos JSON'),
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
                          child: _leftTab == 0
                              ? const CourseSearchList()
                              : const SingleChildScrollView(
                                  child: SelectedCoursesPanel(),
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

  // ── Free-Time Picker Dialog ───────────────────────────────────────────────
  Future<void> _showFreeTimeDialog(
    BuildContext context,
    ScheduleState state,
  ) async {
    final hours = List.generate(
      16,
      (i) => '${(i + 7).toString().padLeft(2, '0')}:00',
    ); // 07:00-22:00

    String start = state.preferredStart ?? '09:00';
    String end = state.preferredEnd ?? '18:00';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('Horario Preferido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Las secciones fuera de este rango se tratarán como cruces.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Desde: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: start,
                    items: hours
                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                    onChanged: (v) => setSt(() => start = v!),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Hasta: '),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: end,
                    items: hours
                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                    onChanged: (v) => setSt(() => end = v!),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                state.setFreeTimePrefs(null, null);
                Navigator.pop(ctx);
              },
              child: const Text('Quitar filtro'),
            ),
            ElevatedButton(
              onPressed: () {
                state.setFreeTimePrefs(start, end);
                Navigator.pop(ctx);
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
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
