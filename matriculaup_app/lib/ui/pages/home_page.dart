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

    return Scaffold(
      appBar: AppBar(title: const Text('MatriculaUp')),
      body: Row(
        children: [
          // Left Panel (30%)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[200],
              child: courses.isEmpty
                  ? Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          List<Course>? loaded =
                              await DataLoader.pickAndLoadCourses();
                          if (loaded != null) {
                            // ignore: use_build_context_synchronously
                            context.read<ScheduleState>().setCourses(loaded);
                          }
                        },
                        child: const Text('Cargar Archivos JSON'),
                      ),
                    )
                  : const CourseSearchList(),
            ),
          ),

          // Right Panel (70%)
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
                      onSelectionChanged: (Set<bool> newSelection) {
                        setState(() {
                          _showExams = newSelection.first;
                        });
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
}
