import 'package:intl/intl.dart' as intl;

import '../l10n/app_localizations.dart';

/// Date formatting utilities.
///
/// All stored times are UTC milliseconds (40-data-model.md §4).
/// Formatting happens here at the UI boundary, converting to local timezone.

/// Format a UTC millisecond timestamp as a human-readable due date string.
///
/// Returns localized labels for today/tomorrow (via [l10n]), otherwise "MMM d".
String formatDueDate(int utcMs, AppLocalizations l10n) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    utcMs,
    isUtc: true,
  ).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final target = DateTime(date.year, date.month, date.day);

  if (target == today) return l10n.today;
  if (target == tomorrow) return l10n.tomorrow;
  if (target.year == now.year) {
    return intl.DateFormat('MMM d').format(date);
  }
  return intl.DateFormat('MMM d, y').format(date);
}

/// Format a UTC millisecond timestamp to full date + time string.
String formatDateTime(int utcMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).toLocal();
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Format an optional start/end UTC millisecond pair as a localized date range.
///
/// - Both null → empty string.
/// - Only one set → delegate to [formatDueDate].
/// - Same local day → show once (delegate to [formatDueDate]).
/// - Otherwise → `"start – end"` (e.g. "Aug 1, 2026 – Aug 3, 2026").
String formatDateRange(int? startAt, int? endAt, AppLocalizations l10n) {
  if (startAt == null && endAt == null) return '';
  if (startAt == null) return formatDueDate(endAt!, l10n);
  if (endAt == null) return formatDueDate(startAt, l10n);

  final start = DateTime.fromMillisecondsSinceEpoch(
    startAt,
    isUtc: true,
  ).toLocal();
  final end = DateTime.fromMillisecondsSinceEpoch(endAt, isUtc: true).toLocal();
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) return formatDueDate(startAt, l10n);
  return '${formatDueDate(startAt, l10n)} – ${formatDueDate(endAt, l10n)}';
}

/// 「距开始 X 天」相对时间文案（61-task-list-redesign.md §4.4）。
///
/// [startAt] 在**后天及以后**（≥2 天）返回本地化文案（如「距开始 12 天」）。
/// 今天/明天开始（≤1 天）返回空串：日期行已由 [formatDueDate] 解析为
/// 「今天/明天」，再显示「距开始 X 天」会造成同一日期两段文字（评审修复 3）。
///
/// 天数差值在 **UTC 域**计算（本地年月日各自转 `DateTime.utc`）：DST 春季
/// 的 23 小时日会让两个本地午夜的 `difference.inDays` 少算一天（评审修复 1）。
String formatRelativeStart(int? startAt, AppLocalizations l10n) {
  if (startAt == null) return '';
  final start = DateTime.fromMillisecondsSinceEpoch(
    startAt,
    isUtc: true,
  ).toLocal();
  final now = DateTime.now();
  final days = DateTime.utc(
    start.year,
    start.month,
    start.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (days <= 1) return '';
  return l10n.relativeStartInDays(days);
}

/// 中文星期名称（下标 = DateTime.weekday - 1）。
const List<String> zhWeekdays = [
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

/// 今日页大标题副标题：完整日期（如「8月27日 星期三」/「Wed, Aug 27」）。
///
/// [date] 缺省取当天。
String formatFullDateLine(DateTime date, {required bool isZh}) {
  if (isZh) {
    return '${intl.DateFormat('M月d日').format(date)} ${zhWeekdays[date.weekday - 1]}';
  }
  return intl.DateFormat('EEE, MMM d', 'en').format(date);
}

/// 星期表头缩写序列（从周一到周日，下标 0..6）。
const List<String> zhWeekdayShorts = ['一', '二', '三', '四', '五', '六', '日'];
const List<String> enWeekdayShorts = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// 获取按语言环境的星期表头缩写序列。
List<String> getWeekdayShorts({required bool isZh}) =>
    isZh ? zhWeekdayShorts : enWeekdayShorts;

/// 格式化日历议程列表日期标题（如「8月27日 · 今天」/「8月28日 星期四」）。
String formatAgendaDateHeader({
  required DateTime selected,
  required String todayLabel,
  required bool isZh,
}) {
  final now = DateTime.now();
  final isToday =
      selected.year == now.year &&
      selected.month == now.month &&
      selected.day == now.day;
  if (isZh) {
    if (isToday) {
      return '${intl.DateFormat('M月d日').format(selected)} · $todayLabel';
    }
    return '${intl.DateFormat('M月d日').format(selected)} ${zhWeekdays[selected.weekday - 1]}';
  } else {
    if (isToday) {
      return '${intl.DateFormat('MMM d', 'en').format(selected)} · $todayLabel';
    }
    return intl.DateFormat('EEEE, MMM d', 'en').format(selected);
  }
}

/// 格式化日历顶栏周期标题（月视图如「2026年8月」/「August 2026」；周视图如「8月10日 – 8月16日」/「Aug 10 – Aug 16, 2026」）。
String formatCalendarHeader({
  required DateTime selectedDate,
  required bool isMonthMode,
  required DateTime weekStart,
  required DateTime weekEnd,
  required bool isZh,
}) {
  if (isMonthMode) {
    return isZh
        ? intl.DateFormat('y年M月').format(selectedDate)
        : intl.DateFormat('MMMM yyyy', 'en').format(selectedDate);
  }
  if (isZh) {
    if (weekStart.year != weekEnd.year) {
      return '${intl.DateFormat('y年M月d日').format(weekStart)} – ${intl.DateFormat('y年M月d日').format(weekEnd)}';
    }
    if (weekStart.month != weekEnd.month) {
      return '${intl.DateFormat('M月d日').format(weekStart)} – ${intl.DateFormat('M月d日').format(weekEnd)}';
    }
    return '${intl.DateFormat('M月d日').format(weekStart)} – ${intl.DateFormat('M月d日').format(weekEnd)}';
  } else {
    if (weekStart.year != weekEnd.year) {
      return '${intl.DateFormat('MMM d, y', 'en').format(weekStart)} – ${intl.DateFormat('MMM d, y', 'en').format(weekEnd)}';
    }
    if (weekStart.month != weekEnd.month) {
      return '${intl.DateFormat('MMM d', 'en').format(weekStart)} – ${intl.DateFormat('MMM d, y', 'en').format(weekEnd)}';
    }
    return '${intl.DateFormat('MMM d', 'en').format(weekStart)} – ${intl.DateFormat('MMM d, y', 'en').format(weekEnd)}';
  }
}
