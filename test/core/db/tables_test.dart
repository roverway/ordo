// TaskPriorityConverter / TaskStatusConverter 单测（docs/40-data-model.md §3.1/§3.2）。
//
// 覆盖：合法值域往返、存储值即枚举下标、越界读取回退默认值
// （评审问题 3：priority / status 均已进入同步快照，未来同步引擎/新版本客户端
// 可能带来越界值，读取路径必须崩溃安全；写入路径由枚举驱动，toSql 恒合法）。

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/tables.dart';

void main() {
  const priorityConverter = TaskPriorityConverter();
  const statusConverter = TaskStatusConverter();

  group('TaskPriorityConverter 往返', () {
    test('合法值域 0–3 往返一致', () {
      for (var i = 0; i < TaskPriority.values.length; i++) {
        final value = TaskPriority.values[i];
        expect(priorityConverter.fromSql(priorityConverter.toSql(value)), value);
      }
    });

    test('toSql 存储值 = 枚举下标（0=none/1=low/2=medium/3=high）', () {
      expect(priorityConverter.toSql(TaskPriority.none), 0);
      expect(priorityConverter.toSql(TaskPriority.low), 1);
      expect(priorityConverter.toSql(TaskPriority.medium), 2);
      expect(priorityConverter.toSql(TaskPriority.high), 3);
    });

    test('fromSql 合法值映射正确', () {
      expect(priorityConverter.fromSql(0), TaskPriority.none);
      expect(priorityConverter.fromSql(1), TaskPriority.low);
      expect(priorityConverter.fromSql(2), TaskPriority.medium);
      expect(priorityConverter.fromSql(3), TaskPriority.high);
    });
  });

  group('越界读取回退 none（崩溃安全，评审问题 3）', () {
    test('负值 → none（不抛 RangeError）', () {
      expect(priorityConverter.fromSql(-1), TaskPriority.none);
      expect(priorityConverter.fromSql(-100), TaskPriority.none);
    });

    test('大于枚举长度 → none（未知值不被静默解释为具体优先级）', () {
      expect(priorityConverter.fromSql(4), TaskPriority.none);
      expect(priorityConverter.fromSql(99), TaskPriority.none);
    });
  });

  group('TaskStatusConverter 往返', () {
    test('合法值域 0–3 往返一致', () {
      for (var i = 0; i < TaskStatus.values.length; i++) {
        final value = TaskStatus.values[i];
        expect(statusConverter.fromSql(statusConverter.toSql(value)), value);
      }
    });

    test('toSql 存储值 = 枚举下标（0=todo/1=inProgress/2=done/3=cancelled）', () {
      expect(statusConverter.toSql(TaskStatus.todo), 0);
      expect(statusConverter.toSql(TaskStatus.inProgress), 1);
      expect(statusConverter.toSql(TaskStatus.done), 2);
      expect(statusConverter.toSql(TaskStatus.cancelled), 3);
    });

    test('fromSql 合法值映射正确', () {
      expect(statusConverter.fromSql(0), TaskStatus.todo);
      expect(statusConverter.fromSql(1), TaskStatus.inProgress);
      expect(statusConverter.fromSql(2), TaskStatus.done);
      expect(statusConverter.fromSql(3), TaskStatus.cancelled);
    });
  });

  group('越界读取回退 todo（崩溃安全，评审问题 3）', () {
    test('负值 → todo（不抛 RangeError）', () {
      expect(statusConverter.fromSql(-1), TaskStatus.todo);
      expect(statusConverter.fromSql(-100), TaskStatus.todo);
    });

    test('大于枚举长度 → todo（未知值回退语义默认值）', () {
      expect(statusConverter.fromSql(4), TaskStatus.todo);
      expect(statusConverter.fromSql(99), TaskStatus.todo);
    });
  });
}
