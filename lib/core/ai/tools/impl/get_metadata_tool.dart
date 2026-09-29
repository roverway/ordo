import 'package:intl/intl.dart';
import '../ai_tool.dart';

/// Read-only tool that provides system metadata: current timestamp/weekday, existing projects and tags.
/// Prevents hallucinations and enables matching against existing taxonomy.
class GetMetadataTool extends AiTool {
  const GetMetadataTool();

  @override
  String get name => 'get_metadata';

  @override
  String get description =>
      'Retrieves system context: current date/time/weekday, existing project names/IDs, and tag names/IDs. '
      'Call this to understand the user\'s current date context or available categories before organizing tasks.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {},
    'required': [],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final nowMs = context.currentNowUtcMs;
    final nowDateTime = DateTime.fromMillisecondsSinceEpoch(
      nowMs,
      isUtc: true,
    ).toLocal();

    final isEn = context.locale.toLowerCase().startsWith('en');
    final weekDayNamesZh = ['一', '二', '三', '四', '五', '六', '日'];
    final weekDayNamesEn = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekdayString = isEn
        ? weekDayNamesEn[nowDateTime.weekday - 1]
        : '星期${weekDayNamesZh[nowDateTime.weekday - 1]}';

    final projects = await context.repository.projects.getAll();
    final tags = await context.repository.tags.getAll();

    return AiToolResult.ok({
      'now': {
        'iso': nowDateTime.toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(nowDateTime),
        'time': DateFormat('HH:mm:ss').format(nowDateTime),
        'weekday': weekdayString,
      },
      'projects': projects
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'color': p.color,
              'folderId': p.folderId,
            },
          )
          .toList(),
      'tags': tags
          .map((t) => {'id': t.id, 'name': t.name, 'color': t.color})
          .toList(),
    });
  }
}
