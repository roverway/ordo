import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/features/ai_copilot/views/ai_copilot_sheet.dart';
import 'package:ordo/features/home/widgets/home_fab.dart';

Widget _buildTestApp({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: const SizedBox.shrink(),
        floatingActionButton: child,
      ),
    ),
  );
}

void main() {
  group('HomeDoubleFab Widget Tests', () {
    testWidgets(
      'renders both native add FAB and AI assistant FAB with proper icons',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: HomeDoubleFab(onNativeAdd: () {}, onAiAssistant: () {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeDoubleFab), findsOneWidget);
        expect(find.byKey(HomeDoubleFab.nativeFabKey), findsOneWidget);
        expect(find.byKey(HomeDoubleFab.aiFabKey), findsOneWidget);

        // Icons
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      },
    );

    testWidgets('triggers onNativeAdd callback on native FAB tap', (
      tester,
    ) async {
      var nativeTapped = false;
      await tester.pumpWidget(
        _buildTestApp(
          child: HomeDoubleFab(
            onNativeAdd: () => nativeTapped = true,
            onAiAssistant: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HomeDoubleFab.nativeFabKey));
      await tester.pumpAndSettle();

      expect(nativeTapped, isTrue);
    });

    testWidgets('triggers onAiAssistant callback on AI FAB tap', (
      tester,
    ) async {
      var aiTapped = false;
      await tester.pumpWidget(
        _buildTestApp(
          child: HomeDoubleFab(
            onNativeAdd: () {},
            onAiAssistant: () => aiTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(HomeDoubleFab.aiFabKey));
      await tester.pumpAndSettle();

      expect(aiTapped, isTrue);
    });

    testWidgets(
      'AI assistant FAB follows design tokens (AppTokens.radiusButton rounded)',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: HomeDoubleFab(onNativeAdd: () {}, onAiAssistant: () {}),
          ),
        );
        await tester.pumpAndSettle();

        final aiFab = tester.widget<Material>(
          find.byKey(HomeDoubleFab.aiFabKey),
        );
        final shape = aiFab.shape;
        expect(shape, isA<RoundedRectangleBorder>());
        final roundedShape = shape as RoundedRectangleBorder;
        final borderRadius = roundedShape.borderRadius as BorderRadius;
        expect(borderRadius.topLeft.x, equals(AppTokens.radiusButton));
      },
    );

    testWidgets(
      'opens AiCopilotSheet by default when onAiAssistant callback is not provided',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: HomeDoubleFab(onNativeAdd: () {})),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(HomeDoubleFab.aiFabKey));
        await tester.pumpAndSettle();

        expect(find.byType(AiCopilotSheet), findsOneWidget);
      },
    );
  });
}
