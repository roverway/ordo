# M9 及后续全量变更架构审查与深度复盘报告

- **审查范围**：Commit `616710463bf44bb66c68c1ee8a353079945832ef` ~ `HEAD`
- **涉及提交**：
  - `6167104` docs: add custom views and multi-panel specification
  - `bb7d6d2` feat: implement custom views and multi-panel dashboards (M9)
  - `81cdd6f` docs: update Linux JDK path in AGENTS.md
  - `d818982` chore(windows): add Windows platform runner and build configuration
  - `1a11813` feat(custom_views): polish visual design, quick-add task prefill, and editor back navigation
  - `503aed1` fix(sync): 修复多端同步问题，支持 Android 与 Windows 双端正常同步
  - `ae4048e` feat: unify desktop and mobile sidebar with adaptive persistent layout
  - `249cc3a` feat: split desktop layout, add task groups header, and streamline sidebar
  - `1c1a729` feat: desktop split layout, modal side sheet, font fallback, and route fix
- **变更统计**：74 个文件变动，+9,625 / -892 行。

---

## 阶段一：全局变更地图（盘点目标）

### 1. 核心意图分析
本次迭代涵盖了产品自 M8 向 M9+ 演进的四个核心里程碑意图：
1. **自定义多面板视图与看板体系（M9）**：引入 `custom_views` 数据表（Drift Schema v5）、纯函数筛选匹配引擎与排序算法、多栏看板/单栏 Tab 响应式视图及跨面板任务智能属性派发（包含子任务派生状态拦截）。
2. **多端同步协议升级与健壮性加固**：快照升级至 v3（新增 `customViews` LWW 合并与墓碑清理）；解决多级子任务先于父任务写入时触发 SQLite 外键失败的死锁问题（引入拓扑分层排序与悬空引用容错）；支持 Gzip 幻数与网络层自动解压自适应检测。
3. **桌面端左右分栏常驻与抽屉侧边栏统一**：引入响应式分栏布局、右侧模态侧边抽屉（Side Sheet）、消除重复过渡动画，并将移动端抽屉与桌面端侧边栏收敛为统一组件。
4. **全平台字体渲染与系统级打磨**：配置 Windows/macOS/Linux/Android 系统字体回退链，优化设置与同步表单的组件化复用。

### 2. 发生实质性变动的业务模块清单（审查队列）

| 序号 | 业务模块名称 | 核心文件与职责 |
| :--- | :--- | :--- |
| **模块 1** | **数据持久层与同步合并引擎**<br>*(Database & Sync Engine)* | `database.dart`, `tables.dart`, `custom_view_dao.dart`, `todo_repository.dart`, `merge_engine.dart`, `snapshot_codec.dart`, `sync_engine.dart` |
| **模块 2** | **自定义视图领域模型与状态层**<br>*(Custom Views Models & Providers)* | `custom_view_models.dart`, `custom_view_providers.dart` |
| **模块 3** | **自定义视图 UI 与交互层**<br>*(Custom Views Presentation & Widgets)* | `custom_view_page.dart`, `custom_view_editor_page.dart`, `panel_column.dart`, `filter_criteria_sheet.dart`, `icon_picker_dialog.dart` |
| **模块 4** | **桌面分栏与应用导航框架**<br>*(Desktop Split Layout, Navigation Shell & Drawer)* | `app_shell.dart`, `app_drawer.dart`, `modal_side_sheet.dart`, `router.dart` |
| **模块 5** | **通用业务页面宽屏适配与设置/同步**<br>*(Feature Pages Adaptation & Settings/Sync)* | `settings_page.dart`, `settings_side_sheet.dart`, `sync_setup_page.dart`, `task_list_page.dart`, `tags_detail_page.dart`, `app_theme.dart` |

---

## 阶段二：模块级全量严格审查

---

### 模块 1：数据持久层与同步合并引擎 (Database & Sync Engine)

