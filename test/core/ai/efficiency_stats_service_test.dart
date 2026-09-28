import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ordo/core/ai/services/efficiency_stats_service.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repository;
  late EfficiencyStatsService statsService;

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    statsService = EfficiencyStatsService(repository: repository);
    await repository.ensureInboxProject('收件箱');
  });

  tearDown(() async {
    await db.close();
  });

  group('EfficiencyStatsService Past 7 Days Statistical Aggregation', () {
    test(
      'calculates completion rate, total, completed, cancelled, inProgress, and overdue',
      () async {
        final fixedNow = DateTime(2026, 9, 28, 12, 0, 0);
        final nowMs = fixedNow.millisecondsSinceEpoch;
        final oneDayMs = 24 * 3600 * 1000;
        final twoDaysAgoMs = nowMs - (2 * oneDayMs);
        final tenDaysAgoMs = nowMs - (10 * oneDayMs);

        // 1. Task completed within 7-day window (2 days ago)
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 't-comp-1',
            projectId: 'inbox',
            title: 'Completed Task 1',
            sortOrder: 0,
            updatedAt: twoDaysAgoMs,
            status: TaskStatus.done,
            createdAt: twoDaysAgoMs,
            completedAt: drift.Value(twoDaysAgoMs),
          ),
        );

        // 2. Task completed 10 days ago (outside 7-day window, should NOT be counted)
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 't-comp-old',
            projectId: 'inbox',
            title: 'Old Completed Task',
            sortOrder: 0,
            updatedAt: tenDaysAgoMs,
            status: TaskStatus.done,
            createdAt: tenDaysAgoMs,
            completedAt: drift.Value(tenDaysAgoMs),
          ),
        );

        // 3. Task in progress within window
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 't-in-progress-1',
            projectId: 'inbox',
            title: 'In Progress Task 1',
            sortOrder: 0,
            updatedAt: twoDaysAgoMs,
            status: TaskStatus.inProgress,
            createdAt: twoDaysAgoMs,
          ),
        );

        // 4. Task cancelled/abandoned within window
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 't-cancelled-1',
            projectId: 'inbox',
            title: 'Cancelled Task 1',
            sortOrder: 0,
            updatedAt: twoDaysAgoMs,
            status: TaskStatus.cancelled,
            createdAt: twoDaysAgoMs,
          ),
        );

        // 5. Overdue task created within window with due date yesterday
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 't-overdue-1',
            projectId: 'inbox',
            title: 'Overdue Task 1',
            sortOrder: 0,
            updatedAt: twoDaysAgoMs,
            status: TaskStatus.todo,
            createdAt: twoDaysAgoMs,
            endAt: drift.Value(nowMs - oneDayMs),
          ),
        );

        final stats = await statsService.getPastWeekStats(now: fixedNow);

        // Total tasks active/touched in past 7 days = 4 (t-comp-1, t-in-progress-1, t-cancelled-1, t-overdue-1)
        expect(stats.totalCount, equals(4));
        expect(stats.completedCount, equals(1));
        expect(stats.cancelledCount, equals(1));
        expect(stats.inProgressCount, equals(2));
        expect(stats.overdueCount, equals(1));
        // Completion rate = 1 / 4 = 25%
        expect(stats.completionRate, closeTo(0.25, 0.001));
        expect(stats.completionPercentage, equals(25));
      },
    );

    test('classifies tasks into 4 Eisenhower quadrants accurately', () async {
      final fixedNow = DateTime(2026, 9, 28, 12, 0, 0);
      final nowMs = fixedNow.millisecondsSinceEpoch;
      final twoDaysAgoMs = nowMs - (2 * 24 * 3600 * 1000);

      // Q1: Urgent & Important (due today + high priority)
      await repository.tasks.insert(
        TasksCompanion.insert(
          id: 't-q1',
          projectId: 'inbox',
          title: 'Q1 Task',
          sortOrder: 0,
          updatedAt: twoDaysAgoMs,
          priority: const drift.Value(TaskPriority.high),
          status: TaskStatus.todo,
          createdAt: twoDaysAgoMs,
          endAt: drift.Value(nowMs), // due today
        ),
      );

      // Q2: Important Not Urgent (high priority + no due or later)
      await repository.tasks.insert(
        TasksCompanion.insert(
          id: 't-q2',
          projectId: 'inbox',
          title: 'Q2 Task',
          sortOrder: 0,
          updatedAt: twoDaysAgoMs,
          priority: const drift.Value(TaskPriority.high),
          status: TaskStatus.todo,
          createdAt: twoDaysAgoMs,
          endAt: drift.Value(nowMs + 5 * 24 * 3600 * 1000), // due in 5 days
        ),
      );

      // Q3: Urgent Not Important (due today + low priority)
      await repository.tasks.insert(
        TasksCompanion.insert(
          id: 't-q3',
          projectId: 'inbox',
          title: 'Q3 Task',
          sortOrder: 0,
          updatedAt: twoDaysAgoMs,
          priority: const drift.Value(TaskPriority.low),
          status: TaskStatus.todo,
          createdAt: twoDaysAgoMs,
          endAt: drift.Value(nowMs), // due today
        ),
      );

      // Q4: Not Urgent Not Important (none priority + no due)
      await repository.tasks.insert(
        TasksCompanion.insert(
          id: 't-q4',
          projectId: 'inbox',
          title: 'Q4 Task',
          sortOrder: 0,
          updatedAt: twoDaysAgoMs,
          priority: const drift.Value(TaskPriority.none),
          status: TaskStatus.todo,
          createdAt: twoDaysAgoMs,
        ),
      );

      final stats = await statsService.getPastWeekStats(now: fixedNow);

      expect(stats.q1Count, equals(1));
      expect(stats.q2Count, equals(1));
      expect(stats.q3Count, equals(1));
      expect(stats.q4Count, equals(1));
      expect(stats.q1Ratio, closeTo(0.25, 0.01));
      expect(stats.q2Ratio, closeTo(0.25, 0.01));
      expect(stats.q3Ratio, closeTo(0.25, 0.01));
      expect(stats.q4Ratio, closeTo(0.25, 0.01));
    });

    test('handles empty task list gracefully with zero stats', () async {
      final stats = await statsService.getPastWeekStats();
      expect(stats.totalCount, equals(0));
      expect(stats.completedCount, equals(0));
      expect(stats.completionRate, equals(0.0));
      expect(stats.completionPercentage, equals(0));
      expect(stats.q1Ratio, equals(0.0));
    });
  });
}
