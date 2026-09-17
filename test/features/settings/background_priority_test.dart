import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/theme/background_config.dart';
import 'package:todo/features/settings/settings_providers.dart';

void main() {
  group('Background Priority Provider Tests', () {
    test(
      'effectiveBackgroundConfigProvider returns none when both are none',
      () {
        final container = ProviderContainer(
          overrides: [
            appBackgroundConfigProvider.overrideWith(
              () => _MockAppBackgroundNotifier(BackgroundConfig.none),
            ),
            projectBackgroundConfigProvider('proj-1').overrideWith(
              () => _MockProjectBackgroundNotifier(BackgroundConfig.none),
            ),
          ],
        );
        addTearDown(container.dispose);

        final effective = container.read(
          effectiveBackgroundConfigProvider('proj-1'),
        );
        expect(effective, equals(BackgroundConfig.none));
        expect(effective.isEffective, isFalse);
      },
    );

    test(
      'effectiveBackgroundConfigProvider falls back to app level when project level is none',
      () {
        const globalConfig = BackgroundConfig(
          type: BackgroundType.preset,
          value: 'assets/images/wallpapers/wp_aurora.png',
          opacity: 0.4,
        );

        final container = ProviderContainer(
          overrides: [
            appBackgroundConfigProvider.overrideWith(
              () => _MockAppBackgroundNotifier(globalConfig),
            ),
            projectBackgroundConfigProvider('proj-1').overrideWith(
              () => _MockProjectBackgroundNotifier(BackgroundConfig.none),
            ),
          ],
        );
        addTearDown(container.dispose);

        final effective = container.read(
          effectiveBackgroundConfigProvider('proj-1'),
        );
        expect(effective, equals(globalConfig));
        expect(effective.value, 'assets/images/wallpapers/wp_aurora.png');
      },
    );

    test(
      'effectiveBackgroundConfigProvider prioritizes project level over app level',
      () {
        const globalConfig = BackgroundConfig(
          type: BackgroundType.preset,
          value: 'assets/images/wallpapers/wp_aurora.png',
          opacity: 0.4,
        );
        const projectConfig = BackgroundConfig(
          type: BackgroundType.preset,
          value: 'assets/images/wallpapers/wp_mountain.png',
          opacity: 0.6,
        );

        final container = ProviderContainer(
          overrides: [
            appBackgroundConfigProvider.overrideWith(
              () => _MockAppBackgroundNotifier(globalConfig),
            ),
            projectBackgroundConfigProvider(
              'proj-1',
            ).overrideWith(() => _MockProjectBackgroundNotifier(projectConfig)),
          ],
        );
        addTearDown(container.dispose);

        final effective = container.read(
          effectiveBackgroundConfigProvider('proj-1'),
        );
        expect(effective, equals(projectConfig));
        expect(effective.value, 'assets/images/wallpapers/wp_mountain.png');
      },
    );

    test(
      'effectiveBackgroundConfigProvider with null projectId returns app level directly',
      () {
        const globalConfig = BackgroundConfig(
          type: BackgroundType.preset,
          value: 'assets/images/wallpapers/wp_mist.png',
          opacity: 0.5,
        );

        final container = ProviderContainer(
          overrides: [
            appBackgroundConfigProvider.overrideWith(
              () => _MockAppBackgroundNotifier(globalConfig),
            ),
          ],
        );
        addTearDown(container.dispose);

        final effective = container.read(
          effectiveBackgroundConfigProvider(null),
        );
        expect(effective, equals(globalConfig));
      },
    );
  });
}

class _MockAppBackgroundNotifier extends AppBackgroundConfigNotifier {
  _MockAppBackgroundNotifier(this._initial);
  final BackgroundConfig _initial;

  @override
  BackgroundConfig build() => _initial;
}

class _MockProjectBackgroundNotifier extends ProjectBackgroundConfigNotifier {
  _MockProjectBackgroundNotifier(this._initial) : super('test');
  final BackgroundConfig _initial;

  @override
  BackgroundConfig build() => _initial;
}
