import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/shared/widgets/animated_strikethrough.dart';

void main() {
  testWidgets('AnimatedStrikethrough renders initial active state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedStrikethrough(text: 'Test task title', isDone: false),
        ),
      ),
    );

    expect(find.text('Test task title'), findsOneWidget);
  });

  testWidgets(
    'AnimatedStrikethrough renders initial done state and animates transition',
    (tester) async {
      bool isDone = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    AnimatedStrikethrough(
                      text: 'Dynamic task title',
                      isDone: isDone,
                    ),
                    TextButton(
                      onPressed: () => setState(() => isDone = true),
                      child: const Text('Toggle'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Dynamic task title'), findsOneWidget);

      // Tap toggle
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Dynamic task title'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Dynamic task title'), findsOneWidget);
    },
  );
}
