// matriculaup_app/lib/ui/pages/fi_calculator_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course.dart';
import '../../store/schedule_state.dart';

class FiCalculatorPage extends StatefulWidget {
  const FiCalculatorPage({super.key});

  @override
  State<FiCalculatorPage> createState() => _FiCalculatorPageState();
}

// ── Data models ──────────────────────────────────────────────────────────────

class _CourseEntry {
  final TextEditingController name;
  final TextEditingController credits;
  final TextEditingController grade;

  _CourseEntry({String n = '', String c = '', String g = ''})
    : name = TextEditingController(text: n),
      credits = TextEditingController(text: c),
      grade = TextEditingController(text: g);

  void dispose() {
    name.dispose();
    credits.dispose();
    grade.dispose();
  }

  int? get creditValue {
    final text = credits.text.trim();
    if (text.isEmpty) return null;
    // Accept both "4" and "4.00" (JSON may use float strings)
    final d = double.tryParse(text);
    if (d == null || d <= 0) return null;
    return d.round();
  }

  double? get gradeValue =>
      double.tryParse(grade.text.trim().replaceAll(',', '.'));
}

class _BonusEntry {
  final String label;
  final TextEditingController amount;
  bool enabled;

  _BonusEntry({
    required this.label,
    required String defaultAmount,
    this.enabled = false,
  }) : amount = TextEditingController(text: defaultAmount);

  void dispose() => amount.dispose();
  double get amountValue => double.tryParse(amount.text.trim()) ?? 0;
}

// ── Course picker dialog ──────────────────────────────────────────────────────

class _CoursePickerDialog extends StatefulWidget {
  final List<Course> courses;
  const _CoursePickerDialog({required this.courses});

  @override
  State<_CoursePickerDialog> createState() => _CoursePickerDialogState();
}

