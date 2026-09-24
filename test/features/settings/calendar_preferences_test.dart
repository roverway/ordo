import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ordo/core/db/daos/settings_dao.dart';
import 'package:ordo/features/settings/settings_providers.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('calendarShowLunarProvider & calendarShowHolidaysProvider', () {
    test('默认均为 true；修改后写入缓存并穿透 DAO，重启后保留', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final settings = SettingsDao(db);
      final cache = AppSettingsCache()..attach(settings);
      final container = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);

      // 默认均为 true
      expect(container.read(calendarShowLunarProvider), isTrue);
      expect(container.read(calendarShowHolidaysProvider), isTrue);

      // 切换为 false
      await container
          .read(calendarShowLunarProvider.notifier)
          .setShowLunar(false);
      await container
          .read(calendarShowHolidaysProvider.notifier)
          .setShowHolidays(false);

      expect(container.read(calendarShowLunarProvider), isFalse);
      expect(container.read(calendarShowHolidaysProvider), isFalse);
      expect(cache.get(calendarShowLunarPrefKey), 'false');
      expect(cache.get(calendarShowHolidaysPrefKey), 'false');
      expect(await settings.get(calendarShowLunarPrefKey), 'false');
      expect(await settings.get(calendarShowHolidaysPrefKey), 'false');

      // 模拟重启：新缓存 attach 同一 DAO 并读取数据库全量设置
      final cache2 = AppSettingsCache()..attach(settings);
      cache2.seed(await settings.getAll());
      final container2 = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache2)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(calendarShowLunarProvider), isFalse);
      expect(container2.read(calendarShowHolidaysProvider), isFalse);
    });
  });
}