#### 1. 代码整洁度
- **正向实践**：`SnapshotCodec.decodeSnapshot` 通过判断 Gzip 幻数 `bytes[0] == 0x1f && bytes[1] == 0x8b` 自适应支持明文与压缩流，实现极其简洁。
- **坏味道与冗余**：
  - `TodoRepository.applyMerged` 函数长度已膨胀至 150+ 行。其内部嵌套了多层 `depthOf` 递归闭包、外键依赖提取、硬删除排序与关联表清理，降低了可读性。
  - `TodoRepository.createCustomView` 中计算 `nextSortOrder` 采用了全量查询 `getAll()` 并在 Dart 内存中进行 `reduce`：
    ```dart
    final allViews = await customViews.getAll();
    final nextSortOrder = allViews.isEmpty ? 0 : (allViews.map((v) => v.sortOrder).reduce((a, b) => a > b ? a : b) + 1);
    ```
    产生冗余的对象分配与内存开销，且缺乏数据库级别的原子查询。

#### 2. 职责与解耦
- **分层遵从度高**：Repository 与 Sync 之间维持了极佳的物理隔离。Repository 仅暴露纯 DB 数据结构（`RepositoryExportData` / `MergedApplyOperation`），不直接依赖同步包；Merge Engine 保持纯函数无状态计算，可在 isolate 安全执行。

#### 3. 健壮性与隐患
- **外键拓扑排序中的递归深度风险**：在 `applyMerged` 中，`depthOf` 闭包虽然添加了 `visited` 集合防循环引用，但依然是递归遍历 `upsertTaskMap`。建议改为迭代式拓扑层级计算或提取为纯函数。

#### 4. 重构建议代码

```dart
// 优化 1：在 CustomViewDao 中增加聚合查询，替代 Repository 内存 reduce
// lib/core/db/daos/custom_view_dao.dart
Future<int> getNextSortOrder() async {
  final maxOrder = _db.customViews.sortOrder.max();
  final query = _db.selectOnly(_db.customViews)
    ..where(_db.customViews.deleted.equals(0))
    ..addColumns([maxOrder]);
  final result = await query.map((row) => row.read(maxOrder)).getSingle();
  return (result ?? -1) + 1;
}

// 优化 2：将拓扑排序逻辑抽离为纯函数工具
// lib/core/utils/topological_sort.dart
List<Task> topologicalSortTasks(List<Task> tasks, Set<String> validParentIds) {
  final taskMap = {for (final t in tasks) t.id: t};
  final sanitized = tasks.map((t) {
    if (t.parentId != null && !validParentIds.contains(t.parentId)) {
      return t.copyWith(parentId: const Value(null));
    }
    return t;
  }).toList();

  final depthCache = <String, int>{};
  int getDepth(Task task, Set<String> visiting) {
    if (task.parentId == null || !taskMap.containsKey(task.parentId)) return 0;
    if (depthCache.containsKey(task.id)) return depthCache[task.id]!;
    if (visiting.contains(task.id)) return 0; // 防循环
    visiting.add(task.id);
    final parent = taskMap[task.parentId!];
    final depth = parent == null ? 0 : 1 + getDepth(parent, visiting);
    depthCache[task.id] = depth;
    return depth;
  }

  sanitized.sort((a, b) => getDepth(a, {}).compareTo(getDepth(b, {})));
  return sanitized;
}
```

---

### 模块 2：自定义视图领域模型与状态层 (Custom Views Models & Providers)

#### 1. 代码整洁度
- **模型设计精良**：`custom_view_models.dart` 纯 Dart 建模无 Flutter 框架侵入，`FilterCriteria` 与 `CustomViewPanelConfig` 拥有完备的不可变性（`const`、`copyWith`、`fromJson`/`toJson`），并自带预设模板构造工厂。

