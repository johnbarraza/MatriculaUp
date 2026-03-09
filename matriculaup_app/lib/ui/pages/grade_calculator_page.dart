// matriculaup_app/lib/ui/pages/grade_calculator_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GradeCalculatorPage extends StatefulWidget {
  const GradeCalculatorPage({super.key});

  @override
  State<GradeCalculatorPage> createState() => _GradeCalculatorPageState();
}

// ── Data model ────────────────────────────────────────────────────────────────

/// Categories used to sort evaluations in the canonical order.
enum _EvalCategory {
  pc, // PCs, controles de lectura, problem sets, quizzes
  ep, // Examen Parcial
  ef, // Examen Final
  other, // Anything else
}

_EvalCategory _inferCategory(String name) {
  final n = name.trim().toUpperCase();
  if (n.contains('FINAL') || n.startsWith('EF')) return _EvalCategory.ef;
  if (n.contains('PARCIAL') || n.startsWith('EP') || n == 'MIDTERM') {
    return _EvalCategory.ep;
  }
  return _EvalCategory.pc; // PC, CL, PS, quiz, tarea, etc.
}

int _categorySortOrder(_EvalCategory cat) {
  switch (cat) {
    case _EvalCategory.pc:
      return 0;
    case _EvalCategory.ep:
      return 1;
    case _EvalCategory.ef:
      return 2;
    case _EvalCategory.other:
      return 3;
  }
}

class _EvalEntry {
  final TextEditingController name;
  final TextEditingController weight;
  final TextEditingController grade;

  _EvalEntry({String n = '', String w = ''})
    : name = TextEditingController(text: n),
      weight = TextEditingController(text: w),
      grade = TextEditingController();

  void dispose() {
    name.dispose();
    weight.dispose();
    grade.dispose();
  }

  double? get weightValue =>
      double.tryParse(weight.text.trim().replaceAll(',', '.'));
  double? get gradeValue =>
      double.tryParse(grade.text.trim().replaceAll(',', '.'));
  bool get hasGrade => gradeValue != null;

  _EvalCategory get category => _inferCategory(name.text);
}

// ── Result model ──────────────────────────────────────────────────────────────

class _CalcResult {
  final double completedWeighted;
  final double completedWeightPct;
  final double pendingWeightPct;
  final double totalWeightPct;
  final double passing;

  const _CalcResult({
    required this.completedWeighted,
    required this.completedWeightPct,
    required this.pendingWeightPct,
    required this.totalWeightPct,
    required this.passing,
  });

  double? get currentNote {
    if (completedWeightPct == 0) return null;
    return completedWeighted / (completedWeightPct / 100);
  }

  double? get neededGrade {
    if (pendingWeightPct == 0) return null;
    return (passing - completedWeighted) / (pendingWeightPct / 100);
  }

  double get maxAchievable => completedWeighted + (pendingWeightPct / 100) * 20;
}

// ── Group-weight dialog ────────────────────────────────────────────────────────

/// Lets the user set a TOTAL % for a group (e.g. all PCs = 45 %)
/// and distribute it evenly among N entries of that type.
class _GroupWeightDialog extends StatefulWidget {
  final String groupLabel;
  final int count;
  final double currentTotal;

  const _GroupWeightDialog({
    required this.groupLabel,
    required this.count,
    required this.currentTotal,
  });

  @override
  State<_GroupWeightDialog> createState() => _GroupWeightDialogState();
}

