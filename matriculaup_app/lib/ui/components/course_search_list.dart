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
  String _searchQuery = '';
  bool _hideConflicts = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final allCourses = state.allCourses;

    // Filter by name, code, or professor. Optionally hide fully-conflicting courses.
    final filteredCourses = allCourses.where((c) {
      final query = _searchQuery.toLowerCase();

      final matchesQuery =
          query.isEmpty ||
          c.nombre.toLowerCase().contains(query) ||
          c.codigo.toLowerCase().contains(query) ||
          c.secciones.any(
            (s) => s.docentes.any((d) => d.toLowerCase().contains(query)),
          );

      if (!matchesQuery) return false;

      // If "Hide Conflicts" is on, remove courses where ALL sections conflict.
      if (_hideConflicts && state.selectedSections.isNotEmpty) {
        final allConflict = c.secciones.every(
          (s) => state.conflictsWithSchedule(s),
        );
        if (allConflict) return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        // ── Search Bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, código o profesor...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // ── "Ocultar Cruces" toggle ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SwitchListTile(
            dense: true,
            title: const Text(
              'Ocultar cursos con cruce',
              style: TextStyle(fontSize: 13),
            ),
            secondary: const Icon(Icons.filter_alt_outlined, size: 18),
            value: _hideConflicts,
            onChanged: (v) => setState(() => _hideConflicts = v),
          ),
        ),

        const Divider(height: 1),

        // ── Courses List ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: filteredCourses.length,
            itemBuilder: (context, index) {
              final course = filteredCourses[index];

              // Filter sections: if hide is on, skip fully-conflicting ones
              final visibleSections = _hideConflicts
                  ? course.secciones
                        .where((s) => !state.conflictsWithSchedule(s))
                        .toList()
                  : course.secciones;

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
                  children: visibleSections.map((section) {
                    final isSelected = state.selectedSections.any(
                      (s) =>
                          s.course.codigo == course.codigo &&
                          s.section.seccion == section.seccion,
                    );
                    final hasConflict =
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
                        // BLOCK add if selected OR has conflict
                        onPressed: (isSelected || hasConflict)
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