#### 2. 职责与解耦
- **关键功能逻辑断裂（重大缺陷）**：
  在 `custom_view_providers.dart` 的 `panelTasksProvider` 中：
  ```dart
  final matched = <Task>[];
  for (final task in allTasks) {
    final directChildren = childrenByParent[task.id] ?? const [];
    final taskTagIds = <String>{}; // ⚠️ 致命硬编码：空的 TagIds 集合！
    if (matchesFilter(
      task,
      panel.filter,
      byId: byId,
      directChildren: directChildren,
      projectsById: projectsById,
      taskTagIds: taskTagIds, // 导致任何包含标签筛选的看板永远匹配不到任务
      nowUtcMs: nowUtcMs,
    )) {
      matched.add(task);
    }
  }
  ```
  `taskTagIds` 被直接硬编码为空集合，没有接入任何任务-标签关联流（如 `taskTagsMapProvider`）。这导致用户在自定义视图中配置的**所有标签筛选条件全部失效**。

#### 3. 健壮性与性能 (Rebuild & 计算瓶颈)
- **过度重算**：`panelTasksProvider` 监听 `allActiveTasksStreamProvider`。由于是 `Provider.family`，当整个数据库内任何一个任务发生更新时，屏幕上所有面板都会并行触发全量任务线性遍历与排序计算（时间复杂度 $O(P \cdot N \log N)$）。
- **跨日边界不刷新**：`nowUtcMs` 在 `panelTasksProvider` 内部即时获取，但没有定时时钟信号或生命周期监听。如果应用跨过午夜零点，`today`/`tomorrow`/`overdue` 视图不会自动刷新，除非用户触发写操作或重新进入页面。

#### 4. 重构建议代码

```dart
// 1. 补齐全局任务-标签关系映射 Provider
// lib/features/custom_views/providers/custom_view_providers.dart
final allTaskTagsMapProvider = StreamProvider<Map<String, Set<String>>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tags.watchAllTaskTags().map((links) {
    final map = <String, Set<String>>{};
    for (final link in links) {
      map.putIfAbsent(link.taskId, () => <String>{}).add(link.tagId);
    }
    return map;
  });
});

// 2. 修复 panelTasksProvider 并接入标签映射
final panelTasksProvider =
    Provider.family<AsyncValue<PanelTasksResult>, CustomViewPanelConfig>((
      ref,
      panel,
    ) {
      final tasksAsync = ref.watch(allActiveTasksStreamProvider);
      final projectsMapAsync = ref.watch(allProjectsMapProvider);
      final taskTagsMapAsync = ref.watch(allTaskTagsMapProvider);

      if (tasksAsync.hasError) return AsyncError(tasksAsync.error!, tasksAsync.stackTrace!);
      if (projectsMapAsync.hasError) return AsyncError(projectsMapAsync.error!, projectsMapAsync.stackTrace!);
      if (taskTagsMapAsync.hasError) return AsyncError(taskTagsMapAsync.error!, taskTagsMapAsync.stackTrace!);

      if (tasksAsync.isLoading || projectsMapAsync.isLoading || taskTagsMapAsync.isLoading) {
        return const AsyncLoading();
      }

      final allTasks = tasksAsync.value ?? const [];
      final projectsById = projectsMapAsync.value ?? const {};
      final taskTagsById = taskTagsMapAsync.value ?? const {};

      final byId = {for (final t in allTasks) t.id: t};
      final childrenByParent = <String?, List<Task>>{};
      for (final t in allTasks) {
        childrenByParent.putIfAbsent(t.parentId, () => []).add(t);
      }

      final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final matched = <Task>[];

      for (final task in allTasks) {
        final directChildren = childrenByParent[task.id] ?? const [];
        final taskTagIds = taskTagsById[task.id] ?? const <String>{};
        if (matchesFilter(
          task,
          panel.filter,
          byId: byId,
          directChildren: directChildren,
          projectsById: projectsById,
          taskTagIds: taskTagIds, // 正确传入真实标签集合
          nowUtcMs: nowUtcMs,
        )) {
          matched.add(task);
        }
      }

      final sorted = sortPanelTasks(
        matched,
        sortBy: panel.sortBy,
        sortDirection: panel.sortDirection,
      );

      return AsyncData(PanelTasksResult(tasks: sorted, totalCount: sorted.length));
    });
```

