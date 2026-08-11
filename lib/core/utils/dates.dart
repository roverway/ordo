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
