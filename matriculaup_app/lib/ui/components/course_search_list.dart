// matriculaup_app/lib/ui/components/course_search_list.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/schedule_state.dart';

String _normalizeSearch(String input) {
  const from = '��������������';
  const to = 'aeiouunAEIOUUN';
  var out = input;
  for (int i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out.toLowerCase().trim();
}


// ── EFE category helpers ──────────────────────────────────────────────────────

/// Short display label for a raw `_tipo_efe` string.
String _efeShortLabel(String raw) {
  final up = raw.toUpperCase();
  if (up.contains('INTRAPERSONAL')) return 'Intrapersonal';
  if (up.contains('INTERPERSONAL')) return 'Interpersonal';
  if (up.contains('SERVICIO SOCIAL')) return 'Serv. Social';
  if (up.contains('INNOVACI')) return 'Innovación';
  if (up.contains('LIDERAZGO')) return 'Liderazgo';
  if (up.contains('COMPETENCIA')) return 'Comp. Prof.';
  if (up.contains('ARTE') ||
      up.contains('CULTURA') ||
      up.contains('DEPORTE')) {
    return 'Arte | Cultura | Deporte';
  }
  // Generic fallback: strip parenthetical suffix and title-case
  final cleaned = raw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
  return cleaned
      .split(' ')
      .map(
        (w) =>
            w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '',
      )
      .join(' ');
}

/// Accent color for each category (used for chip + section header).
Color _efeCategoryColor(String raw) {
  final up = raw.toUpperCase();
  if (up.contains('INTRAPERSONAL')) return Colors.orange.shade700;
  if (up.contains('INTERPERSONAL')) return Colors.green.shade700;
  if (up.contains('SERVICIO SOCIAL')) return Colors.blue.shade700;
  if (up.contains('INNOVACI')) return Colors.purple.shade700;
  if (up.contains('LIDERAZGO')) return Colors.teal.shade700;
  if (up.contains('COMPETENCIA')) return Colors.indigo.shade700;
  if (up.contains('ARTE') ||
      up.contains('CULTURA') ||
      up.contains('DEPORTE')) {
    return Colors.pink.shade700;
  }
  return Colors.grey.shade700;
}

/// Canonical sort order for known EFE categories.
int _efeCategoryOrder(String raw) {
  final up = raw.toUpperCase();
  if (up.contains('INTRAPERSONAL')) return 0;
  if (up.contains('INTERPERSONAL')) return 1;
  if (up.contains('ARTE') ||
      up.contains('CULTURA') ||
      up.contains('DEPORTE')) {
    return 2; // Same block as intra+inter in newer plans
  }
  if (up.contains('SERVICIO SOCIAL')) return 3;
  if (up.contains('INNOVACI')) return 4;
  if (up.contains('LIDERAZGO')) return 5;
  if (up.contains('COMPETENCIA')) return 6;
  return 99;
}

// ─────────────────────────────────────────────────────────────────────────────

class CourseSearchList extends StatefulWidget {
  const CourseSearchList({super.key});

  @override
  State<CourseSearchList> createState() => _CourseSearchListState();
}

class _CourseSearchListState extends State<CourseSearchList> {
  String _searchQuery = '';
  bool _hideConflicts = false;
  bool _showEfe = false; // false = Regulares, true = EFEs

  /// Currently selected EFE category filter (null = show all).
  String? _selectedEfeCategory;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();

    // Auto-switch to regular if EFEs were unloaded
    if (_showEfe && state.efeCourses.isEmpty) {
      _showEfe = false;
      _selectedEfeCategory = null;
    }

    final allCourses = _showEfe ? state.efeCourses : state.allCourses;

    // Collect distinct EFE categories (in canonical order)
    final efeCategories =
        state.efeCourses
            .map((c) => c.tipoEfe)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort((a, b) => _efeCategoryOrder(a).compareTo(_efeCategoryOrder(b)));

    // Apply EFE category filter
    final categoryFiltered =
        (_showEfe && _selectedEfeCategory != null)
            ? allCourses
                .where((c) => c.tipoEfe == _selectedEfeCategory)
                .toList()
            : allCourses;

    // Apply search + conflict filter
    final filteredCourses = categoryFiltered.where((c) {
      final query = _normalizeSearch(_searchQuery);
      final matchesQuery =
          query.isEmpty ||
          _normalizeSearch(c.nombre).contains(query) ||
          _normalizeSearch(c.codigo).contains(query) ||
          c.secciones.any(
            (s) =>
                s.docentes.any((d) => _normalizeSearch(d).contains(query)) ||
                _normalizeSearch(s.docentePrincipal ?? '').contains(query) ||
                s.jps.any((jp) => _normalizeSearch(jp).contains(query)),
          );
      if (!matchesQuery) return false;

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
              hintText: 'Buscar por nombre, código, docente o JP...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // ── Regular / EFE toggle ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: SegmentedButton<bool>(
            segments: [
              const ButtonSegment<bool>(
                value: false,
                label: Text('Regulares'),
                icon: Icon(Icons.menu_book_outlined, size: 15),
              ),
              ButtonSegment<bool>(
                value: true,
                enabled: state.efeCourses.isNotEmpty,
                label: Text(
                  state.efeCourses.isEmpty
                      ? 'EFEs (no cargados)'
                      : 'EFEs (${state.efeCourses.length})',
                ),
                icon: const Icon(Icons.science_outlined, size: 15),
              ),
            ],
            selected: {_showEfe},
            onSelectionChanged: (s) => setState(() {
              _showEfe = s.first;
              _selectedEfeCategory = null; // reset filter on tab switch
            }),
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 4),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),

        // ── EFE category filter chips (only in EFE mode) ─────────────────
        if (_showEfe && efeCategories.isNotEmpty)
          _EfeCategoryChips(
            categories: efeCategories,
            selected: _selectedEfeCategory,
            onSelected: (cat) =>
                setState(() => _selectedEfeCategory = cat),
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
          child: filteredCourses.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _showEfe && _selectedEfeCategory != null
                          ? 'No hay cursos en esta categoría'
                          : 'Sin resultados para "$_searchQuery"',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
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

                    // EFE category badge (only shown when viewing "Todos")
                    Widget? efeBadge;
                    if (_showEfe &&
                        _selectedEfeCategory == null &&
                        course.tipoEfe != null) {
                      final catColor = _efeCategoryColor(course.tipoEfe!);
                      efeBadge = Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          _efeShortLabel(course.tipoEfe!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ExpansionTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showEfe
                                  ? course.nombre.replaceFirst('[EFE] ', '')
                                  : course.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ?curriculumTag,
                            ?efeBadge,
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
                          final hasOnlyZeroCupos = _sectionHasOnlyZeroCupos(section);
                          final conflictReason = state.getConflictReason(
                            section,
                          );
                          final hasConflict =
                              !isSelected && conflictReason != null;
                          final hasFlexibleExam =
                              !isSelected && state.hasFlexibleExam(section);
                          final sectionCupos =
                              section.sesiones
                                  .map((s) => s.cupos)
                                  .whereType<int>()
                                  .toSet()
                                  .toList()
                                ..sort();
                          final cuposLabel = sectionCupos.isEmpty
                              ? 's/d'
                              : (sectionCupos.length == 1
                                    ? '${sectionCupos.first}'
                                    : '${sectionCupos.first}-${sectionCupos.last}');

                          final sessionDetails = section.sesiones
                              .map((s) {
                                String aula = s.aula;
                                if (aula.toUpperCase().contains('VIRTUAL')) {
                                  aula = 'Virtual';
                                }
                                final tipoLabel =
                                    s.tipo.value[0] +
                                    s.tipo.value.substring(1).toLowerCase();
                                final diaStr =
                                    s.dia.isNotEmpty ? s.dia : '—';
                                final horaStr =
                                    '${s.horaInicio}-${s.horaFin}';
                                final cuposStr = s.cupos != null
                                    ? ' | cupos: ${s.cupos}'
                                    : '';
                                return '$tipoLabel: $diaStr $horaStr${aula.isNotEmpty ? ' ($aula)' : ''}$cuposStr';
                              })
                              .join('\n');

                          final docentePrincipalStr =
                              section.docentePrincipal ??
                              (section.docentes.isEmpty
                                  ? 'Sin asignar'
                                  : section.docentes.first);
                          final jpsStr = section.jps.join(', ');

                          return ListTile(
                            tileColor: hasConflict
                                ? Colors.red.shade50
                                : (hasOnlyZeroCupos
                                      ? Colors.orange.shade50
                                      : null),
                            title: Text(
                              'Seccion ${section.seccion} | Cupos: $cuposLabel${hasOnlyZeroCupos ? ' | SIN CUPO' : ''}',
                              style: TextStyle(
                                color: hasConflict
                                    ? Colors.red.shade900
                                    : (hasOnlyZeroCupos
                                          ? Colors.orange.shade900
                                          : null),
                                fontWeight: hasConflict
                                    ? FontWeight.bold
                                    : (hasOnlyZeroCupos
                                          ? FontWeight.w700
                                          : FontWeight.normal),
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
                                if (hasFlexibleExam)
                                  Text(
                                    '⚠ Tiene examen sustitutorio/rezagado — horario provisional',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                Text(
                                  sessionDetails,
                                  style: TextStyle(
                                    color: hasConflict
                                        ? Colors.red.shade700
                                        : null,
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
                                        text: 'Docente: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: docentePrincipalStr),
                                      if (section.jps.isNotEmpty)
                                        const TextSpan(
                                          text: ' | JPs: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      if (section.jps.isNotEmpty)
                                        TextSpan(text: jpsStr),
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
                                    : (hasOnlyZeroCupos
                                          ? Colors.orange.shade100
                                          : null),
                                foregroundColor: hasConflict
                                    ? Colors.red.shade900
                                    : (hasOnlyZeroCupos
                                          ? Colors.orange.shade900
                                          : null),
                              ),
                              onPressed: (isSelected || hasConflict)
                                  ? null
                                  : () async {
                                      if (hasOnlyZeroCupos) {
                                        final proceed =
                                            await showDialog<bool>(
                                              context: context,
                                              builder: (d) => AlertDialog(
                                                title: const Text('Seccion sin cupo'),
                                                content: const Text(
                                                  'Esta seccion tiene cupo 0. Puedes agregarla como referencia, pero no hay vacantes por ahora.\n\nDeseas agregarla igual?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(d, false),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(d, true),
                                                    child: const Text('Agregar igual'),
                                                  ),
                                                ],
                                              ),
                                            ) ??
                                            false;
                                        if (!proceed || !context.mounted) {
                                          return;
                                        }
                                      }
                                      try {
                                        state.addSection(course, section);
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e
                                                  .toString()
                                                  .replaceAll(
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
                                    : (hasConflict
                                          ? 'Cruza'
                                          : (hasOnlyZeroCupos ? 'Sin cupo' : 'Agregar')),
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

  bool _sectionHasOnlyZeroCupos(dynamic section) {
    final cupos = section.sesiones.map((s) => s.cupos).whereType<int>().toList();
    if (cupos.isEmpty) return false;
    return cupos.every((c) => c == 0);
  }
}

// ── EFE Category Chips widget ─────────────────────────────────────────────────

class _EfeCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final void Function(String? category) onSelected;

  const _EfeCategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "Todos" chip
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text(
                  'Todos',
                  style: TextStyle(fontSize: 12),
                ),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
                selectedColor: Colors.blueGrey.shade100,
                checkmarkColor: Colors.blueGrey.shade700,
                labelStyle: TextStyle(
                  color: selected == null
                      ? Colors.blueGrey.shade800
                      : Colors.grey.shade600,
                  fontWeight: selected == null
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
                side: BorderSide(
                  color: selected == null
                      ? Colors.blueGrey.shade400
                      : Colors.grey.shade300,
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),

            // One chip per category
            ...categories.map((cat) {
              final isSelected = selected == cat;
              final color = _efeCategoryColor(cat);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    _efeShortLabel(cat),
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  onSelected: (_) =>
                      onSelected(isSelected ? null : cat),
                  selectedColor: color.withValues(alpha: 0.15),
                  checkmarkColor: color,
                  labelStyle: TextStyle(
                    color: isSelected ? color : Colors.grey.shade700,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? color.withValues(alpha: 0.7)
                        : Colors.grey.shade300,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

}




