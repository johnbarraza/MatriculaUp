import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:matriculaup_app/main.dart';
import 'package:matriculaup_app/store/schedule_state.dart';

void main() {
  testWidgets('MatriculaUp shell renders with schedule provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ScheduleState(),
        child: const MyApp(),
      ),
    );

    await tester.pump();

    expect(find.text('MatriculaUp'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
