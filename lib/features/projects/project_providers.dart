import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/todo_repository.dart';

export '../../core/db/repositories/todo_repository.dart' show TodoRepository;

/// 全局 Repository Provider（M2 复用 M1 已实现的数据层）。
///
/// 编辑自动同步接线（FR-SYNC-02）：Repository.onDataChanged 在 **main.dart**
/// 中手工注入 `syncTriggers.onEdit`（容器创建后赋值）。这里不能在 Provider
/// 构造时 watch syncTriggersProvider——会形成 syncTriggers → syncEngine →
/// todoRepository 的循环依赖。测试直接 `overrideWithValue` 传入自建仓库时
/// 回调保持 null（无自动同步），符合预期。
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return TodoRepository();
});

/// 全部未删除项目（按 sortOrder 升序，StreamProvider 自动刷新）。
final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.projects.watchAll();
});

/// 全部未删除文件夹（按 sortOrder 升序，StreamProvider 自动刷新）。
final foldersStreamProvider = StreamProvider<List<Folder>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.folders.watchAll();
});

/// 项目分组结果（docs/62-folder-nav.md §4.3：文件夹组 + 未分组组）。
///
/// 供抽屉与 /projects 页共用；分组在 Provider/UI 层完成（D5：
/// projectsStreamProvider 仍返回全量项目，UI 不感知 DB 排序）。
class ProjectGrouping {
  const ProjectGrouping({
    this.folders = const [],
    this.folderProjects = const {},
    this.ungrouped = const [],
  });

  /// 按 sortOrder 升序的文件夹。
  final List<Folder> folders;

  /// folderId → 组内项目（按 sortOrder 升序；不含内置收件箱）。
  final Map<String, List<Project>> folderProjects;

  /// 未分组项目（folderId == null，按 sortOrder 升序；不含内置收件箱）。
  final List<Project> ungrouped;

  /// 文件夹内项目数（拖拽入夹时 newIndex = 追加到组尾）。
  int countInFolder(String folderId) => folderProjects[folderId]?.length ?? 0;

  /// 未分组项目数（拖拽出夹时 newIndex = 追加到组尾）。
  int get ungroupedCount => ungrouped.length;

  /// 项目在目标组内的索引（拖拽组内重排 newIndex 用）。
  ///
  /// [folderId] 为 null = 未分组组；组内索引按**全量集合**计数
  /// （与 task_tree 最新语义一致，docs/62-folder-nav.md §6.2）。
  int indexInGroup(Project project, {String? folderId}) {
    final group = folderId == null
        ? ungrouped
        : (folderProjects[folderId] ?? const <Project>[]);
    return group.indexWhere((p) => p.id == project.id);
  }
}

/// 分组聚合 Provider：项目按 folderId 分组（文件夹组 + 未分组组）。
///
/// 抽屉与 /projects 页共用（D4/D5）；折叠状态与拖拽等交互不在此层。
final projectsByFolderProvider = Provider<AsyncValue<ProjectGrouping>>((ref) {
  final projectsAsync = ref.watch(projectsStreamProvider);
  final foldersAsync = ref.watch(foldersStreamProvider);
  if (projectsAsync.hasError) {
    return AsyncError(
      projectsAsync.error!,
      projectsAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (foldersAsync.hasError) {
    return AsyncError(
      foldersAsync.error!,
      foldersAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (projectsAsync.isLoading || foldersAsync.isLoading) {
    return const AsyncLoading();
  }
  // 内置收件箱由系统组 /inbox 承载，不列入分组（Bug 3 语义不变）。
  final visible = projectsAsync.requireValue.where(
    (p) => p.id != inboxProjectId,
  );
  final folderProjects = <String, List<Project>>{};
  final ungrouped = <Project>[];
  for (final p in visible) {
    final folderId = p.folderId;
    if (folderId == null) {
      ungrouped.add(p);
    } else {
      folderProjects.putIfAbsent(folderId, () => []).add(p);
    }
  }
  // projectsStreamProvider 按 sortOrder 全局排序，分组后**组内**重排一次
  //（sortOrder 语义为组内排序，docs/62-folder-nav.md §4.3）。
  for (final list in folderProjects.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
  ungrouped.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return AsyncData(
    ProjectGrouping(
      folders: foldersAsync.requireValue,
      folderProjects: folderProjects,
      ungrouped: ungrouped,
    ),
  );
});

/// 文件夹展开/折叠状态（settings 表持久化，设备本地，不同步，D6）。
///
/// - 默认展开（缺失 = 展开）；
/// - 切换时写入 settings 表 `folder_expanded_<id>`（'1' 展开 / '0' 折叠），
///   读写走 SettingsDao（仿 settings 读写模式，40-data-model.md §2.5）。
final folderExpandProvider =
    AsyncNotifierProvider<FolderExpandNotifier, Map<String, bool>>(
      FolderExpandNotifier.new,
    );

class FolderExpandNotifier extends AsyncNotifier<Map<String, bool>> {
  /// settings key 前缀（设备本地，不同步）。
  static const String _keyPrefix = 'folder_expanded_';
  static const String _expanded = '1';
  static const String _collapsed = '0';

  @override
  Future<Map<String, bool>> build() async {
    final settings = ref.watch(todoRepositoryProvider).settings;
    final all = await settings.getAll();
    return {
      for (final entry in all.entries)
        if (entry.key.startsWith(_keyPrefix))
          entry.key.substring(_keyPrefix.length): entry.value != _collapsed,
    };
  }

  /// 切换某文件夹展开状态并持久化（默认展开 → 折叠）。
  Future<void> toggle(String folderId) async {
    final current = Map<String, bool>.from(state.value ?? const {});
    final next = !(current[folderId] ?? true);
    await ref
        .read(todoRepositoryProvider)
        .settings
        .set('$_keyPrefix$folderId', next ? _expanded : _collapsed);
    state = AsyncData({...current, folderId: next});
  }
}

/// 全部未删除任务流（updatedAt 降序，FR-VIEW-05）。
///
/// 跨视图共享（日历/搜索/标签详情/今日均消费）：单独成 provider 让各视图
/// 共用同一份流订阅（Riverpod 按 provider 去重，避免同一查询被订阅多次）。
/// 返回扁平列表，视图层再各自过滤/排序（view_rules.dart）。
final allActiveTasksProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tasks.watchAllActive();
});
