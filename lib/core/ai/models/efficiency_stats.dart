import 'package:flutter/foundation.dart';

/// Aggregated statistical model for efficiency diagnostic and review.
@immutable
class EfficiencyStats {
  const EfficiencyStats({
    required this.startDate,
    required this.endDate,
    required this.totalCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.inProgressCount,
    required this.overdueCount,
    required this.completionRate,
    required this.q1Count,
    required this.q2Count,
    required this.q3Count,
    required this.q4Count,
    required this.q1Ratio,
    required this.q2Ratio,
    required this.q3Ratio,
    required this.q4Ratio,
  });

  /// Factory creating empty stats with all zeros.
  factory EfficiencyStats.empty({DateTime? startDate, DateTime? endDate}) {
    final now = DateTime.now();
    return EfficiencyStats(
      startDate: startDate ?? now.subtract(const Duration(days: 7)),
      endDate: endDate ?? now,
      totalCount: 0,
      completedCount: 0,
      cancelledCount: 0,
      inProgressCount: 0,
      overdueCount: 0,
      completionRate: 0.0,
      q1Count: 0,
      q2Count: 0,
      q3Count: 0,
      q4Count: 0,
      q1Ratio: 0.0,
      q2Ratio: 0.0,
      q3Ratio: 0.0,
      q4Ratio: 0.0,
    );
  }

  /// Start timestamp of the aggregated time window.
  final DateTime startDate;

  /// End timestamp of the aggregated time window.
  final DateTime endDate;

  /// Total count of tasks involved in the period.
  final int totalCount;

  /// Number of completed tasks.
  final int completedCount;

  /// Number of cancelled / discarded tasks.
  final int cancelledCount;

  /// Number of tasks currently in progress or pending.
  final int inProgressCount;

  /// Number of overdue uncompleted tasks.
  final int overdueCount;

  /// Task completion rate (0.0 to 1.0).
  final double completionRate;

  /// Q1 count: Urgent & Important.
  final int q1Count;

  /// Q2 count: Not Urgent & Important.
  final int q2Count;

  /// Q3 count: Urgent & Unimportant.
  final int q3Count;

  /// Q4 count: Not Urgent & Unimportant.
  final int q4Count;

  /// Proportion of Q1 tasks (0.0 to 1.0).
  final double q1Ratio;

  /// Proportion of Q2 tasks (0.0 to 1.0).
  final double q2Ratio;

  /// Proportion of Q3 tasks (0.0 to 1.0).
  final double q3Ratio;

  /// Proportion of Q4 tasks (0.0 to 1.0).
  final double q4Ratio;

  /// Rounded completion rate percentage (e.g. 71 for 71.4%).
  int get completionPercentage => (completionRate * 100).round();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EfficiencyStats &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          totalCount == other.totalCount &&
          completedCount == other.completedCount &&
          cancelledCount == other.cancelledCount &&
          inProgressCount == other.inProgressCount &&
          overdueCount == other.overdueCount &&
          completionRate == other.completionRate &&
          q1Count == other.q1Count &&
          q2Count == other.q2Count &&
          q3Count == other.q3Count &&
          q4Count == other.q4Count &&
          q1Ratio == other.q1Ratio &&
          q2Ratio == other.q2Ratio &&
          q3Ratio == other.q3Ratio &&
          q4Ratio == other.q4Ratio;

  @override
  int get hashCode => Object.hash(
    startDate,
    endDate,
    totalCount,
    completedCount,
    cancelledCount,
    inProgressCount,
    overdueCount,
    completionRate,
    q1Count,
    q2Count,
    q3Count,
    q4Count,
    q1Ratio,
    q2Ratio,
    q3Ratio,
    q4Ratio,
  );

  @override
  String toString() =>
      'EfficiencyStats(total: $totalCount, done: $completedCount, rate: ${(completionRate * 100).toStringAsFixed(1)}%, Q1: $q1Count, Q2: $q2Count, Q3: $q3Count, Q4: $q4Count)';
}
