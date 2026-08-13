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