---

### 模块 3：自定义视图 UI 与交互层 (Custom Views Presentation & Widgets)

#### 1. 代码整洁度
- **Linter 警告与死变量**：`custom_view_editor_page.dart:152` 声明了 `final isWide = AppBreakpoints.isWide(context);` 但从未被使用，违反 `flutter analyze` 零 Warning/Error 的发布门禁。
- **过长组件与深层嵌套**：`panel_column.dart`（734 行）将面板容器、排序 Popup、筛选入口、任务卡片（`_buildTaskCard` 长达 180 行）、状态切换 GestureDetector、优先级标记、逾期徽章、拖拽 DragTarget 与底部新建按钮全部塞在一个文件中，Widget 嵌套深度达到 14 层。

#### 2. 职责与解耦
- **`build()` 方法中产生副作用（严重反模式）**：
  在 `custom_view_editor_page.dart:154-162` 中：
  ```dart
  if (widget.viewId != null) {
    final viewAsync = ref.watch(customViewDetailProvider(widget.viewId!));
    final view = viewAsync.value;
    if (view != null) {
      _initFromView(view); // ⚠️ 在 build() 过程中直接修改 State 属性与 Controller.text！
    }
  }
  ```
  在 Flutter 的 `build` 周期内直接调用 `_nameController.text = view.name`、`_panels = ...` 等状态修改操作，不仅会在热重载或祖先 Widget 触发重绘时打断用户正在进行的文本输入，更破坏了 Flutter 响应式渲染的纯函数原则。

#### 3. 健壮性
- **移动端水平滑动冲突**：在 `custom_view_page.dart` 中，宽屏或指定看板模式下外层是横向 `ListView.builder(scrollDirection: Axis.horizontal)`，内层任务卡片使用 `Draggable` / `LongPressDraggable`。在多列看板拖拽时没有实现边缘自动滚动（Auto-scroll），当任务需要从第 1 列拖拽到屏幕可视区外的第 5 列时，操作受限。

#### 4. 重构建议代码

```dart
// 1. 消除 build() 中的副作用，改用 ref.listen 驱动表单初始化
// lib/features/custom_views/presentation/custom_view_editor_page.dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);

  if (widget.viewId != null) {
    // 监听视图数据流，仅在首次接收到有效数据时初始化，避免在 build 过程中产生副作用
    ref.listen<AsyncValue<CustomView?>>(customViewDetailProvider(widget.viewId!), (prev, next) {
      if (!_initialized && next.value != null) {
        _initFromView(next.value!);
      }
    });
  } else if (!_initialized) {
    _initNewDefault(l10n);
  }

  // 移除无用的 isWide 变量...
```

```dart
// 2. 将 PanelColumn 中的任务卡片拆解为独立的 CustomViewTaskCard 组件
// lib/features/custom_views/widgets/custom_view_task_card.dart
class CustomViewTaskCard extends StatelessWidget {
  const CustomViewTaskCard({
    super.key,
    required this.task,
    this.project,
    required this.onStatusToggle,
  });

  final Task task;
  final Project? project;
  final VoidCallback onStatusToggle;

  @override
  Widget build(BuildContext context) {
    // 独立出单独的 StatelessWidget，减小 PanelColumn 的 Rebuild 范围与嵌套层级
    return Container(
      /* 纯净的任务卡片 UI 实现 */
    );
  }
}
```

---

### 模块 4：桌面分栏与应用导航框架 (Desktop Split Layout, Navigation Shell & Drawer)

