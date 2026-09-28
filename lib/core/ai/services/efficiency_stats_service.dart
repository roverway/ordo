import 'package:ordo/core/ai/models/efficiency_stats.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/features/quadrant/models/quadrant_models.dart';

/// Service responsible for extracting aggregated efficiency statistics from local Drift DB.
class EfficiencyStatsService {
  EfficiencyStatsService({required TodoRepository repository})
    : _repository = repository;

  final TodoRepository _repository;

  /// Retrieves aggregated task statistics for the past 7 days (or custom window).
  Future<EfficiencyStats> getPastWeekStats({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final windowStart = current.subtract(const Duration(days: 7));
    final windowStartMs = windowStart.millisecondsSinceEpoch;
    final nowMs = current.millisecondsSinceEpoch;

    final allTasks = await _repository.tasks.getAllActive();

    // Filter tasks that belong to the past 7 days window
    final relevantTasks = allTasks.where((task) {
      // 1. Task completed within past 7 days
      if (task.completedAt != null &&
          task.completedAt! >= windowStartMs &&
          task.completedAt! <= nowMs) {
        return true;
      }
      // 2. Task cancelled within past 7 days
      if (task.status == TaskStatus.cancelled &&
          task.updatedAt >= windowStartMs &&
          task.updatedAt <= nowMs) {
        return true;
      }
      // 3. Task created within past 7 days
      if (task.createdAt >= windowStartMs && task.createdAt <= nowMs) {
        return true;
      }
      // 4. Task deadline within past 7 days
      if (task.endAt != null &&
          task.endAt! >= windowStartMs &&
          task.endAt! <= nowMs) {
        return true;
      }
      return false;
    }).toList();

    var completedCount = 0;
    var cancelledCount = 0;
    var inProgressCount = 0;
    var overdueCount = 0;

    var q1Count = 0;
    var q2Count = 0;
    var q3Count = 0;
    var q4Count = 0;

    for (final task in relevantTasks) {
      if (task.status == TaskStatus.done ||
          (task.completedAt != null &&
              task.completedAt! >= windowStartMs &&
              task.completedAt! <= nowMs)) {
        completedCount++;
      } else if (task.status == TaskStatus.cancelled) {
        cancelledCount++;
      } else {
        inProgressCount++;
        // Check if overdue (< nowMs)
        if (task.endAt != null && task.endAt! < nowMs) {
          overdueCount++;
        }
      }

      // Quadrant classification based on Eisenhower matrix
      final quadrant = classifyTask(task, current);
      switch (quadrant) {
        case QuadrantType.urgentImportant:
          q1Count++;
          break;
        case QuadrantType.notUrgentImportant:
          q2Count++;
          break;
        case QuadrantType.urgentUnimportant:
          q3Count++;
          break;
        case QuadrantType.notUrgentUnimportant:
          q4Count++;
          break;
      }
    }

    final totalCount = relevantTasks.length;
    final completionRate = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    final q1Ratio = totalCount > 0 ? (q1Count / totalCount) : 0.0;
    final q2Ratio = totalCount > 0 ? (q2Count / totalCount) : 0.0;
    final q3Ratio = totalCount > 0 ? (q3Count / totalCount) : 0.0;
    final q4Ratio = totalCount > 0 ? (q4Count / totalCount) : 0.0;

    return EfficiencyStats(
      startDate: windowStart,
      endDate: current,
      totalCount: totalCount,
      completedCount: completedCount,
      cancelledCount: cancelledCount,
      inProgressCount: inProgressCount,
      overdueCount: overdueCount,
      completionRate: completionRate,
      q1Count: q1Count,
      q2Count: q2Count,
      q3Count: q3Count,
      q4Count: q4Count,
      q1Ratio: q1Ratio,
      q2Ratio: q2Ratio,
      q3Ratio: q3Ratio,
      q4Ratio: q4Ratio,
    );
  }
}
