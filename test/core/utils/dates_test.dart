// dates.dart 区间格式化单测（SimpleTaskTile 时间行，M3）。
//
// 用远离当前的固定日期（2020 年）保证输出确定（`MMM d, y` 格式），
// 不依赖运行时的「今天」/「明天」判定。

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;
import 'package:ordo/core/l10n/app_localizations_en.dart';
import 'package:ordo/core/utils/dates.dart';

int _ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  final l10n = AppLocalizationsEn();

  setUpAll(() async {
    await initializeDateFormatting('en');
    intl.Intl.defaultLocale = 'en';
  });

  group('formatDateRange', () {
    final d1 = DateTime(2020, 1, 1);
    final d2 = DateTime(2020, 1, 3);

    test('startAt 与 endAt 都为空 → 空串', () {
      expect(formatDateRange(null, null, l10n), '');
    });

    test('仅 endAt → 委托 formatDueDate（只显示截止日）', () {
      expect(formatDateRange(null, _ms(d1), l10n), 'Jan 1, 2020');
    });

    test('仅 startAt → 委托 formatDueDate（只显示开始日）', () {
      expect(formatDateRange(_ms(d1), null, l10n), 'Jan 1, 2020');
    });

    test('跨天区间 → "start – end"', () {
      expect(
        formatDateRange(_ms(d1), _ms(d2), l10n),
        'Jan 1, 2020 – Jan 3, 2020',
      );
    });

    test('同一天（跨小时）→ 只显示一次', () {
      expect(
        formatDateRange(_ms(d1), _ms(DateTime(2020, 1, 1, 23, 59)), l10n),
        'Jan 1, 2020',
      );
    });
  });

  group('formatRelativeStart', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));
    final yesterday = today.subtract(const Duration(days: 1));

    test('null → 空串', () {
      expect(formatRelativeStart(null, l10n), '');
    });

    test('今天开始 → 空串（days=0）', () {
      expect(formatRelativeStart(_ms(today), l10n), '');
    });

    test('明天开始 → 空串（days=1，抑制冗余，61 §4.4）', () {
      expect(formatRelativeStart(_ms(tomorrow), l10n), '');
    });

    test('后天开始 → 「Starts in 2 days」', () {
      expect(formatRelativeStart(_ms(dayAfter), l10n), 'Starts in 2 days');
    });

    test('已开始（过去）→ 空串', () {
      expect(formatRelativeStart(_ms(yesterday), l10n), '');
    });

    test('天数差在 UTC 域计算：明天（含 DST 23 小时日）恒为 1 天', () {
      // 不模拟具体 DST 时区，验证「明天」差值恒定 1：若实现退化为本地
      // difference.inDays，DST 春季日会得 0；UTC 域计算恒为 1 → 空串。
      expect(formatRelativeStart(_ms(tomorrow), l10n), '');
    });
  });

  group("formatDueDateWithTime & formatScheduleDisplay", () {
    final d1 = DateTime(2020, 1, 1, 9, 30);
    final d2 = DateTime(2020, 1, 1, 18, 0);
    final d3 = DateTime(2020, 1, 2, 10, 0);

    test("formatDueDateWithTime 包含日期与具体时间", () {
      final res = formatDueDateWithTime(_ms(d1), l10n);
      expect(res.contains("Jan 1, 2020"), isTrue);
      expect(res.contains("09:30"), isTrue);
    });

    test("formatScheduleDisplay 双方为 null 返回空串", () {
      expect(formatScheduleDisplay(null, null, l10n), "");
    });

    test("formatScheduleDisplay 同一天显示时间段", () {
      final res = formatScheduleDisplay(_ms(d1), _ms(d2), l10n);
      expect(res.contains("Jan 1, 2020"), isTrue);
      expect(res.contains("09:30–18:00"), isTrue);
    });

    test("formatScheduleDisplay 跨天显示起止日期", () {
      final res = formatScheduleDisplay(_ms(d1), _ms(d3), l10n);
      expect(res, "Jan 1, 2020 – Jan 2, 2020");
    });
  });

  group('formatFullTaskDateRange', () {
    final d1 = DateTime(2020, 1, 1);
    final d1WithTimeStart = DateTime(2020, 1, 1, 9, 0);
    final d1WithTimeEnd = DateTime(2020, 1, 1, 18, 0);
    final d2 = DateTime(2020, 1, 3);
    final d2WithTimeEnd = DateTime(2020, 1, 3, 18, 0);

    test('startAt 与 endAt 均为空 → 空串', () {
      expect(formatFullTaskDateRange(null, null, l10n), '');
    });

    test('仅 startAt 带时刻 → 显示单点完整时间', () {
      expect(
        formatFullTaskDateRange(_ms(d1WithTimeStart), null, l10n),
        'Jan 1, 2020 09:00',
      );
    });

    test('仅 endAt 带时刻 → 显示单点完整时间', () {
      expect(
        formatFullTaskDateRange(null, _ms(d1WithTimeEnd), l10n),
        'Jan 1, 2020 18:00',
      );
    });

    test('同一天均带不同时刻 → 共享日期并展示时刻区间', () {
      expect(
        formatFullTaskDateRange(_ms(d1WithTimeStart), _ms(d1WithTimeEnd), l10n),
        'Jan 1, 2020 09:00 – 18:00',
      );
    });

    test('同一天均无时刻（全天） → 仅显示一次日期', () {
      expect(formatFullTaskDateRange(_ms(d1), _ms(d1), l10n), 'Jan 1, 2020');
    });

    test('跨天均带时刻 → 完整显示两侧起止日期与时刻', () {
      expect(
        formatFullTaskDateRange(_ms(d1WithTimeStart), _ms(d2WithTimeEnd), l10n),
        'Jan 1, 2020 09:00 – Jan 3, 2020 18:00',
      );
    });

    test('跨天无时刻 → 显示两侧起止日期', () {
      expect(
        formatFullTaskDateRange(_ms(d1), _ms(d2), l10n),
        'Jan 1, 2020 – Jan 3, 2020',
      );
    });
  });
}
