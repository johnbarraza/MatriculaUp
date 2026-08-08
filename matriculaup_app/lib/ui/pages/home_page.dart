// matriculaup_app/lib/ui/pages/home_page.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/data_loader.dart';
import '../../store/schedule_state.dart';
import 'package:matriculaup_app/ui/components/course_search_list.dart';
import 'package:matriculaup_app/ui/components/timetable_grid.dart';
import 'package:matriculaup_app/ui/components/academic_calendar_sheet.dart';
import 'package:matriculaup_app/ui/components/donation_dialog.dart';
import 'package:matriculaup_app/ui/components/courses_summary_bar.dart';
import 'package:matriculaup_app/ui/components/disclaimer_footer.dart';
import 'package:matriculaup_app/ui/pages/fi_calculator_page.dart';
import 'package:matriculaup_app/ui/pages/grade_calculator_page.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/ics_exporter.dart';
import '../../utils/page_reload.dart';

// ── Community resources ───────────────────────────────────────────────────────
// To add a new resource, just append an entry to this list.
const _kResources = [
  _Resource(
    title: 'Sílabos REA',
    description: 'Repositorio de sílabos del programa REA · 2026-I',
    url:
        'https://drive.google.com/drive/folders/15YHaq5sXd1PXk1TfSPS125PmiXhf-62f',
    icon: Icons.description_outlined,
    tag: 'Drive',
  ),
  _Resource(
    title: 'UP Blackboard Sync',
    description:
        'Descarga todo tu material de Blackboard (PDFs, videos, archivos) '
        'para compartir con amigos o usar con LLMs.',
    url:
        'https://github.com/johnbarraza/UPBlackboardSync/releases?page=4#release-v1.0',
    icon: Icons.download_outlined,
    tag: 'GitHub',
  ),
];

class _Resource {
  final String title;
  final String description;
  final String url;
  final IconData icon;
  final String tag;

