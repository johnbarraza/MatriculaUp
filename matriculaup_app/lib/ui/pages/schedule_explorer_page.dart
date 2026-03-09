import 'package:flutter/material.dart';
import '../components/schedule_explorer_panel.dart';

class ScheduleExplorerPage extends StatelessWidget {
  const ScheduleExplorerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explorador de Horarios')),
      body: const SafeArea(
        child: ScheduleExplorerPanel(closeOnApply: true),
      ),
    );
  }
}