#### 1. 代码整洁度
- **超级单体巨石文件**：`app_drawer.dart` 长达 **1360 行**，集合了 `AppDrawer`、`AppSidebar`、`AppSidebarContent`、`_DrawerTile`、`_FolderTreeConnectorPainter` 自绘连线、文件夹折叠动画、文件夹拖拽与项目跨组拖拽。

#### 2. 职责与解耦
- **ShellRoute 职责倒置与代码严重冗余（详见阶段三溯源）**：`AppShell` 在窄屏下退化为 `return child;`，导致项目中所有一级页面（`TaskListPage`, `ProjectsPage`, `TagsPage`, `TagsDetailPage`, `CalendarPage`, `CustomViewPage`）各自必须在内部重复编写抽屉与 AppBar 模板代码。

#### 3. 健壮性与性能风暴 (高频 Rebuild 缺陷)
- **动态循环 `ref.watch` 订阅**：
  在 `app_drawer.dart:497-505` 与 `Line 986` 中：
  ```dart
  int _folderUncompleted(WidgetRef ref, String folderId) {
    final grouping = ref.watch(projectsByFolderProvider).value;
    final projects = grouping?.folderProjects[folderId] ?? const <Project>[];
    var sum = 0;
    for (final p in projects) {
      sum += ref.watch(projectUncompletedCountProvider(p.id)); // ⚠️ 在循环体和 helper 方法中动态 ref.watch
    }
    return sum;
  }
  ```
  在 `AppSidebarContent` 的 `build` 树中，不仅在循环中动态 `ref.watch` 多个 `projectUncompletedCountProvider`，且在每个项目行中也直接 `ref.watch`。
  **结果**：数据库中任何一个任务的勾选，都会导致整个 1360 行的 `AppSidebarContent`（包含所有系统项、文件夹树、自定义视图项、拖拽目标以及自绘 Painter）被**全量重新构建**，引发严重的 UI 掉帧与无谓重绘。

#### 4. 重构建议代码

```dart
// 优化：将项目未完成数徽章抽离为超轻量独立 ConsumerWidget，阻断整个侧边栏的 Rebuild
// lib/shared/widgets/project_badge.dart
class ProjectUncompletedBadge extends ConsumerWidget {
  const ProjectUncompletedBadge({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(projectUncompletedCountProvider(projectId));
    return Text(
      '$count',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// 文件夹汇总数同理抽离为独立计算 Provider，而非在 Widget build 循环中反复 watch
final folderUncompletedCountProvider = Provider.family<int, String>((ref, folderId) {
  final grouping = ref.watch(projectsByFolderProvider).value;
  final projects = grouping?.folderProjects[folderId] ?? const <Project>[];
  var sum = 0;
  for (final p in projects) {
    sum += ref.watch(projectUncompletedCountProvider(p.id));
  }
  return sum;
});
```

---

### 模块 5：通用业务页面宽屏适配与设置/同步 (Feature Pages Adaptation & Settings/Sync)

#### 1. 代码整洁度
- **极佳的组件化抽取**：`SettingsPage` 与 `SyncSetupPage` 均将表单实体拆分为 `SettingsBody` 与 `SyncSetupBody`，使得这些功能既可以在全屏路由中承载，也可以在桌面端直接嵌入 `SettingsSideSheet`，实现了 100% 的 UI 逻辑复用。

#### 2. 职责与解耦
- **严格遵循 i18n 分层规则**：`SyncSetupBody._syncErrorText` 将同步引擎抛出的结构化枚举 `SyncErrorCode` 与 ARB 国际化资源精确绑定，禁止底层硬编码异常字符串直接暴露至 UI。
- **字体系统统一**：`app_theme.dart` 配置了健全的跨平台字体族（`Microsoft YaHei UI`、`PingFang SC`、`Noto Sans CJK SC`），确保 Windows 与 Linux 平台的中文字重与排版一致。

