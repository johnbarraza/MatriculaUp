import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Thin bar shown at the bottom of the main screen.
/// Contains the legal disclaimer and author credits.
class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

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
          const Expanded(
            child: Text(
              'MatriculaUp no se responsabiliza por errores en cursos con formato inusual, '
              'datos incorrectos en el JSON fuente, ni por cruces de horario no detectados. '
              'Verifica siempre tu matrícula en el sistema oficial de la universidad.',
              style: TextStyle(fontSize: 10, color: Colors.white54, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Hecho por John Barraza',
            style: TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'LinkedIn',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _open('https://www.linkedin.com/in/john-barraza-ratachi/'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.work_outline, size: 14, color: Colors.white38),
              ),
            ),
          ),
          Tooltip(
            message: 'Portfolio',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _open('https://johnbarraza.github.io/'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.code, size: 14, color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
