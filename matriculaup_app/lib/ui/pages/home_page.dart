// matriculaup_app/lib/ui/pages/home_page.dart
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  // Key for PNG capture of the timetable grid
  final GlobalKey _timetableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDefaultData();
  }

  Future<void> _loadDefaultData() async {
    try {
      final String contents = await rootBundle.loadString(
        'assets/default_courses.json',
      );
      final Map<String, dynamic> jsonData = jsonDecode(contents);
      final List<dynamic> coursesList = jsonData['cursos'] ?? [];
      final courses = coursesList.map((c) => Course.fromJson(c)).toList();
      if (mounted) {
        context.read<ScheduleState>().setCourses(courses);
      }
    } catch (e) {
      debugPrint("No default courses found or error loading: $e");
    }
  }

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
          // Weekly hours chip
          if (state.selectedSections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: 'Horas semanales de Clases y Prácticas',
                child: Chip(
                  avatar: const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.white70,
                  ),
                  label: Text(
                    '${state.weeklyHours.toStringAsFixed(1)} h/sem',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
            onPressed: () => _showSettingsSheet(context, state),
          ),
          // PNG Export button
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Exportar horario como PNG',
            onPressed: () => _exportAsPng(context),
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
                  Expanded(
                    child: TimetableGrid(
                      showExams: _showExams,
                      exportKey: _timetableKey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PNG Export ────────────────────────────────────────────────────────────
  Future<void> _exportAsPng(BuildContext context) async {
    try {
      final boundary =
          _timetableKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar horario como PNG',
        fileName: 'horario_matriculaup.png',
        type: FileType.image,
        allowedExtensions: ['png'],
        bytes: bytes,
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Guardado en: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
  }

  // ── Settings Bottom Sheet ─────────────────────────────────────────────────
  Future<void> _showSettingsSheet(
    BuildContext context,
    ScheduleState state,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Configuración',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Actualizar Horarios (JSON)'),
              onPressed: () async {
                Navigator.pop(ctx);
                final loaded = await DataLoader.pickAndLoadCourses();
                if (loaded != null && context.mounted) {
                  context.read<ScheduleState>().setCourses(loaded);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cargados ${loaded.length} cursos')),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.school),
              label: const Text('Cargar Plan de Estudios (Opcional)'),
              onPressed: () async {
                Navigator.pop(ctx);
                final curriculum = await DataLoader.pickAndLoadCurriculum();
                if (curriculum != null && context.mounted) {
                  context.read<ScheduleState>().setCurriculum(curriculum);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Plan "${curriculum.title}" cargado'),
                    ),
                  );
                }
              },
            ),
            if (state.curriculum != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text(
                  'Quitar plan de estudios',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  context.read<ScheduleState>().setCurriculum(null);
                  Navigator.pop(ctx);
                },
              ),
            ],
            const SizedBox(height: 8),
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
