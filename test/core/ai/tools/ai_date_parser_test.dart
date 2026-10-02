import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/tools/impl/ai_date_parser.dart';

void main() {
  group('AiDateParser', () {
    test('parses relative dates: today, tomorrow, yesterday, EOD', () {
      final now = DateTime.utc(2026, 10, 2, 12, 0, 0);
      final nowMs = now.millisecondsSinceEpoch;

      final todayMs = AiDateParser.parseToUtcMsStrict('today', nowUtcMs: nowMs);
      expect(todayMs, isNotNull);

      final tomorrowMs = AiDateParser.parseToUtcMsStrict(
        'tomorrow',
        nowUtcMs: nowMs,
      );
      expect(tomorrowMs, isNotNull);
      expect(tomorrowMs! > todayMs!, isTrue);

      final yesterdayMs = AiDateParser.parseToUtcMsStrict(
        'yesterday',
        nowUtcMs: nowMs,
      );
      expect(yesterdayMs, isNotNull);
      expect(yesterdayMs! < todayMs, isTrue);

      final in3Days = AiDateParser.parseToUtcMsStrict(
        'in 3 days',
        nowUtcMs: nowMs,
      );
      expect(in3Days, isNotNull);
    });

    test('rejects invalid calendar dates strictly', () {
      expect(
        () => AiDateParser.parseToUtcMsStrict('2026-02-30'),
        throwsFormatException,
      );

      expect(
        () => AiDateParser.parseToUtcMsStrict('not-a-date'),
        throwsFormatException,
      );

      expect(
        () => AiDateParser.parseToUtcMsStrict('2026-13-01'),
        throwsFormatException,
      );
    });

    test('parses standard ISO and yyyy-MM-dd correctly', () {
      final ms = AiDateParser.parseToUtcMsStrict('2026-10-05 18:30');
      expect(ms, isNotNull);

      final isoMs = AiDateParser.parseToUtcMsStrict('2026-10-05T18:30:00.000Z');
      expect(isoMs, isNotNull);
    });

    test('returns null on null or clear keywords', () {
      expect(AiDateParser.parseToUtcMsStrict(null), isNull);
      expect(AiDateParser.parseToUtcMsStrict(''), isNull);
      expect(AiDateParser.parseToUtcMsStrict('null'), isNull);
      expect(AiDateParser.parseToUtcMsStrict('none'), isNull);
      expect(AiDateParser.parseToUtcMsStrict('clear'), isNull);
    });
  });
}
