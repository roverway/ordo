import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/utils/calendar_day_decorator.dart';
import 'package:ordo/features/calendar/calendar_page.dart';
import 'package:ordo/features/calendar/calendar_providers.dart';
import 'package:ordo/features/projects/project_providers.dart';
import 'package:ordo/features/settings/settings_page.dart';
import 'package:ordo/features/settings/settings_providers.dart';
import 'package:ordo/features/tags/tag_providers.dart';

class _FixedCalendarNotifier extends CalendarNotifier {
  _FixedCalendarNotifier(this._fixed);

  final CalendarState _fixed;

  @override
  CalendarState build() => _fixed;
}

Widget _buildTestCalendarApp({
  required DateTime selectedDate,
  required AppSettingsCache cache,
  StreamController<Map<DateTime, List<Task>>>? bucketCtrl,
}) {
  final fixedState = CalendarState(
    selectedDate: selectedDate,
    mode: CalendarMode.month,
    agendaScope: CalendarAgendaScope.day,
  );

  return ProviderScope(
    overrides: [
      appSettingsCacheProvider.overrideWithValue(cache),
      calendarStateProvider.overrideWith(
        () => _FixedCalendarNotifier(fixedState),
      ),
      allActiveTasksProvider.overrideWith((ref) => Stream.value(<Task>[])),
      if (bucketCtrl != null)
        calendarBucketsProvider.overrideWith((ref) => bucketCtrl.stream),
      projectsStreamProvider.overrideWith((ref) => Stream.value(<Project>[])),
      tagsStreamProvider.overrideWith((ref) => Stream.value(<Tag>[])),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('zh'),
      home: Scaffold(body: CalendarPage()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CalendarDayDecorator 逻辑测试', () {
    test('开启农历时输出副文本，关闭农历时不输出副文本', () {
      final date = DateTime(2026, 9, 25); // 农历八月十五 中秋节
      final withLunar = CalendarDayDecorator.decorate(
        date: date,
        showLunar: true,
        showHolidays: false,
      );
      expect(withLunar.subText, '中秋');
      expect(withLunar.isSpecialSubText, isTrue);
      expect(withLunar.agendaDescription, contains('中秋节'));
      expect(withLunar.badgeText, isNull);

      final withoutLunar = CalendarDayDecorator.decorate(
        date: date,
        showLunar: false,
        showHolidays: false,
      );
      expect(withoutLunar.subText, isNull);
      expect(withoutLunar.agendaDescription, isNull);
    });

    test('开启调休时标注休与班，关闭调休时不标注', () {
      final holiday = DateTime(2026, 10, 1); // 国庆节 休
      final workday = DateTime(2026, 2, 15); // 春节调休 班

      final decoHoliday = CalendarDayDecorator.decorate(
        date: holiday,
        showLunar: false,
        showHolidays: true,
      );
      expect(decoHoliday.badgeText, '休');
      expect(decoHoliday.isRestBadge, isTrue);

      final decoWorkday = CalendarDayDecorator.decorate(
        date: workday,
        showLunar: false,
        showHolidays: true,
      );
      expect(decoWorkday.badgeText, '班');
      expect(decoWorkday.isWorkdayBadge, isTrue);

      final decoNone = CalendarDayDecorator.decorate(
        date: holiday,
        showLunar: false,
        showHolidays: false,
      );
      expect(decoNone.badgeText, isNull);
    });
  });

  group('日历页面农历与节假日 Widget 渲染测试', () {
    testWidgets('默认开启农历与法定节假日：中秋节显示「中秋」副文本和「休」角标', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cache = AppSettingsCache();
      final bucketCtrl =
          StreamController<Map<DateTime, List<Task>>>.broadcast();
      addTearDown(bucketCtrl.close);

      await tester.pumpWidget(
        _buildTestCalendarApp(
          selectedDate: DateTime(2026, 9, 25), // 2026年中秋
          cache: cache,
          bucketCtrl: bucketCtrl,
        ),
      );
      bucketCtrl.add({});
      await tester.pumpAndSettle();

      // 验证日历单元格内包含「中秋」
      expect(find.text('中秋'), findsWidgets);
      // 验证包含放假徽标「休」
      expect(find.text('休'), findsWidgets);
    });

    testWidgets('关闭农历与节假日后：单元格内无农历副文本和角标', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cache = AppSettingsCache()
        ..seed({
          calendarShowLunarPrefKey: 'false',
          calendarShowHolidaysPrefKey: 'false',
        });
      final bucketCtrl =
          StreamController<Map<DateTime, List<Task>>>.broadcast();
      addTearDown(bucketCtrl.close);

      await tester.pumpWidget(
        _buildTestCalendarApp(
          selectedDate: DateTime(2026, 9, 25),
          cache: cache,
          bucketCtrl: bucketCtrl,
        ),
      );
      bucketCtrl.add({});
      await tester.pumpAndSettle();

      // 不应渲染农历文本和休角标
      expect(find.text('中秋'), findsNothing);
      expect(find.text('休'), findsNothing);
    });
  });

  group('设置页面日历开关交互测试', () {
    testWidgets('在设置页面中切换农历与节假日开关可正常触发', (tester) async {
      final cache = AppSettingsCache();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsCacheProvider.overrideWithValue(cache),
            tagsStreamProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(
              body: SettingsBody(onOpenSync: () {}, onOpenTags: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证设置项标题文案存在
      expect(find.text('日历'), findsOneWidget);
      expect(find.text('显示中国农历'), findsOneWidget);
      expect(find.text('中国法定节假日与调休'), findsOneWidget);

      // 查找 Switch 并点击切换
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      expect(cache.get(calendarShowLunarPrefKey), 'false');
    });
  });
}
