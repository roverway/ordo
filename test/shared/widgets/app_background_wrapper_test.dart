import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/core/theme/background_config.dart';
import 'package:ordo/shared/widgets/app_background_wrapper.dart';

void main() {
  group('AppBackgroundWrapper', () {
    testWidgets(
      'renders ColoredBox with surfacePageLight in light mode when no wallpaper',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.light(),
              home: const AppBackgroundWrapper(
                overrideConfig: BackgroundConfig.none,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final coloredBox = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(AppBackgroundScope),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(coloredBox.color, AppTokens.surfacePageLight);
        expect(
          AppBackgroundScope.hasWallpaperOf(
            tester.element(find.byType(SizedBox)),
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'renders ColoredBox with surfacePageDark in dark mode when no wallpaper',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const AppBackgroundWrapper(
                overrideConfig: BackgroundConfig.none,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final coloredBox = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(AppBackgroundScope),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(coloredBox.color, AppTokens.surfacePageDark);
        expect(
          AppBackgroundScope.hasWallpaperOf(
            tester.element(find.byType(SizedBox)),
          ),
          isFalse,
        );
      },
    );
  });
}
