import 'package:flutter/material.dart';

/// Thin disclaimer bar shown at the bottom of the main screen.
class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 13, color: Colors.white54),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'MatriculaUp no se responsabiliza por errores en cursos con formato inusual, '
              'datos incorrectos en el JSON fuente, ni por cruces de horario no detectados. '
              'Verifica siempre tu matrícula en el sistema oficial de la universidad.',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
