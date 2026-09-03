import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/projects/widgets/create_list_folder_sheet.dart';
import 'package:todo/features/settings/settings_providers.dart';
import '../../helpers/db_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TodoRepository repo;
  late AppSettingsCache cache;

  setUp(() {
    cache = AppSettingsCache();
    db = openTestDatabase();
    repo = TodoRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({
    CreateType initialType = CreateType.list,
    String? initialFolderId,
    List<Project> projects = const [],
    List<Folder> folders = const [],
  }) {
    return ProviderScope(
      overrides: [
        appSettingsCacheProvider.overrideWithValue(cache),
        todoRepositoryProvider.overrideWithValue(repo),
        projectsStreamProvider.overrideWithValue(AsyncData(projects)),
        foldersStreamProvider.overrideWithValue(AsyncData(folders)),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showCreateListFolderSheet(
                      context: context,
                      initialType: initialType,
                      initialFolderId: initialFolderId,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('渲染初始清单模式并显示所有表单模块', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 顶栏
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('新建清单'), findsOneWidget);
    expect(find.text('新建文件夹'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);

    // 模块
    expect(find.text('清单名称'), findsOneWidget);
    expect(find.text('0/24'), findsOneWidget);
    expect(find.text('主题颜色'), findsOneWidget);
    expect(find.text('选择图标'), findsOneWidget);
    expect(find.text('点击即时应用'), findsOneWidget);
    expect(find.text('所属文件夹'), findsOneWidget);
    expect(find.text('单选归属'), findsOneWidget);
    expect(find.text('无 (顶层清单)'), findsOneWidget);

    // 分类胶囊
    expect(find.text('常用'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('生活'), findsOneWidget);
    expect(find.text('学习'), findsOneWidget);
    expect(find.text('健康'), findsOneWidget);
    expect(find.text('财务'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('名称输入与清除按钮交互', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 初始输入为空，无清除按钮
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // 输入名称
    await tester.enterText(find.byType(TextField), '学习计划');
    await tester.pumpAndSettle();

    expect(find.text('4/24'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 点击清除按钮
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('0/24'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('颜色调色盘选择与名称联动', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 初始颜色为曜石黑
    expect(find.text('曜石黑'), findsOneWidget);

    // 点击第二个颜色（克莱因蓝）
    for (final color in kPresetModalColors) {
      if (color.id == 'blue') {
        // 点击选择该颜色
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == color.color,
          ),
        );
        await tester.pumpAndSettle();
        break;
      }
    }

    expect(find.text('克莱因蓝'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('图标分类切换与图标选择', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 切换到「工作」分类
    await tester.tap(find.text('工作'));
    await tester.pumpAndSettle();

    // 应该显示工作分类图标（如办公、电脑）
    expect(find.byIcon(Icons.work_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.laptop_mac_rounded), findsOneWidget);

    // 点击电脑图标
    await tester.tap(find.byIcon(Icons.laptop_mac_rounded));
    await tester.pumpAndSettle();

    // 顶部徽章中应显示电脑图标 (共 2 处：网格 + 顶部徽章)
    expect(find.byIcon(Icons.laptop_mac_rounded), findsNWidgets(2));

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('新建清单并指定所属文件夹成功落库', (tester) async {
    // 预先插入一个文件夹
    final folder = await repo.createFolder(name: '工作空间');

    await tester.pumpWidget(buildTestWidget(folders: [folder]));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 应该列出已有文件夹
    expect(find.text('工作空间'), findsOneWidget);
    expect(find.text('0 个清单'), findsOneWidget);

    // 选中该文件夹
    await tester.ensureVisible(find.text('工作空间'));
    await tester.tap(find.text('工作空间'));
    await tester.pumpAndSettle();

    // 输入清单名称并完成
    await tester.enterText(find.byType(TextField), '前端开发');
    await tester.pumpAndSettle();

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // 弹窗关闭
    expect(find.text('所属文件夹'), findsNothing);

    // 验证 DB 中项目已创建且 folderId 正确
    final projects = await repo.projects.getAll();
    final created = projects.firstWhere((p) => p.name == '前端开发');
    expect(created.folderId, isNotNull);
  });

  testWidgets('新建文件夹模式创建文件夹成功', (tester) async {
    await tester.pumpWidget(buildTestWidget(initialType: CreateType.folder));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // 文件夹模式下不显示所属文件夹
    expect(find.text('文件夹名称'), findsOneWidget);
    expect(find.text('所属文件夹'), findsNothing);

    // 输入文件夹名称并完成
    await tester.enterText(find.byType(TextField), '生活档案');
    await tester.pumpAndSettle();

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    // 验证 DB 中文件夹已创建
    final folders = await repo.folders.getAll();
    expect(folders.any((f) => f.name == '生活档案'), isTrue);
  });
}