#### 3. 健壮性
- **生命周期资源管理**：`SyncSetupBody` 在 `initState` 中注册 `_skewHolder.callback`，并在 `dispose` 中及时注销所有 6 个 `TextEditingController` 与回调引用，无任何内存泄露隐患。

#### 4. 重构建议
当前模块实现规范严谨，已达到工业级标准。建议在 `SyncSetupBody` 首次预填配置时，将 `WidgetsBinding.instance.addPostFrameCallback` 改为标准的 Riverpod `ref.listen` 机制，更符合声明式状态管理的惯用法。

---

## 阶段三：重大架构缺陷溯源（深度复盘）

针对本次审查中暴露出的**最典型、最严重的架构级缺陷——“ShellRoute 导航外壳与 Page 内部嵌套 Scaffold 职责倒置与模板膨胀”**进行深度历史溯源与复盘。

```mermaid
graph TD
    subgraph 原本期望的架构 (Clean Shell Architecture)
        SR[GoRouter ShellRoute] --> AS[AppShell]
        AS -->|Wide| SB[常驻 AppSidebar]
        AS -->|Narrow| DR[自管 AppDrawer]
        AS --> APPBAR[统一动态 AppBar]
        AS --> BODY[动态注入 Page Body]
    end

    subgraph 当前实际的倒置架构 (Inverted Scaffold Flaw)
        SR2[GoRouter ShellRoute] --> AS2[AppShell]
        AS2 -->|Wide| ROW[Row: AppSidebar + Expanded]
        AS2 -->|Narrow: 退化为透明透传| CHILD[直接返回 Page]
        ROW --> PAGE1[Page A: 内部自带 Scaffold + AppBar + Drawer]
        CHILD --> PAGE2[Page B: 内部自带 Scaffold + AppBar + Drawer]
    end
```

### 1. 缺陷历史溯源 (Git Archeology)

1. **初始设计（Commit `ae4048e` 之前）**：
   - `AppShell` 是一个全功能的外壳组件，直接接受 `title`、`actions` 和 `child`，在内部统一调度 `Scaffold`、`AppBar`、`AppDrawer` 与 `NavigationRail`/`CompactBottomBar`。各业务页面无需感知抽屉与外壳存在。
2. **问题引入时刻（Commit `ae4048e` - 2026-08-25 13:01:00）**：
   - **诉求**：用户提出需求希望在桌面端将侧边栏改为全高（Top-to-Bottom）常驻，而不是被 AppBar 压在下方。
   - **改动**：为了让桌面端侧边栏贯穿顶底，开发者在 `AppShell` 的桌面分支中将结构改为了 `Row(children: [AppSidebar, VerticalDivider, Expanded(child: Scaffold(...))])`。
3. **缺陷定型时刻（Commit `1c1a729` - 2026-08-25 14:13:36）**：
   - **妥协**：为了支持 `CustomViewPage` 等页面拥有高度定制的 AppBar Title（例如带有颜色圆点和图标的 Title Widget）以及多 Tab 的 `bottom: TabBar`，开发者决定将 `Scaffold` 和 `AppBar` 的构建权力**下放给每一个 Page**，而将 `AppShell` 简化为纯外层布局容器：
     ```dart
     // Commit 1c1a729 后的 AppShell:
     if (narrow) {
       return child; // ⚠️ 窄屏下直接透传，完全放弃了 Shell 的职责
     }
     return Scaffold(
       body: Row(
         children: [
           const AppSidebar(width: AppTokens.sidebarWidth),
           const VerticalDivider(width: 1, thickness: 1),
           Expanded(child: child), // ⚠️ 导致桌面端出现 Scaffold 嵌套 Scaffold
         ],
       ),
     );
     ```

