import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = TodoRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomViewDao & TodoRepository Custom Views CRUD', () {
    test('createCustomView 创建并正确递增 sortOrder', () async {
      final view1 = await repo.createCustomView(
        name: '看板1',
        icon: 'dashboard',
        color: 0xFF123456,
        layoutMode: 'kanban',
        panelsJson: '[]',
      );
      expect(view1.name, '看板1');
      expect(view1.icon, 'dashboard');
      expect(view1.color, 0xFF123456);
      expect(view1.layoutMode, 'kanban');
      expect(view1.sortOrder, 0);

      final view2 = await repo.createCustomView(name: '看板2', panelsJson: '[]');
      expect(view2.name, '看板2');
      expect(view2.sortOrder, 1);

      final all = await repo.customViews.getAll();
      expect(all.length, 2);
    });

    test('updateCustomView 更新字段并刷新 updatedAt', () async {
      final view = await repo.createCustomView(name: '原名称', panelsJson: '[]');

      await repo.updateCustomView(
        view.id,
        name: '新名称',
        icon: 'list',
        color: 0xFFAABBCC,
        layoutMode: 'list',
        panelsJson: '[{"id":"p1"}]',
      );

      final updated = await repo.customViews.getById(view.id);
      expect(updated!.name, '新名称');
      expect(updated.icon, 'list');
      expect(updated.color, 0xFFAABBCC);
      expect(updated.layoutMode, 'list');
      expect(updated.panelsJson, '[{"id":"p1"}]');
      expect(updated.updatedAt >= view.updatedAt, isTrue);
    });

    test('deleteCustomView 物理删除并写入墓碑', () async {
      final view = await repo.createCustomView(name: '待删看板', panelsJson: '[]');

      await repo.deleteCustomView(view.id);

      final deleted = await repo.customViews.getById(view.id);
      expect(deleted, isNull);

      final tombstones = await repo.readTombstones();
      expect(
        tombstones.any((t) => t.type == 'custom_view' && t.id == view.id),
        isTrue,
      );
    });

    test('reorderCustomViews 批量重排 sortOrder 连续', () async {
      final v1 = await repo.createCustomView(name: 'V1', panelsJson: '[]');
      final v2 = await repo.createCustomView(name: 'V2', panelsJson: '[]');
      final v3 = await repo.createCustomView(name: 'V3', panelsJson: '[]');

      await repo.reorderCustomViews([v3.id, v1.id, v2.id]);

      final all = await repo.customViews.getAll();
      expect(all.map((v) => v.id).toList(), [v3.id, v1.id, v2.id]);
      expect(all.map((v) => v.sortOrder).toList(), [0, 1, 2]);
    });
  });
}
