import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/shared/widgets/modern_segmented_control.dart';

void main() {
  group('ModernSegmentedControl tests', () {
    testWidgets(
      'renders items and handles taps with sliding animation (expanded)',
      (tester) async {
        String selected = 'tab1';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return SizedBox(
                    width: 300,
                    child: ModernSegmentedControl<String>(
                      selectedValue: selected,
                      onChanged: (val) {
                        setState(() {
                          selected = val;
                        });
                      },
                      items: const [
                        ModernSegmentItem(value: 'tab1', label: 'Tab 1'),
                        ModernSegmentItem(value: 'tab2', label: 'Tab 2'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Tab 1'), findsOneWidget);
        expect(find.text('Tab 2'), findsOneWidget);

        final animatedPositionedFinder = find.byType(AnimatedPositioned);
        expect(animatedPositionedFinder, findsOneWidget);

        AnimatedPositioned indicator = tester.widget(animatedPositionedFinder);
        expect(indicator.left, closeTo(3.0, 0.5));

        // Tap Tab 2
        await tester.tap(find.text('Tab 2'));
        await tester.pump(); // Start animation frame
        await tester.pump(
          const Duration(milliseconds: 100),
        ); // Midway animation

        // Should be moving
        indicator = tester.widget(animatedPositionedFinder);
        expect(indicator.left, greaterThan(3.0));

        await tester.pumpAndSettle(); // Complete spring animation

        indicator = tester.widget(animatedPositionedFinder);
        expect(indicator.left, greaterThan(100.0));
        expect(selected, 'tab2');
      },
    );

    testWidgets('renders items and handles taps (compact / non-expanded)', (
      tester,
    ) async {
      String selected = 'a';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ModernSegmentedControl<String>(
                  isExpanded: false,
                  selectedValue: selected,
                  onChanged: (val) {
                    setState(() {
                      selected = val;
                    });
                  },
                  items: const [
                    ModernSegmentItem(value: 'a', label: 'Alpha'),
                    ModernSegmentItem(value: 'b', label: 'Beta'),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      final animatedPositionedFinder = find.byType(AnimatedPositioned);
      expect(animatedPositionedFinder, findsOneWidget);

      AnimatedPositioned indicator = tester.widget(animatedPositionedFinder);
      final initialLeft = indicator.left;

      // Tap Beta
      await tester.tap(find.text('Beta'));
      await tester.pump();
      await tester.pumpAndSettle();

      indicator = tester.widget(animatedPositionedFinder);
      expect(indicator.left, greaterThan(initialLeft!));
      expect(selected, 'b');
    });
  });
}