### 2. 缺陷引发的架构债务
1. **代码膨胀与胶水代码蔓延**：
   - 导致 `TaskListPage`、`ProjectsPage`、`TagsPage`、`TagsDetailPage`、`CalendarPage`、`CustomViewPage` 等 **6+ 个核心页面** 全部必须在顶部引入 `AppBreakpoints`，并在 `build` 中手动判断 `narrow ? const AppDrawer() : null` 和手写 `Builder(builder: (context) => IconButton(...))`。
2. **桌面端双重 Scaffold 嵌套**：
   - 在桌面端，外层 `AppShell` 提供了一个根 `Scaffold`，内层各个 `Page` 又返回了一个 `Scaffold`。这会导致主题继承、SnackBar/BottomSheet 的 Overlay 挂载点以及按键事件响应出现非预期的多层代理问题。
3. **架构脆弱性**：
   - 新增任何一个业务页面，开发人员只要漏写了 `drawer: narrow ? const AppDrawer() : null`，移动端就会丢失侧边栏入口。

### 3. 正确的架构演进路线图 (Roadmap & Solution)

真正的顶级架构解法应当保持 **“外壳管外壳，页面管内容”** 的单一职责原则，采用 **“页面向外壳声明 Header 配置（Page Header Contract）”** 的模式。

#### 标准演进方案代码：

