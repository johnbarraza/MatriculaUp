import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Disclaimer ────────────────────────────────────────────────────
          const Icon(Icons.info_outline, size: 13, color: Colors.white60),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Verifica siempre tu matrícula en la fuente oficial de tu universidad.',
              style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          // ── Author credits (derecha) ───────────────────────────────────────
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
          const SizedBox(width: 8),
          Tooltip(
            message: 'LinkedIn',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _open(
                'https://www.linkedin.com/in/john-barraza-ratachi/',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: SvgPicture.asset(
                  'assets/linkedin.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF0A66C2),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Portfolio',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => _open('https://johnbarraza.github.io/'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: SvgPicture.asset(
                  'assets/github.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    Colors.white70,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
