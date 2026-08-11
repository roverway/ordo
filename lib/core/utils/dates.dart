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