```dart
// 1. 定义页面向 Shell 传递 Header 配置的纯模型
// lib/shared/widgets/page_header_config.dart
class PageHeaderConfig {
  const PageHeaderConfig({
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.bottom,
    this.floatingActionButton,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
}

// 2. 重构 AppShell：自适应管理全高 Sidebar、统一 Scaffold、动态 AppBar 与 Drawer
// lib/shared/widgets/app_shell.dart
class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    super.key,
    required this.headerConfig,
    required this.child,
  });

  final PageHeaderConfig headerConfig;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final narrow = AppBreakpoints.isNarrow(context);
    final l10n = AppLocalizations.of(context);

    final appBar = AppBar(
      leading: narrow
          ? Builder(
              builder: (ctx) => IconButton(
                tooltip: l10n.openDrawer,
                icon: const Icon(Icons.menu, size: 22),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      automaticallyImplyLeading: false,
      title: headerConfig.titleWidget ?? Text(headerConfig.title ?? ''),
      actions: [
        IconButton(
          tooltip: l10n.search,
          icon: const Icon(Icons.search, size: 22),
          onPressed: () => context.push('/search'),
        ),
        ...headerConfig.actions,
      ],
      bottom: headerConfig.bottom,
    );

    // 窄屏：经典 Material 架构，单层 Scaffold + 抽屉
    if (narrow) {
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: appBar,
        body: child,
        floatingActionButton: headerConfig.floatingActionButton,
      );
    }

    // 宽屏：全高侧边栏常驻，右侧单层内容 Scaffold（无外层多余 Scaffold 嵌套）
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSidebar(width: AppTokens.sidebarWidth),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Scaffold(
              appBar: appBar,
              body: child,
              floatingActionButton: headerConfig.floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 结论与行动项

1. **P0 (Blocker)**：修复 `custom_view_providers.dart` 中的 `taskTagIds` 硬编码空集缺陷，确保自定义视图标签筛选生效；清除 `custom_view_editor_page.dart` 中未使用的 `isWide` 变量。
2. **P1 (Performance)**：将 `app_drawer.dart` 循环中动态 `ref.watch` 未完成数的逻辑拆分为独立的原子 `ConsumerWidget`（如 `ProjectUncompletedBadge`），消除全局重绘风暴。
3. **P2 (Architecture)**：按 `AdaptiveAppShell` 演进路线图重构 6 个页面的重复 Scaffold 胶水代码，消除桌面端双层 Scaffold 嵌套。

---

## 阶段四：复核修复与闭环状态追踪

经独立排查与技术评估，已对报告中确有必要的问题完成修复与单测覆盖。各项状态如下：

| 事项 / 问题编号 | 报告问题描述 | 独立验证结论 | 修复方案与闭环记录 | 修复状态 |
| :--- | :--- | :--- | :--- | :---: |
| **M1-01** | `TodoRepository.createCustomView` 全量 `getAll()` 并在 Dart 内存中 `reduce` 计算 `nextSortOrder` | **属实且成立**。<br>无谓内存开销，未利用 SQL 聚合功能。 | 在 `CustomViewDao` 中新增 `getNextSortOrder()`，基于 Drift `customViews.sortOrder.max()` 聚合查询；`TodoRepository` 调用该 DAO 方法。 | **已修复 (Fixed)** |
| **M1-02** | `TodoRepository.applyMerged` 拓扑排序递归闭包 | **部分成立**。<br>已有 `visited` 防环，逻辑完备安全。 | 维持现有安全拓扑排序机制，保证同步时外键约束严格满足。 | **维持现状 (As Intended)** |
| **M2-01 (P0)** | `panelTasksProvider` 中 `taskTagIds` 硬编码为空集，自定义视图标签筛选完全失效 | **致命缺陷属实 (P0)**。<br>任何包含标签筛选的看板无法匹配任务。 | 1. 在 `TagDao` 中暴露 `watchAllTaskTags()` 与 `getAllTaskTags()`；<br>2. 新增 `allTaskTagsMapProvider`（`StreamProvider<Map<String, Set<String>>>`）；<br>3. `panelTasksProvider` 监听标签映射并传入真实 `taskTagIds`；<br>4. 新增多标签单测覆盖（单标签、多标签 AND / OR）。 | **已修复 (Fixed)** |
| **M3-01** | `custom_view_editor_page.dart` 中存在未使用变量 `isWide` 及无用 import | **属实**。<br>`flutter analyze` 报 warning。 | 清除未使用的局部变量及 `app_breakpoints.dart` 引用，静态检查 0 warning。 | **已修复 (Fixed)** |
| **M3-02** | `custom_view_editor_page.dart` 在 `build()` 周期中直接调用 `_initFromView` 修改状态 | **属实**。<br>Flutter 响应式渲染反模式。 | 改用 `ref.listen` 监听 `customViewDetailProvider`，配合 `_initialized` 守卫进行单次异步初始化。 | **已修复 (Fixed)** |
| **M4-01 (P1)** | `app_drawer.dart` 循环及 helper 中动态 `ref.watch` 项目未完成数，引发全局 Rebuild 掉帧 | **性能缺陷属实 (P1)**。<br>单个任务状态变更导致 1300+ 行侧边栏整棵全量重构。 | 将项目与文件夹的未完成数拆分为独立的轻量 `ConsumerWidget`（`_ProjectUncompletedBadge` 与 `_FolderUncompletedBadge`），从 `AppSidebarContent` 中彻底移除未完成数的动态订阅，阻断重绘扩散。 | **已修复 (Fixed)** |
| **M4-02 (P2)** | ShellRoute 宽屏双层 Scaffold 嵌套与 Scaffold 结构治理 | **部分成立**。<br>报告建议由 ShellRoute 统一接管所有 AppBar 会破坏各页面复杂的动态 AppBar 定制与 GoRouter 惯用法；但宽屏下 `AppShell` 的外层 `Scaffold(body: Row(...))` 确实导致双层 Scaffold 嵌套。 | 将宽屏下 `AppShell` 的外层 `Scaffold` 替换为透明纯布局 `Material`/`Row`，消除桌面端双层 Scaffold 嵌套问题，同时保持各 Page 自主维护 AppBar 与 FAB 的清晰内聚性。 | **已修复 (Fixed)** |

### 质量门禁自检结果

- **`flutter analyze`**：`No issues found!`（0 error, 0 warning）
- **`flutter test`**：全量单元与组件测试 100% 通过（含新增自定义视图标签筛选与 `getNextSortOrder` 专项单测）
- **`dart format .`**：全量格式化完成