class _GroupWeightDialogState extends State<_GroupWeightDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentTotal > 0
          ? widget.currentTotal.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(_ctrl.text) ?? 0;
    final each = widget.count > 0 ? total / widget.count : 0;

    return AlertDialog(
      title: Text('Distribuir: ${widget.groupLabel}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresa el porcentaje TOTAL del grupo y lo divido entre '
            '${widget.count} ${widget.count == 1 ? 'evaluación' : 'evaluaciones'}.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Total del grupo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (widget.count > 0 && total > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Cada ${widget.groupLabel.toLowerCase()}: '
                '${each.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: total > 0 && widget.count > 0
              ? () => Navigator.pop(context, total)
              : null,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

// ── Page state ────────────────────────────────────────────────────────────────

class _GradeCalculatorPageState extends State<GradeCalculatorPage> {
  final List<_EvalEntry> _rows = [];
  final _passingCtrl = TextEditingController(text: '10.5');

  @override
  void initState() {
    super.initState();
    _rows.addAll([
      _EvalEntry(n: 'PC1', w: '15'),
      _EvalEntry(n: 'PC2', w: '15'),
      _EvalEntry(n: 'PC3', w: '15'),
      _EvalEntry(n: 'Examen Parcial', w: '25'),
      _EvalEntry(n: 'Examen Final', w: '30'),
    ]);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _passingCtrl.dispose();
    super.dispose();
  }

  // ── Calculation ───────────────────────────────────────────────────────────

  _CalcResult _calculate() {
    final passing =
        double.tryParse(_passingCtrl.text.trim().replaceAll(',', '.')) ?? 10.5;
    double completedWeighted = 0;
    double completedWeightPct = 0;
    double pendingWeightPct = 0;
    double totalWeightPct = 0;

    for (final row in _rows) {
      final w = row.weightValue;
      if (w == null || w <= 0) continue;
      totalWeightPct += w;
      if (row.hasGrade) {
        completedWeighted += row.gradeValue! * w / 100;
        completedWeightPct += w;
      } else {
        pendingWeightPct += w;
      }
    }

    return _CalcResult(
      completedWeighted: completedWeighted,
      completedWeightPct: completedWeightPct,
      pendingWeightPct: pendingWeightPct,
      totalWeightPct: totalWeightPct,
      passing: passing,
    );
  }

  // ── Sort rows ─────────────────────────────────────────────────────────────

  /// Reorder rows: PCs/CLs first, then EP, then EF. Stable within each group.
  void _autoSortRows() {
    setState(() {
      _rows.sort((a, b) {
        final order = _categorySortOrder(
          a.category,
        ).compareTo(_categorySortOrder(b.category));
        return order;
      });
    });
  }

  // ── Group-weight distribution ─────────────────────────────────────────────

  /// Returns distinct group labels for PC-type evals (without trailing digits).
  List<String> _pcGroupNames() {
    final seen = <String>{};
    final result = <String>[];
    for (final row in _rows) {
      if (row.category == _EvalCategory.pc) {
        // Strip trailing digits to get group name (PC1→PC, CL1→CL, etc.)
        final groupName = row.name.text
            .trim()
            .replaceAll(RegExp(r'\d+$'), '')
            .trim();
        final key = groupName.isEmpty ? 'PC' : groupName;
        if (seen.add(key)) result.add(key);
      }
    }
    return result;
  }

  Future<void> _showGroupWeightDialog(String groupPrefix) async {
    // Find matching rows
    final matching = _rows.where((r) {
      final base = r.name.text.trim().replaceAll(RegExp(r'\d+$'), '').trim();
      return r.category == _EvalCategory.pc &&
          (base.isEmpty ? 'PC' : base) == groupPrefix;
    }).toList();

    if (matching.isEmpty) return;

    final currentTotal = matching.fold<double>(
      0,
      (s, r) => s + (r.weightValue ?? 0),
    );

    final newTotal = await showDialog<double>(
      context: context,
      builder: (_) => _GroupWeightDialog(
        groupLabel: groupPrefix.isEmpty ? 'PC' : groupPrefix,
        count: matching.length,
        currentTotal: currentTotal,
      ),
    );

    if (newTotal != null && mounted) {
      final each = newTotal / matching.length;
      setState(() {
        for (final row in matching) {
          row.weight.text = each.toStringAsFixed(2);
        }
      });
    }
  }

  // ── Preset evaluations ────────────────────────────────────────────────────

  void _applyPreset(List<({String name, String weight})> preset) {
    for (final r in _rows) {
      r.dispose();
    }
    setState(() {
      _rows.clear();
      for (final p in preset) {
        _rows.add(_EvalEntry(n: p.name, w: p.weight));
      }
    });
  }

  // ── Builders ──────────────────────────────────────────────────────────────

  Widget _buildResultCard(_CalcResult r) {
    if (r.completedWeightPct == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ingresa al menos una nota para ver el resultado.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // All completed
    if (r.pendingWeightPct == 0) {
      final final_ = r.completedWeighted;
      final passes = final_ >= r.passing;
      return Card(
        color: passes ? Colors.green.shade50 : Colors.red.shade50,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nota Final: ${final_.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: passes ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                passes
                    ? '✓ Aprobado (≥ ${r.passing})'
                    : '✗ Desaprobado (< ${r.passing})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: passes ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Has pending evals
    final needed = r.neededGrade;
    final bool impossible =
        needed == null || needed > 20 || r.maxAchievable < r.passing;
    final bool alreadyPassing = needed != null && needed <= 0;

    Color cardColor;
    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (impossible) {
      cardColor = Colors.red.shade50;
      statusText =
          'Imposible aprobar aunque saques 20 en todo (máx: ${r.maxAchievable.toStringAsFixed(2)})';
      statusIcon = Icons.cancel_outlined;
      statusColor = Colors.red.shade700;
    } else if (alreadyPassing) {
      cardColor = Colors.green.shade50;
      statusText =
          '¡Ya tienes el aprobado asegurado aunque saques 0 en los pendientes!';
      statusIcon = Icons.check_circle_outline;
      statusColor = Colors.green.shade700;
    } else {
      final isComfy = needed <= 12;
      cardColor = isComfy ? Colors.green.shade50 : Colors.orange.shade50;
      statusText = isComfy ? 'Alcanzable' : 'Exigente pero posible';
      statusIcon = isComfy
          ? Icons.sentiment_satisfied_outlined
          : Icons.sentiment_neutral_outlined;
      statusColor = isComfy ? Colors.green.shade700 : Colors.orange.shade700;
    }

    return Card(
      color: cardColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip(
                  'Nota acumulada: ${r.currentNote?.toStringAsFixed(2) ?? '—'}',
                  Colors.blue.shade100,
                ),
                _chip(
                  'Rendido: ${r.completedWeightPct.toStringAsFixed(0)}%',
                  Colors.blue.shade100,
                ),
                _chip(
                  'Pendiente: ${r.pendingWeightPct.toStringAsFixed(0)}%',
                  Colors.orange.shade100,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!impossible && !alreadyPassing) ...[
              const Text(
                'Para aprobar, necesitas al menos:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                needed.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: needed <= 12
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
              Text(
                'en cada evaluación pendiente',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(statusIcon, size: 18, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final result = _calculate();
    final totalOk = (result.totalWeightPct - 100).abs() < 0.5;
    final pcGroups = _pcGroupNames();

    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Cuánto me falta para aprobar?'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Passing grade ────────────────────────────────────────────
                Row(
                  children: [
                    const Text(
                      'Nota mínima aprobatoria:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _passingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Presets ──────────────────────────────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Plantillas:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    ActionChip(
                      label: const Text(
                        '3PCs + EP + EF',
                        style: TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _applyPreset([
                        (name: 'PC1', weight: '15'),
                        (name: 'PC2', weight: '15'),
                        (name: 'PC3', weight: '15'),
                        (name: 'Examen Parcial', weight: '25'),
                        (name: 'Examen Final', weight: '30'),
                      ]),
                    ),
                    ActionChip(
                      label: const Text(
                        '4PCs + EP + EF',
                        style: TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _applyPreset([
                        (name: 'PC1', weight: '11'),
                        (name: 'PC2', weight: '11'),
                        (name: 'PC3', weight: '11'),
                        (name: 'PC4', weight: '12'),
                        (name: 'Examen Parcial', weight: '25'),
                        (name: 'Examen Final', weight: '30'),
                      ]),
                    ),
                    ActionChip(
                      label: const Text(
                        'PS + CL + EP + EF',
                        style: TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _applyPreset([
                        (name: 'Problem Set 1', weight: '15'),
                        (name: 'Problem Set 2', weight: '15'),
                        (name: 'Control Lectura 1', weight: '8'),
                        (name: 'Control Lectura 2', weight: '7'),
                        (name: 'Examen Parcial', weight: '25'),
                        (name: 'Examen Final', weight: '30'),
                      ]),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Group-weight distribution chips ──────────────────────────
                if (pcGroups.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Distribuir % en grupo:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      ...pcGroups.map(
                        (g) => ActionChip(
                          avatar: const Icon(Icons.pie_chart_outline, size: 14),
                          label: Text(
                            g.isEmpty ? 'PCs' : '${g}s',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showGroupWeightDialog(g),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // ── Auto-order button ────────────────────────────────────────
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.sort, size: 16),
                      label: const Text(
                        'Ordenar (PCs → EP → EF)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.indigo.shade600,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _autoSortRows,
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Table header ─────────────────────────────────────────────
                Row(
                  children: const [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Evaluación',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 68,
                      child: Text(
                        'Peso %',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 68,
                      child: Text(
                        'Nota',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    SizedBox(width: 32),
                  ],
                ),
                const Divider(height: 12),

                // ── Table rows ───────────────────────────────────────────────
                ..._rows.asMap().entries.map((e) {
                  final i = e.key;
                  final row = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: row.name,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Evaluación',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              filled: !row.hasGrade,
                              fillColor: !row.hasGrade
                                  ? Colors.orange.shade50
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 68,
                          child: TextField(
                            controller: row.weight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: '0',
                              isDense: true,
                              border: OutlineInputBorder(),
                              suffixText: '%',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 68,
                          child: TextField(
                            controller: row.grade,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: '—',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              filled: row.hasGrade,
                              fillColor: row.hasGrade
                                  ? Colors.green.shade50
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
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
                            tooltip: 'Eliminar evaluación',
                            onPressed: () {
                              row.dispose();
                              setState(() => _rows.removeAt(i));
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // ── Add row + weight total ────────────────────────────────────
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'Agregar evaluación',
                        style: TextStyle(fontSize: 13),
                      ),
                      onPressed: () => setState(() => _rows.add(_EvalEntry())),
                    ),
                    const Spacer(),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: totalOk
                            ? Colors.green.shade700
                            : result.totalWeightPct > 100
                            ? Colors.red.shade700
                            : Colors.orange.shade700,
                      ),
                      child: Text(
                        totalOk
                            ? 'Total: 100% ✓'
                            : 'Total: ${result.totalWeightPct.toStringAsFixed(0)}% (debe ser 100%)',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Legend ───────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: Colors.green.shade50,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Nota ingresada',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 12,
                      height: 12,
                      color: Colors.orange.shade50,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Pendiente',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Result card ──────────────────────────────────────────────
                _buildResultCard(result),

                const SizedBox(height: 16),

                // ── How it works ─────────────────────────────────────────────
                ExpansionTile(
                  title: const Text(
                    '¿Cómo se calcula?',
                    style: TextStyle(fontSize: 13),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '• Ingresa la nota en las evaluaciones ya rendidas; deja en blanco las pendientes.\n'
                            '• "Distribuir % en grupo" reparte el % total entre las evaluaciones del mismo tipo (PC1, PC2, etc.).\n'
                            '• El botón "Ordenar" pone PCs y controles primero, luego EP y finalmente EF.\n'
                            '• La nota mínima mostrada asume que obtienes la misma nota en TODAS las evaluaciones pendientes.\n'
                            '• Fórmula: Nota necesaria = (Meta − Σ(nota × peso/100)) ÷ (Σ pesos pendientes / 100)\n'
                            '• Rango de notas: 0 a 20.',
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
