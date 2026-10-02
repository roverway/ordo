import 'package:intl/intl.dart';
import '../ai_tool.dart';

/// Read-only tool that provides system metadata: current timestamp/weekday, timezone,
/// existing projects (with folder names), tags, folders, custom views, and server write mode.
class GetMetadataTool extends AiTool {
  const GetMetadataTool();

  @override
  bool get isReadOnly => true;

  @override
  bool get isIdempotent => true;

  @override
  String get name => 'get_metadata';

  @override
  String get description =>
      'Retrieves system context: current date/time/weekday, timezone, existing project names/IDs with folders, '
      'tags, folders, custom views, and server write mode. Call this before organizing or creating tasks.';

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
    final folders = await context.repository.folders.getAll();
    final customViews = await context.repository.customViews.getAll();

    final folderMap = {for (final f in folders) f.id: f.name};

    return AiToolResult.ok({
      'now': {
        'iso': nowDateTime.toIso8601String(),
        'date': DateFormat('yyyy-MM-dd').format(nowDateTime),
        'time': DateFormat('HH:mm:ss').format(nowDateTime),
        'weekday': weekdayString,
        'timezone': nowDateTime.timeZoneName,
        'utcOffsetMinutes': nowDateTime.timeZoneOffset.inMinutes,
      },
      'writeMode': context.writeMode,
      'effectiveWriteMode': context.writeMode,
      'projects': projects
          .where((p) => p.deleted == 0)
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'color': p.color,
              'folderId': p.folderId,
              'folderName': p.folderId != null ? folderMap[p.folderId] : null,
            },
          )
          .toList(),
      'folders': folders
          .where((f) => f.deleted == 0)
          .map(
            (f) => {
              'id': f.id,
              'name': f.name,
              'color': f.color,
              'icon': f.icon,
            },
          )
          .toList(),
      'tags': tags
          .where((t) => t.deleted == 0)
          .map((t) => {'id': t.id, 'name': t.name, 'color': t.color})
          .toList(),
      'customViews': customViews
          .map((v) => {'id': v.id, 'name': v.name, 'icon': v.icon})
          .toList(),
    });
  }
}
