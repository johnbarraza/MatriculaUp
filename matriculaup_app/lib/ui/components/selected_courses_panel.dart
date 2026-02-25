// matriculaup_app/lib/ui/components/selected_courses_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/schedule_state.dart';

/// A panel listing all selected courses for the active schedule plan.
/// Each row shows the course name, section, credits, and a delete button.
class SelectedCoursesPanel extends StatelessWidget {
  const SelectedCoursesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final selections = state.selectedSections;

    if (selections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No hay cursos seleccionados.\nAgrega cursos desde el buscador.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: selections.length,
      itemBuilder: (context, i) {
        final sel = selections[i];
        final credits = double.tryParse(sel.course.creditos)?.round() ?? 0;

        return ListTile(
          dense: true,
          leading: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 18,
          ),
          title: Text(
            sel.course.nombre,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${sel.course.codigo} · Sec ${sel.section.seccion} · $credits cr.',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Quitar del horario',
            onPressed: () => state.removeSection(sel.course, sel.section),
          ),
        );
      },
    );
  }
}