  const _Resource({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.tag,
  });
}

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onThemeModeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showExams = false;
  // Key for PNG capture of the timetable grid
  final GlobalKey _timetableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadDefaultData();
  }

  Future<void> _loadDefaultData() async {
    final state = context.read<ScheduleState>();

    final result = await DataLoader.loadDefaultCourses();
    if (result != null && mounted) {
      state.setCourses(result.courses, label: result.label);
      _checkAndAnnounceNewData(result.label);
    }

    final efeResult = await DataLoader.loadDefaultEfeCourses();
    if (efeResult != null && mounted) {
      state.setEfeCourses(efeResult.courses, label: efeResult.label);
    }

    // Restore last session now that all courses are available
    if (mounted) {
      await state.loadSession(state.allVisibleCourses);
    }

    final calendar = await DataLoader.loadCalendar();
    if (calendar != null && mounted) {
      state.setCalendar(calendar);
    }
  }

  void _openGitHub() {
    launchUrl(
      Uri.parse('https://github.com/johnbarraza/MatriculaUp'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ScheduleState>();
    final colorScheme = Theme.of(context).colorScheme;
    final courses = state.allCourses;
    final credits = state.currentCredits;
    final maxCredits = state.maxCredits;
    final hasFreeTime = state.hasTimeSlotSelection;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      drawer: isMobile
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      color: colorScheme.primary,
                      child: Text(
                        'Buscar cursos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const Expanded(child: CourseSearchList()),
                  ],
                ),
              ),
            )
          : null,
      // ── AppBar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        foregroundColor: colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MatriculaUp',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (state.coursesLabel != null)
              Text(
                'Regulares: ${state.coursesLabel!}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (state.efeCoursesLabel != null)
              Text(
                'EFEs: ${state.efeCoursesLabel!}',
                style: TextStyle(fontSize: 11, color: colorScheme.tertiary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: widget.isDarkMode
                ? 'Cambiar a modo claro'
                : 'Activar modo oscuro',
            onPressed: () => widget.onThemeModeChanged(!widget.isDarkMode),
          ),
          IconButton(
            icon: const Icon(Icons.code_outlined),
            tooltip: 'GitHub · open source · gratis · privacidad',
            onPressed: _openGitHub,
          ),
          // Clear time slots
          if (hasFreeTime)
            IconButton(
              icon: Icon(Icons.filter_alt, color: colorScheme.secondary),
              tooltip: 'Limpiar selección de horario',
              onPressed: () => state.clearTimeSlots(),
            ),
          // Credit counter
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showCreditLimitDialog(context, state),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$credits / $maxCredits cr.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: credits >= maxCredits ? colorScheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Plan A / B / C switcher (on a separate row on mobile)
          if (!isMobile)
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
          // Weekly hours chip — desktop only
          if (!isMobile && state.selectedSections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: 'Horas semanales de Clases y Prácticas',
                child: Chip(
                  avatar: Icon(
                    Icons.schedule,
                    size: 14,
                    color: colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                  label: Text(
                    '${state.weeklyHours.toStringAsFixed(1)} h/sem',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  backgroundColor: colorScheme.primary,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          if (!isMobile) ...[
            // Calculadoras
            PopupMenuButton<String>(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: 'Calculadoras',
              onSelected: (value) {
                if (value == 'fi') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FiCalculatorPage()),
                  );
                } else if (value == 'grade') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GradeCalculatorPage(),
                    ),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'fi',
                  child: Row(
                    children: [
                      Icon(Icons.leaderboard_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Factor de Inscripción'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'grade',
                  child: Row(
                    children: [
                      Icon(Icons.quiz_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('¿Cuánto me falta?'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.library_books_outlined),
              tooltip: 'Materiales de la comunidad',
              onPressed: () => _showResourcesSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Reportar bug o dar feedback',
              onPressed: () => launchUrl(
                Uri.parse('https://forms.gle/cag87CjtGhmDLaek6'),
                mode: LaunchMode.externalApplication,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.coffee_outlined),
              tooltip: 'Invítame un café ☕',
              onPressed: () => DonationDialog.show(context),
            ),
            if (state.calendar != null)
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Calendario Académico 2026-II',
                onPressed: () => _showCalendar(context, state),
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configuración',
              onPressed: () => _showSettingsSheet(context, state),
            ),
          ] else
            // Mobile: all secondary actions in one popup
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Más opciones',
              onSelected: (value) {
                switch (value) {
                  case 'fi':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FiCalculatorPage(),
                      ),
                    );
                  case 'grade':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GradeCalculatorPage(),
                      ),
                    );
                  case 'resources':
                    _showResourcesSheet(context);
                  case 'bug':
                    launchUrl(
                      Uri.parse('https://forms.gle/cag87CjtGhmDLaek6'),
                      mode: LaunchMode.externalApplication,
                    );
                  case 'donate':
                    DonationDialog.show(context);
                  case 'calendar':
                    _showCalendar(context, state);
                  case 'settings':
                    _showSettingsSheet(context, state);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'fi',
                  child: Row(
                    children: [
                      Icon(Icons.leaderboard_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Factor de Inscripción'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'grade',
                  child: Row(
                    children: [
                      Icon(Icons.quiz_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('¿Cuánto me falta?'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'resources',
                  child: Row(
                    children: [
                      Icon(Icons.library_books_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Materiales comunidad'),
                    ],
                  ),
                ),
                if (state.calendar != null)
                  const PopupMenuItem(
                    value: 'calendar',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Calendario Académico'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'donate',
                  child: Row(
                    children: [
                      Icon(Icons.coffee_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Invítame un café ☕'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'bug',
                  child: Row(
                    children: [
                      Icon(Icons.bug_report_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Reportar bug'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, size: 18),
                      SizedBox(width: 10),
                      Text('Configuración'),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 4),
        ],
        bottom: isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Center(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('A')),
                        ButtonSegment<int>(value: 1, label: Text('B')),
                        ButtonSegment<int>(value: 2, label: Text('C')),
                      ],
                      selected: <int>{state.activeScheduleIndex},
                      onSelectionChanged: (s) => state.switchSchedule(s.first),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),

      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // ── Left Panel (hidden on mobile — use Drawer instead) ─────────
                if (!isMobile)
                  Expanded(
                    flex: 3,
                    child: Container(
                      color: colorScheme.surfaceContainerLowest,
                      child: courses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.upload_file),
                                    onPressed: () async {
                                      final result =
                                          await DataLoader.pickAndLoadCourses();
                                      if (result != null && context.mounted) {
                                        context
                                            .read<ScheduleState>()
                                            .setCourses(
                                              result.courses,
                                              label: result.label,
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
                                      if (curriculum != null &&
                                          context.mounted) {
                                        context
                                            .read<ScheduleState>()
                                            .setCurriculum(curriculum);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.tertiary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  color: colorScheme.primary,
                                  child: Text(
                                    'Buscar cursos',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                const Expanded(child: CourseSearchList()),
                              ],
                            ),
                    ),
                  ),

                // ── Right Panel: Timetable ───────────────────────────────────
                Expanded(
                  flex: isMobile ? 1 : 7,
                  child: Container(
                    color: colorScheme.surface,
                    child: Column(
                      children: [
                        // ── Top controls row ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // Semana Regular / Exámenes — always reachable
                                SegmentedButton<bool>(
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
                                  style: ButtonStyle(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Exportar a Google Calendar (.ics)',
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.event_outlined,
                                      size: 20,
                                      color: state.selectedSections.isNotEmpty
                                          ? null
                                          : Colors.grey.shade400,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: state.selectedSections.isNotEmpty
                                        ? () => _exportAsIcs(context)
                                        : null,
                                  ),
                                ),
                                Tooltip(
                                  message: 'Exportar horario como PNG',
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 20,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _exportAsPng(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // ── Course summary (always visible) ─────────────────────
                        const CoursesSummaryBar(),
                        // ── Timetable ────────────────────────────────────────────
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
          ),
          // ── Disclaimer footer ────────────────────────────────────────────
          const DisclaimerFooter(),
        ],
      ),
    );
  }

  // ── New data announcement ─────────────────────────────────────────────────
  Future<void> _checkAndAnnounceNewData(String currentLabel) async {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.new_releases_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text('Datos actualizados'),
            ],
          ),
          content: Text(
            'La app ahora usa la oferta academica V5:\n\n$currentLabel\n\n'
            'MatriculaUp es gratis y de codigo abierto. Tus horarios se guardan '
            'solo en tu dispositivo; no los enviamos ni almacenamos en servidores.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  // ── Academic Calendar ─────────────────────────────────────────────────────
  void _showCalendar(BuildContext context, ScheduleState state) {
    if (state.calendar == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AcademicCalendarSheet(calendar: state.calendar!),
    );
  }

  // ── ICS Export ───────────────────────────────────────────────────────────
  Future<void> _exportAsIcs(BuildContext context) async {
    final state = context.read<ScheduleState>();
    if (state.selectedSections.isEmpty) return;

    try {
      final bytes = IcsExporter.generateBytes(
        state.selectedSections,
        state.calendar,
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar horario a calendario (.ics)',
        fileName: 'horario_matriculaup.ics',
        type: FileType.custom,
        allowedExtensions: ['ics'],
        bytes: bytes,
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado en: $path'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    }
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                widget.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              title: const Text('Modo oscuro'),
              subtitle: const Text('Tema con contraste alto para leer mejor'),
              value: widget.isDarkMode,
              onChanged: (value) {
                widget.onThemeModeChanged(value);
                Navigator.pop(ctx);
              },
            ),
            if (state.coursesLabel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Regulares activos: ${state.coursesLabel}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (state.efeCoursesLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'EFEs activos: ${state.efeCoursesLabel}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Actualizar Horarios (JSON)'),
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await DataLoader.pickAndLoadCourses();
                if (result != null && context.mounted) {
                  context.read<ScheduleState>().setCourses(
                    result.courses,
                    label: result.label,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Cargados ${result.courses.length} cursos · ${result.label}',
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            // ── EFE courses ──────────────────────────────────────────────
            if (state.efeCoursesLabel != null) ...[
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'EFEs activos: ${state.efeCoursesLabel}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.science_outlined),
              label: Text(
                state.efeCoursesLabel == null
                    ? 'Cargar EFEs (JSON)'
                    : 'Reemplazar EFEs (JSON)',
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await DataLoader.pickAndLoadCourses();
                if (result != null && context.mounted) {
                  context.read<ScheduleState>().setEfeCourses(
                    result.courses,
                    label: result.label,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'EFEs cargados: ${result.courses.length} cursos · ${result.label}',
                      ),
                    ),
                  );
                }
              },
            ),
            if (state.efeCoursesLabel != null) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                icon: const Icon(Icons.close, color: Colors.orange, size: 16),
                label: const Text(
                  'Quitar EFEs',
                  style: TextStyle(color: Colors.orange),
                ),
                onPressed: () {
                  context.read<ScheduleState>().clearEfeCourses();
                  Navigator.pop(ctx);
                },
              ),
            ],
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
            const Divider(height: 24),
            // ── Session ───────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.save_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const Text(
                  'Los horarios seleccionados se guardan automáticamente.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red,
              ),
              label: const Text(
                'Limpiar sesión guardada',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Limpiar sesión'),
                    content: const Text(
                      '¿Eliminar todos los cursos seleccionados y restablecer la configuración?\n\nEsta acción no se puede deshacer.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<ScheduleState>().clearSession();
                  reloadPage();
                }
              },
            ),
            const Divider(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.code_outlined),
              label: const Text('Ver codigo en GitHub'),
              onPressed: () {
                Navigator.pop(ctx);
                _openGitHub();
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Open source, gratis y sin enviar tus horarios a servidores.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            const Divider(height: 24),
            // ── Donation ─────────────────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.coffee_outlined, color: Color(0xFF6B0096)),
              label: const Text(
                'Invítame un café ☕',
                style: TextStyle(color: Color(0xFF6B0096)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6B0096)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                DonationDialog.show(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Community Resources Sheet ─────────────────────────────────────────────
  void _showResourcesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.library_books_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Materiales de la comunidad',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Tooltip(
                  message: '¿Tienes material para aportar? Contáctanos',
                  child: Icon(
                    Icons.volunteer_activism_outlined,
                    size: 16,
                    color: Colors.pink.shade300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Recursos compartidos por y para la comunidad UP',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),
            ..._kResources.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(r.icon, size: 20, color: Colors.blue.shade700),
                ),
                title: Text(
                  r.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  r.description,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(r.tag),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(r.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
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
