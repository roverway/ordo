import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/tools/impl/ai_date_parser.dart';

void main() {
  group('AiDateParser', () {
    test('parses int and num epoch timestamps directly', () {
      expect(AiDateParser.parseToUtcMs(1727611200000), 1727611200000);
      expect(AiDateParser.parseToUtcMs(1727611200000.0), 1727611200000);
      expect(AiDateParser.parseToUtcMs('1727611200000'), 1727611200000);
    });

    test('parses standard ISO 8601 strings', () {
      final iso = '2026-09-29T12:00:00Z';
      final expected = DateTime.parse(iso).toUtc().millisecondsSinceEpoch;
      expect(AiDateParser.parseToUtcMs(iso), expected);
    });

    test('parses yyyy-MM-dd HH:mm formatted strings', () {
      final parsed = AiDateParser.parseToUtcMs('2026-09-29 15:30');
      expect(parsed, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(parsed!, isUtc: false);
      expect(dt.year, 2026);
      expect(dt.month, 9);
      expect(dt.day, 29);
      expect(dt.hour, 15);
      expect(dt.minute, 30);
    });

    test('parses yyyy-MM-dd date-only strings', () {
      final parsed = AiDateParser.parseToUtcMs('2026-10-01');
      expect(parsed, isNotNull);
      final dt = DateTime.fromMillisecondsSinceEpoch(parsed!, isUtc: false);
      expect(dt.year, 2026);
      expect(dt.month, 10);
      expect(dt.day, 1);
    });

    test('returns null for empty, null, or special markers', () {
      expect(AiDateParser.parseToUtcMs(null), isNull);
      expect(AiDateParser.parseToUtcMs(''), isNull);
      expect(AiDateParser.parseToUtcMs('   '), isNull);
      expect(AiDateParser.parseToUtcMs('none'), isNull);
      expect(AiDateParser.parseToUtcMs('clear'), isNull);
      expect(AiDateParser.parseToUtcMs('invalid_string'), isNull);
    });
  });
}
