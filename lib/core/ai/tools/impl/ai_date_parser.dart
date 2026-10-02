import 'package:intl/intl.dart';

/// Unified utility to parse date and time arguments provided by LLM / MCP tools.
class AiDateParser {
  AiDateParser._();

  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Strict date parser.
  /// Returns `null` only when [raw] is `null` or an explicit clear keyword (`'none'`, `'clear'`).
  /// Throws [FormatException] if [raw] contains a non-empty string that cannot be resolved to a valid date.
  static int? parseToUtcMsStrict(dynamic raw, {int? nowUtcMs}) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();

    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'none' || str == 'clear') {
      return null;
    }

    final asInt = int.tryParse(str);
    if (asInt != null) return asInt;

    final now = nowUtcMs != null
        ? DateTime.fromMillisecondsSinceEpoch(nowUtcMs, isUtc: true).toLocal()
        : DateTime.now();

    // 1. Relative date keywords
    final lower = str.toLowerCase();
    if (lower == 'today' || lower == '今天' || lower == '今日') {
      return DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().millisecondsSinceEpoch;
    }
    if (lower == 'tomorrow' || lower == '明天' || lower == '明日') {
      return DateTime(
        now.year,
        now.month,
        now.day + 1,
        23,
        59,
        59,
      ).toUtc().millisecondsSinceEpoch;
    }
    if (lower == 'yesterday' || lower == '昨天' || lower == '昨日') {
      return DateTime(
        now.year,
        now.month,
        now.day - 1,
        23,
        59,
        59,
      ).toUtc().millisecondsSinceEpoch;
    }
    if (lower == 'eod' || lower == 'end of day') {
      return DateTime(
        now.year,
        now.month,
        now.day,
        18,
        0,
        0,
      ).toUtc().millisecondsSinceEpoch;
    }

    final inDaysMatch = RegExp(r'^in\s+(\d+)\s+days?$').firstMatch(lower);
    if (inDaysMatch != null) {
      final days = int.parse(inDaysMatch.group(1)!);
      return DateTime(
        now.year,
        now.month,
        now.day + days,
        23,
        59,
        59,
      ).toUtc().millisecondsSinceEpoch;
    }

    final daysAfterMatch = RegExp(r'^(\d+)天后$').firstMatch(lower);
    if (daysAfterMatch != null) {
      final days = int.parse(daysAfterMatch.group(1)!);
      return DateTime(
        now.year,
        now.month,
        now.day + days,
        23,
        59,
        59,
      ).toUtc().millisecondsSinceEpoch;
    }

    // 2. Strict calendar validation to catch invalid calendar dates like 2026-02-30
    final datePattern = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2}))?',
    );
    final match = datePattern.firstMatch(str);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = match.group(4) != null ? int.parse(match.group(4)!) : 18;
      final minute = match.group(5) != null ? int.parse(match.group(5)!) : 0;

      if (month < 1 || month > 12) {
        throw FormatException(
          'Invalid calendar month "$month" in date "$str".',
        );
      }
      final maxDaysInMonth = DateTime(year, month + 1, 0).day;
      if (day < 1 || day > maxDaysInMonth) {
        throw FormatException(
          'Invalid calendar day "$day" for month $month in date "$str" (maximum is $maxDaysInMonth).',
        );
      }
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        throw FormatException('Invalid time "$hour:$minute" in date "$str".');
      }

      // Check if it has timezone offset
      if (str.endsWith('Z') ||
          str.contains('+') ||
          (str.contains('-') && str.lastIndexOf('-') > 7)) {
        final parsedIso = DateTime.tryParse(str);
        if (parsedIso != null) {
          return parsedIso.toUtc().millisecondsSinceEpoch;
        }
      }

      return DateTime(
        year,
        month,
        day,
        hour,
        minute,
      ).toUtc().millisecondsSinceEpoch;
    }

    final parsedIso = DateTime.tryParse(str);
    if (parsedIso != null) {
      return parsedIso.toUtc().millisecondsSinceEpoch;
    }

    try {
      return _dateTimeFormat.parseStrict(str).toUtc().millisecondsSinceEpoch;
    } catch (_) {}

    try {
      return _dateFormat.parseStrict(str).toUtc().millisecondsSinceEpoch;
    } catch (_) {}

    throw FormatException(
      'Unparseable date: "$raw". Expected ISO-8601, "yyyy-MM-dd HH:mm", "yyyy-MM-dd", or relative terms like "today", "tomorrow".',
    );
  }

  /// Parses [raw] input into UTC milliseconds, or returns null if unparseable.
  /// (Retained for backwards compatibility with non-strict contexts)
  static int? parseToUtcMs(dynamic raw) {
    try {
      return parseToUtcMsStrict(raw);
    } catch (_) {
      return null;
    }
  }
}
