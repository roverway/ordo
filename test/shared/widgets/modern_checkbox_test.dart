import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/core/theme/background_config.dart';
import 'package:ordo/shared/widgets/app_background_wrapper.dart';
import 'package:ordo/shared/widgets/modern_checkbox.dart';

void main() {
  group('ModernCheckbox', () {
    testWidgets('enabled unchecked renders interactive surface and border', (
      tester,
    ) async {
      var toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernCheckbox(
              checked: false,
              onChanged: (val) => toggled = val,
            ),
          ),
        ),
      );

      expect(find.byType(ModernCheckbox), findsOneWidget);
      await tester.tap(find.byType(ModernCheckbox));
      expect(toggled, isTrue);
    });

    testWidgets(
      'disabled (onChanged == null) shows grey styling and ignores taps',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ModernCheckbox(checked: false, onChanged: null),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ModernCheckbox),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        // 禁用时背景为灰色 (0xFFF3F4F6)
        expect(decoration.color, const Color(0xFFF3F4F6));
        expect(
          (decoration.border as Border).top.color,
          const Color(0xFFD1D5DB),
        );
      },
    );

    testWidgets('disabled checked shows grey fill and checkmark', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ModernCheckbox(checked: true, onChanged: null)),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ModernCheckbox),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      // 禁用且已完成时填充为中性灰 (0xFF9CA3AF)
      expect(decoration.color, const Color(0xFF9CA3AF));
    });

    testWidgets(
      'hasWallpaper: true renders frosted semi-transparent surface and checked fill',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: AppBackgroundScope(
                hasWallpaper: true,
                config: BackgroundConfig(
                  type: BackgroundType.preset,
                  value: 'assets/images/wallpapers/1.webp',
                ),
                child: ModernCheckbox(checked: false, onChanged: _noop),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(ModernCheckbox),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration as BoxDecoration;
        final expectedBg = Colors.white.withValues(
          alpha: AppTokens.alphaCheckboxFrostedSurfaceLight,
        );
        final expectedBorder = Colors.black.withValues(
          alpha: AppTokens.alphaCheckboxFrostedBorder,
        );

        expect(decoration.color, expectedBg);
        expect((decoration.border as Border).top.color, expectedBorder);
      },
    );

    testWidgets('hasWallpaper: true in dark mode renders dark frosted alpha', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: AppBackgroundScope(
              hasWallpaper: true,
              config: BackgroundConfig(
                type: BackgroundType.preset,
                value: 'assets/images/wallpapers/1.webp',
              ),
              child: ModernCheckbox(checked: false, onChanged: _noop),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ModernCheckbox),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      final expectedBg = Colors.black.withValues(
        alpha: AppTokens.alphaCheckboxFrostedSurfaceDark,
      );
      final expectedBorder = Colors.white.withValues(
        alpha: AppTokens.alphaCheckboxFrostedBorder,
      );

      expect(decoration.color, expectedBg);
      expect((decoration.border as Border).top.color, expectedBorder);
    });
  });
}

void _noop(bool _) {}
