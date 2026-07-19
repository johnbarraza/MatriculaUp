import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  void _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Disclaimer ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 13, color: Colors.white60),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MatriculaUp no se responsabiliza por errores en cursos con formato inusual, '
                  'datos incorrectos en el JSON fuente, ni por cruces de horario no detectados. '
                  'Verifica siempre tu matrícula en el sistema oficial de la universidad.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Author credits ──���─────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Hecho por ',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const Text(
                'John Barraza',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'LinkedIn',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _open(
                    'https://www.linkedin.com/in/john-barraza-ratachi/',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: FaIcon(
                      FontAwesomeIcons.linkedin,
                      size: 16,
                      color: Color(0xFF0A66C2),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Portfolio',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _open('https://johnbarraza.github.io/'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: FaIcon(
                      FontAwesomeIcons.github,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
