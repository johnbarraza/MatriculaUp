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

      // If "Hide Conflicts" is on, remove courses where ALL sections conflict
      // with either the schedule OR the free-time preference window.
      if (_hideConflicts) {
        final allConflict = c.secciones.every(
          (s) =>
              state.conflictsWithSchedule(s) ||
              !state.fitsInSelectedTimeSlots(s),
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

              final visibleSections = _hideConflicts
                  ? course.secciones
                        .where((s) => !state.conflictsWithSchedule(s))
                        .toList()
                  : course.secciones;

              // Curriculum Tag Logic
              Widget? curriculumTag;
              if (state.curriculum != null) {
                final isMandatory = state.curriculum!.isMandatory(
                  course.codigo,
                );
                curriculumTag = Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isMandatory
                        ? Colors.green.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isMandatory
                          ? Colors.green.shade400
                          : Colors.blue.shade400,
                    ),
                  ),
                  child: Text(
                    isMandatory ? 'Obligatorio' : 'Electivo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMandatory
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                );
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ?curriculumTag,
                    ],
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
                    final conflictReason = state.getConflictReason(section);
                    final hasConflict = !isSelected && conflictReason != null;

                    // Build session detail strings
                    final sessionDetails = section.sesiones
                        .map((s) {
                          String aula = s.aula;
                          if (aula.toUpperCase().contains('VIRTUAL')) {
                            aula = 'Virtual';
                          }
                          // Human-readable session type (title-case the raw string)
                          final tipoLabel =
                              s.tipo.value[0] +
                              s.tipo.value.substring(1).toLowerCase();
                          final diaStr = s.dia.isNotEmpty ? s.dia : '—';
                          final horaStr = '${s.horaInicio}-${s.horaFin}';
                          return '$tipoLabel: $diaStr $horaStr${aula.isNotEmpty ? ' ($aula)' : ''}';
                        })
                        .join('\n');

                    // Docentes string
                    final docentesStr = section.docentes.isEmpty
                        ? 'Sin asignar'
                        : section.docentes.join(', ');

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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasConflict)
                            Text(
                              'Cruce con: $conflictReason',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            sessionDetails,
                            style: TextStyle(
                              color: hasConflict ? Colors.red.shade700 : null,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: hasConflict
                                    ? Colors.red.shade700
                                    : Colors.black87,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Profs: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: docentesStr),
                              ],
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
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
