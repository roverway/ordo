import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';

/// 四象限类型枚举（艾森豪威尔矩阵纯模型）。
///
/// 属于核心领域模型，供 AI 效率统计与四象限特征层共用。
enum QuadrantType {
  /// 第一象限：重要且紧急（Q1）
  urgentImportant,

  /// 第二象限：重要不紧急（Q2）
  notUrgentImportant,

  /// 第三象限：不重要但紧急（Q3）
  urgentUnimportant,

  /// 第四象限：不重要且不紧急（Q4）
  notUrgentUnimportant;

  /// 象限标识短标签（Q1 ~ Q4）。
  String get tag => 'Q${index + 1}';

  /// 罗马数字标号（I ~ IV）。
  String get romanNumeral => ['I', 'II', 'III', 'IV'][index];

  /// 象限纯数字（1 ~ 4）。
  int get number => index + 1;
}

/// 纯函数：根据当前时间基准与任务自身属性判定其所属象限。
QuadrantType classifyTask(Task task, DateTime now) {
  final endOfToday = DateTime(
    now.year,
    now.month,
    now.day,
    23,
    59,
    59,
    999,
  ).millisecondsSinceEpoch;

  final isImportant =
      task.priority == TaskPriority.high ||
      task.priority == TaskPriority.medium;

  // 逾期（< now）或今天截止（<= endOfToday）均视为紧急
  final isUrgent = task.endAt != null && task.endAt! <= endOfToday;

  if (isImportant && isUrgent) {
    return QuadrantType.urgentImportant;
  } else if (isImportant && !isUrgent) {
    return QuadrantType.notUrgentImportant;
  } else if (!isImportant && isUrgent) {
    return QuadrantType.urgentUnimportant;
  } else {
    return QuadrantType.notUrgentUnimportant;
  }
}