class _CoursePickerDialogState extends State<_CoursePickerDialog> {
  final _searchCtrl = TextEditingController();
  late List<Course> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.courses;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.courses
          : widget.courses
                .where(
                  (c) =>
                      c.nombre.toLowerCase().contains(q) ||
                      c.codigo.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar curso'),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o código',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: _onSearch,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            c.nombre,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            c.codigo,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${c.creditos} cr.',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// ── Page state ────────────────────────────────────────────────────────────────

class _FiCalculatorPageState extends State<FiCalculatorPage> {
  bool _isCachimbo = true;

  // Cachimbo
  final List<_CourseEntry> _cRows = [];
  final List<_BonusEntry> _cBonuses = [
    _BonusEntry(label: 'Matrícula Preventiva', defaultAmount: '16'),
    _BonusEntry(label: 'Encuesta a Docentes', defaultAmount: '16'),
  ];

  // Veterano
  final List<_CourseEntry> _vRows = [];
  final _accCreditsCtrl = TextEditingController();
  final List<_BonusEntry> _vBonuses = [
    _BonusEntry(label: 'Matrícula Preventiva', defaultAmount: '3'),
    _BonusEntry(label: 'Encuesta a Docentes', defaultAmount: '3'),
    _BonusEntry(label: 'Intercambio Estudiantil', defaultAmount: '10'),
    _BonusEntry(label: 'Deportista Calificado', defaultAmount: '3'),
    _BonusEntry(label: 'REA/REDAS Destacado', defaultAmount: '3'),
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      _cRows.add(_CourseEntry());
      _vRows.add(_CourseEntry());
    }
    _loadFi();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final r in _cRows) r.dispose();
    for (final r in _vRows) r.dispose();
    for (final b in _cBonuses) b.dispose();
    for (final b in _vBonuses) b.dispose();
    _accCreditsCtrl.dispose();
    super.dispose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  static const _kFiKey = 'fi_calculator_v1';

  Future<void> _loadFi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFiKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      void applyRows(List<_CourseEntry> target, List<dynamic>? data) {
        if (data == null) return;
        for (final r in target) r.dispose();
        target.clear();
        for (final item in data) {
          final m = item as Map<String, dynamic>;
          target.add(
            _CourseEntry(
              n: m['n'] as String? ?? '',
              c: m['c'] as String? ?? '',
              g: m['g'] as String? ?? '',
            ),
          );
        }
        if (target.isEmpty) target.add(_CourseEntry());
      }

      void applyBonuses(List<_BonusEntry> bonuses, List<dynamic>? data) {
        if (data == null) return;
        for (int i = 0; i < bonuses.length && i < data.length; i++) {
          final m = data[i] as Map<String, dynamic>;
          bonuses[i].enabled = m['enabled'] as bool? ?? false;
          if (m['amount'] != null) {
            bonuses[i].amount.text = m['amount'] as String;
          }
        }
      }

      setState(() {
        applyRows(_cRows, json['cRows'] as List<dynamic>?);
        applyRows(_vRows, json['vRows'] as List<dynamic>?);
        applyBonuses(_cBonuses, json['cBonuses'] as List<dynamic>?);
        applyBonuses(_vBonuses, json['vBonuses'] as List<dynamic>?);
        if (json['accCredits'] != null) {
          _accCreditsCtrl.text = json['accCredits'] as String;
        }
        if (json['mode'] != null) {
          _isCachimbo = json['mode'] == 'cachimbo';
        }
      });
    } catch (_) {
      // Ignore load errors — start fresh
    }
  }

  Future<void> _saveFi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, String>> rowsToMap(List<_CourseEntry> rows) => rows
          .map(
            (r) => {'n': r.name.text, 'c': r.credits.text, 'g': r.grade.text},
          )
          .toList();

      List<Map<String, dynamic>> bonusesToMap(List<_BonusEntry> bonuses) =>
          bonuses
              .map((b) => {'enabled': b.enabled, 'amount': b.amount.text})
              .toList();

      await prefs.setString(
        _kFiKey,
        jsonEncode({
          'mode': _isCachimbo ? 'cachimbo' : 'veterano',
          'cRows': rowsToMap(_cRows),
          'vRows': rowsToMap(_vRows),
          'cBonuses': bonusesToMap(_cBonuses),
          'vBonuses': bonusesToMap(_vBonuses),
          'accCredits': _accCreditsCtrl.text,
        }),
      );
    } catch (_) {}
  }

  // Debounced auto-save: fires 600ms after the last setState
  Timer? _saveTimer;
  void _scheduleAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveFi);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleAutoSave();
  }

  // ── Calculations ────────────────────────────────────────────────────────────

  double? _weightedAverage(List<_CourseEntry> rows) {
    double sumNC = 0;
    int sumC = 0;
    for (final row in rows) {
      final c = row.creditValue;
      final n = row.gradeValue;
      if (c != null && c > 0 && n != null && n >= 0 && n <= 20) {
        sumNC += n * c;
        sumC += c;
      }
    }
    if (sumC == 0) return null;
    return double.parse((sumNC / sumC).toStringAsFixed(2));
  }

  int _sumCredits(List<_CourseEntry> rows) {
    int sum = 0;
    for (final row in rows) {
      final c = row.creditValue;
      final n = row.gradeValue;
      if (c != null && c > 0 && n != null) sum += c;
    }
    return sum;
  }

  double _bonusSum(List<_BonusEntry> bonuses) {
    double sum = 0;
    for (final b in bonuses) {
      if (b.enabled) sum += b.amountValue;
    }
    return sum;
  }

  ({double fi, double pp, int credits, double bonos})? _calcCachimbo() {
    final pp = _weightedAverage(_cRows);
    if (pp == null) return null;
    final sumC = _sumCredits(_cRows);
    final bonos = _bonusSum(_cBonuses);
    final fi = double.parse((pp * 10 + sumC + bonos).toStringAsFixed(1));
    return (fi: fi, pp: pp, credits: sumC, bonos: bonos);
  }

  ({double fi, double pp, int credits, double bonos})? _calcVeterano() {
    final pp = _weightedAverage(_vRows);
    if (pp == null) return null;
    final accC = int.tryParse(_accCreditsCtrl.text.trim()) ?? 0;
    final bonos = _bonusSum(_vBonuses);
    final fi = double.parse((10 * pp + accC + bonos).toStringAsFixed(1));
    return (fi: fi, pp: pp, credits: accC, bonos: bonos);
  }

  // ── Course picker ────────────────────────────────────────────────────────────

  Future<void> _pickCourse(
    BuildContext context,
    _CourseEntry row,
    List<Course> courses,
  ) async {
    final selected = await showDialog<Course>(
      context: context,
      builder: (_) => _CoursePickerDialog(courses: courses),
    );
    if (selected != null && mounted) {
      setState(() {
        row.name.text = selected.nombre;
        row.credits.text = selected.creditos;
      });
    }
  }

  // ── Builders ─────────────────────────────────────────────────────────────────

  Widget _buildCourseTable(List<_CourseEntry> rows, List<Course> courses) {
    final hasDb = courses.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  const Text(
                    'Curso',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (hasDb) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Pulsa 🔍 en cada fila para autocompletar desde la base de datos cargada',
                      child: Icon(
                        Icons.info_outline,
                        size: 13,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 68,
              child: Text(
                'Créd.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 68,
              child: Text(
                'Nota',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
        const Divider(height: 12),
        // Data rows
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Name field + optional search button
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.name,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: hasDb
                                ? 'Nombre (o busca con 🔍)'
                                : 'Nombre del curso',
                            isDense: true,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (hasDb)
                        Tooltip(
                          message: 'Buscar en cursos cargados',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () => _pickCourse(context, row, courses),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: Icon(
                                Icons.search,
                                size: 18,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Credits – editable even after autofill
                SizedBox(
                  width: 68,
                  child: TextField(
                    controller: row.credits,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '0',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      // Subtle tint when autofilled
                      filled: row.credits.text.isNotEmpty,
                      fillColor: row.credits.text.isNotEmpty
                          ? Colors.blue.shade50
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // Grade
                SizedBox(
                  width: 68,
                  child: TextField(
                    controller: row.grade,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Remove row
                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Eliminar fila',
                    onPressed: rows.length > 1
                        ? () {
                            row.dispose();
                            setState(() => rows.removeAt(i));
                          }
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Agregar curso', style: TextStyle(fontSize: 13)),
          onPressed: () => setState(() => rows.add(_CourseEntry())),
        ),
      ],
    );
  }

  Widget _buildBonuses(List<_BonusEntry> bonuses, {required bool editable}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bonuses.map((b) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Checkbox(
                value: b.enabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => b.enabled = v ?? false),
              ),
              Expanded(
                child: Text(b.label, style: const TextStyle(fontSize: 13)),
              ),
              editable
                  ? SizedBox(
                      width: 72,
                      child: TextField(
                        controller: b.amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          prefixText: '+',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    )
                  : Text(
                      '+${b.amount.text}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultCard(
    ({double fi, double pp, int credits, double bonos})? result,
  ) {
    if (result == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ingresa al menos un curso con créditos y nota para calcular el FI.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final creditsLabel = _isCachimbo
        ? 'Créditos matriculados'
        : 'Créditos acumulados';
    final formula = _isCachimbo
        ? 'PP × 10 + Créditos + Bonos  =  ${result.pp} × 10 + ${result.credits} + ${result.bonos}'
        : '10 × PP + Créditos acumulados + Bonos  =  10 × ${result.pp} + ${result.credits} + ${result.bonos}';

    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FI = ${result.fi}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('PP = ${result.pp}', Colors.blue.shade100),
                _chip(
                  '$creditsLabel = ${result.credits}',
                  Colors.blue.shade100,
                ),
                if (result.bonos > 0)
                  _chip('Bonos = +${result.bonos}', Colors.green.shade100),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$formula  =  ${result.fi}',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<ScheduleState>().allVisibleCourses;
    final result = _isCachimbo ? _calcCachimbo() : _calcVeterano();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factor de Inscripción'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Mode selector ──────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Modalidad:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('Cachimbo'),
                          selected: _isCachimbo,
                          onSelected: (_) => setState(() => _isCachimbo = true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Veterano'),
                          selected: !_isCachimbo,
                          onSelected: (_) =>
                              setState(() => _isCachimbo = false),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: _isCachimbo
                              ? 'Primera vez matriculándote en la universidad'
                              : 'Ya tienes semestres cursados anteriormente',
                          child: const Icon(
                            Icons.help_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                        if (courses.isNotEmpty) ...[
                          const Spacer(),
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'BD cargada (${courses.length} cursos)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_isCachimbo) ...[
                  // ── Cachimbo ───────────────────────────────────────────────
                  const Text(
                    'Cursos del semestre anterior',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildCourseTable(_cRows, courses),
                  const SizedBox(height: 20),
                  const Text(
                    'Bonificaciones',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  _buildBonuses(_cBonuses, editable: false),
                ] else ...[
                  // ── Veterano ───────────────────────────────────────────────
                  const Text(
                    'Cursos del último semestre académico',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Excluir cursos de verano, nivelación, retirados y desaprobados',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  _buildCourseTable(_vRows, courses),

                  const SizedBox(height: 20),

                  // ── Accumulated credits ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Créditos acumulados al último período cursado',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message:
                            'Puedes consultar tus créditos acumulados en:\nautoservicio2.up.edu.pe\n(Registro Académico → Historial)',
                        child: const Icon(
                          Icons.help_outline,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Obligatorios + Electivos + EFEs aprobados. No contar retiros, desaprobados ni nivelaciones.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  // Hint banner pointing to autoservicio
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      border: Border.all(color: Colors.amber.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Consulta tu total en ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        SelectableText(
                          'autoservicio2.up.edu.pe',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        Text(
                          '  →  Registro Académico → Historial',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _accCreditsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Créditos acumulados',
                        hintText: 'ej. 96',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Veterano bonuses ─────────────────────────────────────
                  Row(
                    children: [
                      const Text(
                        'Bonificaciones',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(modifica el valor si es diferente en tu reglamento)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildBonuses(_vBonuses, editable: true),
                ],

                const SizedBox(height: 24),

                // ── Result card ──────────────────────────────────────────────
                _buildResultCard(result),

                const SizedBox(height: 16),

                // ── Formula explanation ──────────────────────────────────────
                ExpansionTile(
                  title: const Text(
                    '¿Cómo se calcula el FI?',
                    style: TextStyle(fontSize: 13),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Cachimbo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '1. PP = Σ(Nota × Créditos) ÷ Σ(Créditos), redondeado a 2 decimales\n'
                            '2. FI = PP × 10 + Créditos matriculados + Bonificaciones\n'
                            '3. Resultado redondeado a 1 decimal',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Veterano',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '1. PP = Promedio ponderado del último semestre académico regular\n'
                            '   (solo cursos aprobados; excluir verano, nivelación, retiros, desaprobados)\n'
                            '2. FI = 10 × PP + Créditos acumulados al último período + Bonificaciones\n'
                            '   (Créditos: obligatorios + electivos + EFEs aprobados)\n'
                            '3. Resultado redondeado a 1 decimal',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
