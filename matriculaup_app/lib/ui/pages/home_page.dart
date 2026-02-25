// matriculaup_app/lib/ui/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/data_loader.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';
import 'package:matriculaup_app/ui/components/course_search_list.dart';
import 'package:matriculaup_app/ui/components/timetable_grid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showExams = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final courses = state.allCourses;
    final credits = state.currentCredits;
    final maxCredits = state.maxCredits;

    return Scaffold(
      // ── AppBar with credit badge and Plan A/B/C switcher ─────────────────
      appBar: AppBar(
        title: const Text('MatriculaUp'),
        actions: [
          // Credit counter + edit button
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showCreditLimitDialog(context, state),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Créditos: $credits / $maxCredits',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: credits >= maxCredits ? Colors.red.shade200 : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Plan A / B / C switcher
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('Plan A')),
              ButtonSegment<int>(value: 1, label: Text('Plan B')),
              ButtonSegment<int>(value: 2, label: Text('Plan C')),
            ],
            selected: <int>{state.activeScheduleIndex},
            onSelectionChanged: (Set<int> s) => state.switchSchedule(s.first),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),

      body: Row(
        children: [
          // Left Panel — Course search (30%)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[200],
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
                  : const CourseSearchList(),
            ),
          ),

          // Right Panel — Timetable (70%)
          Expanded(
            flex: 7,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Regular / Exams toggle
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
                      onSelectionChanged: (Set<bool> s) {
                        setState(() => _showExams = s.first);
                      },
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

  // ── Credit Limit Edit Dialog ──────────────────────────────────────────────
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
