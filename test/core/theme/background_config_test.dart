import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/theme/background_config.dart';

void main() {
  group('BackgroundConfig Unit Tests', () {
    test('Default none config is correctly constructed', () {
      const config = BackgroundConfig.none;
      expect(config.type, BackgroundType.none);
      expect(config.value, isNull);
      expect(config.opacity, 0.35);
      expect(config.blur, 0.0);
      expect(config.fit, BackgroundFit.cover);
      expect(config.isEffective, isFalse);
    });

    test('Preset config is effective and correctly formatted', () {
      const config = BackgroundConfig(
        type: BackgroundType.preset,
        value: 'assets/images/wallpapers/wp_aurora.png',
        opacity: 0.35,
        blur: 5.0,
        fit: BackgroundFit.cover,
      );
      expect(config.isEffective, isTrue);
      expect(config.type, BackgroundType.preset);
      expect(config.value, 'assets/images/wallpapers/wp_aurora.png');
      expect(config.opacity, 0.35);
      expect(config.blur, 5.0);
    });

    test('Custom config is effective and correctly formatted', () {
      const config = BackgroundConfig(
        type: BackgroundType.custom,
        value: '/data/user/0/app/wallpapers/custom_123.jpg',
        opacity: 0.5,
        blur: 10.0,
      );
      expect(config.isEffective, isTrue);
      expect(config.type, BackgroundType.custom);
      expect(config.value, '/data/user/0/app/wallpapers/custom_123.jpg');
    });

    test('Serialization and deserialization with toJson / fromJson', () {
      const original = BackgroundConfig(
        type: BackgroundType.preset,
        value: 'assets/images/wallpapers/wp_mountain.png',
        opacity: 0.4,
        blur: 8.0,
        fit: BackgroundFit.contain,
      );

      final jsonMap = original.toJson();
      expect(jsonMap['type'], 'preset');
      expect(jsonMap['value'], 'assets/images/wallpapers/wp_mountain.png');
      expect(jsonMap['opacity'], 0.4);
      expect(jsonMap['blur'], 8.0);
      expect(jsonMap['fit'], 'contain');

      final restored = BackgroundConfig.fromJson(jsonMap);
      expect(restored, equals(original));
      expect(restored.type, BackgroundType.preset);
      expect(restored.value, original.value);
      expect(restored.opacity, 0.4);
      expect(restored.blur, 8.0);
      expect(restored.fit, BackgroundFit.contain);
    });

    test('String serialize / deserialize roundtrip', () {
      const original = BackgroundConfig(
        type: BackgroundType.custom,
        value: '/path/to/my_image.png',
        opacity: 0.15,
        blur: 12.0,
      );

      final serialized = original.serialize();
      expect(serialized, isA<String>());

      final parsed = BackgroundConfig.deserialize(serialized);
      expect(parsed, equals(original));
    });

    test('deserialize handles null, malformed or empty data gracefully', () {
      expect(BackgroundConfig.fromJson({}), equals(BackgroundConfig.none));
      expect(BackgroundConfig.deserialize(null), equals(BackgroundConfig.none));
      expect(BackgroundConfig.deserialize(''), equals(BackgroundConfig.none));
      expect(
        BackgroundConfig.deserialize('invalid json string'),
        equals(BackgroundConfig.none),
      );
    });

    test('copyWith properly modifies specified fields', () {
      const original = BackgroundConfig(
        type: BackgroundType.preset,
        value: 'assets/images/wallpapers/wp_ocean.png',
        opacity: 0.3,
        blur: 2.0,
      );

      final updated = original.copyWith(opacity: 0.6, blur: 15.0);

      expect(updated.type, BackgroundType.preset);
      expect(updated.value, 'assets/images/wallpapers/wp_ocean.png');
      expect(updated.opacity, 0.6);
      expect(updated.blur, 15.0);
      expect(updated.fit, BackgroundFit.cover);
    });

    test('Preset wallpapers metadata array is properly defined', () {
      expect(kPresetWallpapers.length, 5);
      for (final wp in kPresetWallpapers) {
        expect(wp.id, isNotEmpty);
        expect(wp.labelZh, isNotEmpty);
        expect(wp.labelEn, isNotEmpty);
        expect(wp.assetPath, startsWith('assets/images/wallpapers/'));
        expect(wp.assetPath, endsWith('.png'));
      }
    });
  });
}
