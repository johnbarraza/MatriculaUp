// matriculaup_app/lib/ui/components/course_search_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/schedule_state.dart';

class CourseSearchList extends StatefulWidget {
  const CourseSearchList({super.key});

  @override
  State<CourseSearchList> createState() => _CourseSearchListState();
}

class _CourseSearchListState extends State<CourseSearchList> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final allCourses = state.allCourses;

    final filteredCourses = allCourses.where((c) {
      final query = _searchQuery.toLowerCase();
      return c.nombre.toLowerCase().contains(query) ||
          c.codigo.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o código...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              final course = filteredCourses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Text(
                    course.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${course.codigo} | Créditos: ${course.creditos}',
                  ),
                  children: course.secciones.map((section) {
                    // Check if already selected
                    bool isSelected = state.selectedSections.any(
                      (s) =>
                          s.course.codigo == course.codigo &&
                          s.section.seccion == section.seccion,
                    );
                    bool hasConflict =
                        !isSelected && state.conflictsWithSchedule(section);

                    return ListTile(
                      tileColor: hasConflict ? Colors.red.shade50 : null,
                      title: Text(
                        'Sección ${section.seccion}',
                        style: TextStyle(
                          color: hasConflict ? Colors.red.shade900 : null,
                          fontWeight: hasConflict
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        hasConflict
                            ? 'Cruce de horarios\n${section.docentes.join(', ')}'
                            : section.docentes.join(', '),
                        style: TextStyle(
                          color: hasConflict ? Colors.red.shade700 : null,
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasConflict
                              ? Colors.red.shade100
                              : null,
                          foregroundColor: hasConflict
                              ? Colors.red.shade900
                              : null,
                        ),
                        onPressed: isSelected
                            ? null
                            : () {
                                try {
                                  state.addSection(course, section);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          isSelected
                              ? 'Agregado'
                              : (hasConflict ? 'Cruza' : 'Agregar'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
