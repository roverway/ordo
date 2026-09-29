import 'package:intl/intl.dart';

/// Unified utility to parse date and time arguments provided by LLM / MCP tools.
class AiDateParser {
  AiDateParser._();

  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Parses [raw] input (which might be an epoch timestamp, ISO-8601 string,
  /// 'yyyy-MM-dd HH:mm' or 'yyyy-MM-dd') into UTC milliseconds since epoch.
  /// Returns null if [raw] is null, empty or unparseable.
  static int? parseToUtcMs(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();

    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'none' || str == 'clear') {
      return null;
    }

    final asInt = int.tryParse(str);
    if (asInt != null) return asInt;

    final parsedIso = DateTime.tryParse(str);
    if (parsedIso != null) {
      return parsedIso.toUtc().millisecondsSinceEpoch;
    }

    try {
      return _dateTimeFormat.parse(str).toUtc().millisecondsSinceEpoch;
    } catch (_) {}

    try {
      return _dateFormat.parse(str).toUtc().millisecondsSinceEpoch;
    } catch (_) {}

    return null;
  }
}
