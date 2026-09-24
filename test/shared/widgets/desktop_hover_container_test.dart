import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/shared/widgets/desktop_hover_container.dart';

void main() {
  testWidgets(
    'DesktopHoverContainer renders child and responds to hover & tap',
    (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopHoverContainer(
              onTap: () => tapped = true,
              builder: (context, isHovered) {
                return Text(isHovered ? 'Hovered' : 'Normal');
              },
            ),
          ),
        ),
      );

      expect(find.text('Normal'), findsOneWidget);

      // Simulate hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(
        tester.getCenter(find.byType(DesktopHoverContainer)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hovered'), findsOneWidget);

      // Tap
      await tester.tap(find.byType(DesktopHoverContainer));
      expect(tapped, isTrue);
    },
  );
}
