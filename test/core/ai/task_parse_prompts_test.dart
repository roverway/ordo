import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/prompts/task_parse_prompts.dart';

void main() {
  group('TaskParsePrompts', () {
    test(
      'buildTaskParseSystemPrompt injects current time, weekday, and timezone offset',
      () {
        // 2026-09-28 is a Monday
        final fixedTime = DateTime.utc(2026, 9, 28, 10, 20, 8);
        const timeZoneOffset = Duration(hours: 8);

        final prompt = buildTaskParseSystemPrompt(
          now: fixedTime,
          timeZoneOffset: timeZoneOffset,
        );

        expect(prompt, contains('2026-09-28'));
        expect(prompt, contains('UTC+08:00'));
        expect(prompt, contains('星期一'));
        expect(prompt, contains(fixedTime.millisecondsSinceEpoch.toString()));
      },
    );

    test('buildTaskParseSystemPrompt includes JSON schema requirements', () {
      final fixedTime = DateTime.utc(2026, 9, 28, 2, 0, 0);
      final prompt = buildTaskParseSystemPrompt(now: fixedTime);

      expect(prompt, contains('"title"'));
      expect(prompt, contains('"description"'));
      expect(prompt, contains('"priority"'));
      expect(prompt, contains('"startAt"'));
      expect(prompt, contains('"dueAt"'));
      expect(prompt, contains('"tags"'));
      expect(prompt, contains('"substeps"'));
      expect(prompt, contains('0: none, 1: low, 2: medium, 3: high'));
    });

    test(
      'buildTaskParseSystemPrompt specifies substeps only on explicit breakdown request',
      () {
        final prompt = buildTaskParseSystemPrompt();

        expect(prompt, contains('substeps'));
        expect(prompt, anyOf([contains('拆细'), contains('拆解'), contains('分解')]));
        expect(prompt, contains('[]'));
      },
    );
  });
}
