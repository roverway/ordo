// 视图匹配纯函数单测（docs/10-requirements.md §9 / FR-VIEW-05/06，
// 70-milestones.md M3 DoD）。
//
// 用固定本地日期 DateTime(2026, 8, 11) 作为「今天」，毫秒值由本地日期换算。

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/utils/view_rules.dart';

/// 构造测试用 Task。
Task _t({
  String id = '',
  int? startAt,
  int? endAt,
  TaskStatus status = TaskStatus.todo,
}) => Task(
  id: id,
  projectId: 'p1',
  parentId: null,
  title: id,
  description: '',
  notes: '',
  status: status,
  startAt: startAt,
  endAt: endAt,
  sortOrder: 0,
  priority: TaskPriority.none,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 本地 DateTime → 毫秒（与 view_rules 的 `fromMillisecondsSinceEpoch(ms)`
/// 往返一致）。
int _ms(DateTime d) => d.millisecondsSinceEpoch;

void main() {
  // 固定「今天」：2026-08-11（本地时区）。
  final todayStart = DateTime(2026, 8, 11);
  final todayEnd = DateTime(2026, 8, 11, 23, 59, 59, 999);
  final yesterday = DateTime(2026, 8, 10);
  final tomorrow = DateTime(2026, 8, 12);
  final dayAfterTomorrow = DateTime(2026, 8, 13);
  final dayBeforeYesterday = DateTime(2026, 8, 9);

  group('matchesToday（§9.1）', () {
    test('startAt 落在今天 → true', () {
      expect(
        matchesToday(_t(startAt: _ms(todayStart)), todayStart, todayEnd),
        isTrue,
      );
      expect(
        matchesToday(_t(startAt: _ms(todayEnd)), todayStart, todayEnd),
        isTrue,
      );
    });

    test('endAt 落在今天 → true', () {
      expect(
        matchesToday(_t(endAt: _ms(todayStart)), todayStart, todayEnd),
        isTrue,
      );
      expect(
        matchesToday(_t(endAt: _ms(todayEnd)), todayStart, todayEnd),
        isTrue,
      );
    });

    test('跨天区间覆盖今天（startAt 昨天 / endAt 明天）→ true', () {
      expect(
        matchesToday(
          _t(startAt: _ms(yesterday), endAt: _ms(tomorrow)),
          todayStart,
          todayEnd,
        ),
        isTrue,
      );
    });

    test('跨天区间：startAt 今天 / endAt 明天 → true', () {
      expect(
        matchesToday(
          _t(startAt: _ms(todayStart), endAt: _ms(tomorrow)),
          todayStart,
          todayEnd,
        ),
        isTrue,
      );
    });

    test('无时间任务 → false', () {
      expect(matchesToday(_t(), todayStart, todayEnd), isFalse);
    });

    test('昨天开始昨天结束 → false（不覆盖今天）', () {
      expect(
        matchesToday(
          _t(startAt: _ms(yesterday), endAt: _ms(yesterday)),
          todayStart,
          todayEnd,
        ),
        isFalse,
      );
    });

    test('完全在未来（startAt 明天 / endAt 后天）→ false', () {
      expect(
        matchesToday(
          _t(startAt: _ms(tomorrow), endAt: _ms(dayAfterTomorrow)),
          todayStart,
          todayEnd,
        ),
        isFalse,
      );
    });
  });

  group('isOverdue（§9.3）', () {
    test('endAt 昨天 + todo → true', () {
      expect(
        isOverdue(_t(endAt: _ms(yesterday)), TaskStatus.todo, todayStart),
        isTrue,
      );
    });

    test('endAt 昨天 + inProgress → true（非 done/cancelled 即逾期）', () {
      expect(
        isOverdue(_t(endAt: _ms(yesterday)), TaskStatus.inProgress, todayStart),
        isTrue,
      );
    });

    test('endAt 昨天 + done → false', () {
      expect(
        isOverdue(_t(endAt: _ms(yesterday)), TaskStatus.done, todayStart),
        isFalse,
      );
    });

    test('endAt 昨天 + cancelled → false', () {
      expect(
        isOverdue(_t(endAt: _ms(yesterday)), TaskStatus.cancelled, todayStart),
        isFalse,
      );
    });

    test('endAt 今天（== todayStart，非早于）→ false', () {
      expect(
        isOverdue(_t(endAt: _ms(todayStart)), TaskStatus.todo, todayStart),
        isFalse,
      );
    });

    test('endAt 为 null → false', () {
      expect(isOverdue(_t(), TaskStatus.todo, todayStart), isFalse);
    });
  });

  group('calendarDaysForTask（§9.2）', () {
    final rangeStart = dayBeforeYesterday;
    final rangeEnd = dayAfterTomorrow;

    test('区间任务（startAt+endAt）→ 区间内每天', () {
      final days = calendarDaysForTask(
        _t(startAt: _ms(dayBeforeYesterday), endAt: _ms(dayAfterTomorrow)),
        rangeStart,
        rangeEnd,
      );
      expect(days.length, 5);
      expect(days, {
        DateTime(2026, 8, 9),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 13),
      });
    });

    test('仅 endAt → 截止日当天', () {
      final days = calendarDaysForTask(
        _t(endAt: _ms(tomorrow)),
        rangeStart,
        rangeEnd,
      );
      expect(days, {DateTime(2026, 8, 12)});
    });

    test('仅 startAt → 开始日当天', () {
      final days = calendarDaysForTask(
        _t(startAt: _ms(yesterday)),
        rangeStart,
        rangeEnd,
      );
      expect(days, {DateTime(2026, 8, 10)});
    });

    test('startAt 与 endAt 都为空 → 空集', () {
      expect(calendarDaysForTask(_t(), rangeStart, rangeEnd), isEmpty);
    });

    test('区间裁剪：任务区间超出 range 只返回 range 内天数', () {
      final days = calendarDaysForTask(
        _t(
          startAt: _ms(DateTime(2026, 8, 1)),
          endAt: _ms(DateTime(2026, 8, 20)),
        ),
        rangeStart,
        rangeEnd,
      );
      expect(days.length, 5);
      expect(days.contains(DateTime(2026, 8, 9)), isTrue);
      expect(days.contains(DateTime(2026, 8, 13)), isTrue);
      expect(days.contains(DateTime(2026, 8, 8)), isFalse);
      expect(days.contains(DateTime(2026, 8, 14)), isFalse);
    });

    test('任务区间与 range 无交集 → 空集', () {
      final days = calendarDaysForTask(
        _t(
          startAt: _ms(DateTime(2026, 1, 1)),
          endAt: _ms(DateTime(2026, 1, 3)),
        ),
        rangeStart,
        rangeEnd,
      );
      expect(days, isEmpty);
    });
  });

  group('matchesSearch（FR-VIEW-05）', () {
    final task = Task(
      id: 't',
      projectId: 'p1',
      parentId: null,
      title: 'Buy Milk',
      description: 'Whole milk from the store',
      notes: 'remember salt',
      status: TaskStatus.todo,
      priority: TaskPriority.none,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );

    test('标题命中 → true', () {
      expect(matchesSearch(task, 'milk'), isTrue);
    });

    test('描述命中 → true', () {
      expect(matchesSearch(task, 'store'), isTrue);
    });

    test('备注命中 → true', () {
      expect(matchesSearch(task, 'salt'), isTrue);
    });

    test('大小写不敏感 → true', () {
      expect(matchesSearch(task, 'BUY'), isTrue);
      expect(matchesSearch(task, 'Milk'), isTrue);
    });

    test('空查询 / 纯空白 → false', () {
      expect(matchesSearch(task, ''), isFalse);
      expect(matchesSearch(task, '   '), isFalse);
    });

    test('未命中 → false', () {
      expect(matchesSearch(task, 'nothing-here'), isFalse);
    });
  });

  group('inTimeRange（FR-VIEW-06）', () {
    test('startAt 在区间内且 endAt 为 null → true', () {
      final t = _t(startAt: _ms(todayStart));
      expect(inTimeRange(t, yesterday, tomorrow), isTrue);
    });

    test('区间任务与 range 相交（startAt 昨天 / endAt 明天）→ true', () {
      final t = _t(startAt: _ms(yesterday), endAt: _ms(tomorrow));
      expect(inTimeRange(t, todayStart, todayEnd), isTrue);
    });

    test('startAt 在区间之后 → false', () {
      final t = _t(startAt: _ms(tomorrow));
      expect(inTimeRange(t, yesterday, todayEnd), isFalse);
    });

    test('startAt 在区间之前且 endAt 在区间之前 → false', () {
      final t = _t(startAt: _ms(dayBeforeYesterday), endAt: _ms(yesterday));
      expect(inTimeRange(t, todayStart, todayEnd), isFalse);
    });

    test('无时间任务 → false（不参与时间段筛选）', () {
      expect(inTimeRange(_t(), todayStart, todayEnd), isFalse);
    });

    test('仅 endAt（startAt 为 null）→ endAt 落在区间内则 true', () {
      final t = _t(endAt: _ms(todayStart));
      expect(inTimeRange(t, yesterday, tomorrow), isTrue);
    });

    test('仅 endAt 且 endAt 在区间之前 → false', () {
      final t = _t(endAt: _ms(yesterday));
      expect(inTimeRange(t, todayStart, todayEnd), isFalse);
    });
  });

  group('applyTaskFilter（FR-VIEW-06）', () {
    final t1 = _t(id: 't1', startAt: _ms(todayStart), status: TaskStatus.todo);
    final t2 = _t(
      id: 't2',
      startAt: _ms(yesterday),
      endAt: _ms(tomorrow),
      status: TaskStatus.done,
    );
    final t3 = _t(id: 't3', status: TaskStatus.inProgress); // 无时间
    final all = [t1, t2, t3];
    final effective = {
      't1': TaskStatus.todo,
      't2': TaskStatus.done,
      't3': TaskStatus.inProgress,
    };

    List<String> ids(List<Task> tasks) => tasks.map((t) => t.id).toList();

    test('状态筛选（按 effectiveStatuses 映射）', () {
      expect(ids(applyTaskFilter(all, effective, status: TaskStatus.done)), [
        't2',
      ]);
      expect(ids(applyTaskFilter(all, effective, status: TaskStatus.todo)), [
        't1',
      ]);
    });

    test('派生状态优先于 task.status', () {
      // t4 存储 status=todo，但映射给派生 done → 按 done 筛中。
      final t4 = _t(
        id: 't4',
        startAt: _ms(todayStart),
        status: TaskStatus.todo,
      );
      final map = {'t4': TaskStatus.done};
      expect(ids(applyTaskFilter([t4], map, status: TaskStatus.done)), ['t4']);
      expect(applyTaskFilter([t4], map, status: TaskStatus.todo), isEmpty);
    });

    test('映射缺失条目回退到 task.status', () {
      expect(ids(applyTaskFilter([t1], {}, status: TaskStatus.todo)), ['t1']);
      expect(applyTaskFilter([t1], {}, status: TaskStatus.done), isEmpty);
    });

    test('时间段筛选（rangeStart/rangeEnd 均非 null 才生效）', () {
      expect(
        ids(
          applyTaskFilter(
            all,
            effective,
            rangeStart: todayStart,
            rangeEnd: todayEnd,
          ),
        ),
        ['t1', 't2'],
      );
      // t3 无时间 → 不入选。
    });

    test('仅传 rangeStart（rangeEnd 为 null）→ 时间段不生效', () {
      expect(ids(applyTaskFilter(all, effective, rangeStart: todayStart)), [
        't1',
        't2',
        't3',
      ]);
    });

    test('allowedTaskIds 筛选（标签关联由调用方解析为 taskId 集合）', () {
      expect(
        ids(applyTaskFilter(all, effective, allowedTaskIds: {'t1', 't3'})),
        ['t1', 't3'],
      );
    });

    test('多条件 AND 叠加', () {
      expect(
        ids(
          applyTaskFilter(
            all,
            effective,
            status: TaskStatus.done,
            rangeStart: todayStart,
            rangeEnd: todayEnd,
            allowedTaskIds: {'t1', 't2'},
          ),
        ),
        ['t2'],
      );
    });

    test('无任何条件 → 原样返回', () {
      expect(ids(applyTaskFilter(all, effective)), ['t1', 't2', 't3']);
    });
  });
}
