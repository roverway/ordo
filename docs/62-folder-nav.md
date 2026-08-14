# 62 — 侧边栏文件夹功能（定稿）

> 状态：**定稿（决策已确认 2026-08-14）**
> 相关文档：`40-data-model.md` / `60-sync-design.md` / `50-ui-ux.md` / `10-requirements.md` / `70-milestones.md`

## 1. 背景与目标

当前侧边栏抽屉（`AppDrawer`）的项目组是**平铺列表**（颜色圆点 + 项目名 + 未完成数）。
目标：允许用户用**文件夹**收纳项目，实现：

1. 文件夹收纳项目清单（项目可以挂到某个文件夹下）。
2. 文件夹可**展开/折叠**（树状显示其内部项目）。
3. **拖拽项目**调整所属文件夹（入夹/出夹/组内排序）。
4. **拖拽文件夹**调整文件夹之间的显示顺序。

## 2. 现状

### 2.1 UI（`lib/shared/widgets/app_drawer.dart`）
- 项目组：`projectsStreamProvider` 平铺 `_DrawerTile`（排除内置收件箱 `inboxProjectId`）。
- 项目行：10px 色点 + 名称 + 未完成数；整行点击跳 `/projects/{id}`。
- 底部：「新建项目」+ 设置入口。
- 宽屏（≥600dp）NavigationRail 不列项目，项目经 `/projects` 页（`ProjectsPage`）访问。

### 2.2 数据模型（`lib/core/db/tables.dart`）
- `Projects` 表：id / name / color / description / **sortOrder（全局）** / createdAt / updatedAt / deleted。
- 无 `folderId` 列；无 `folders` 表。
- `schemaVersion = 3`（v2: tasks.priority，v3: projects.description）。

### 2.3 同步（`lib/core/sync/`）
- 快照 `schemaVersion = 1`（`kSnapshotSchemaVersion`），含 projects / tasks / tags。
- `MergeEngine.merge` 对三种类型做 LWW 合并 + `reconcileTagIds`。
- 墓碑类型：project / task / tag（`_kTombstoneTypeXxx`）。
- `SyncEngine` 走 `exportAll`（Repository）→ `SnapshotData` → `merge` → 应用。

### 2.4 拖拽先例（`lib/features/tasks/widgets/task_tree.dart`）
- `LongPressDraggable` 包整行 + `DragTarget` 命中整行；`moveTask` 事务内重排。
- **最新实现要点**（`684c35f` / `0b072e8`）：索引表在 build 层算一次（`childrenIndexAll`/`byIdAll`），
  落点 `newIndex` 按**全量 DB 集合**计数（隐藏的 done 兄弟仍占位）。

## 3. 决策（已确认）

| 决策 | 选择 | 说明 |
|---|---|---|
| **D1 同步范围** | **参与同步** | 新增 `folders` 表（带 id/updatedAt/deleted 三字段）+ `projects.folderId` 列；快照 schemaVersion 1→2；MergeEngine 加类型 + `reconcileFolderIds` |
| **D2 文件夹层级** | **单层** | 文件夹直接装项目，不嵌套。展开/折叠 = 显示/隐藏内部项目 |
| **D3 删除语义** | **仅解除收纳** | 删文件夹 = 其内项目 `folderId` 置 NULL（回未分组），不级联删项目；与标签删除语义一致 |
| **D4 未分组位置** | **文件夹之后「未分组」区** | 抽屉项目区 = 文件夹组（各含项目）+ 底部未分组区；收件箱排除逻辑不变 |
| **D5 宽屏一致性** | **/projects 页同步分组** | `ProjectsPage` 按文件夹分组 + 未分组区展示（不做拖拽） |
| **D6 折叠状态** | 设备本地持久化 | settings 表 `folder_expanded_<id>`，不同步 |
| **D7 新建项目默认归属** | 未分组 | 创建后拖拽入夹；不做建时选择文件夹 |
| **D8 计数语义** | 恒为真实值 | 文件夹行汇总未完成数按真实全量计算，与任务树「计数/进度恒为真实值」一致（`fa53b65` 先例） |

## 4. 数据模型

### 4.1 新增 `folders` 表（`lib/core/db/tables.dart`）

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| name | TEXT | NOT NULL, 1–50 字符 | 文件夹名 |
| sortOrder | INTEGER | NOT NULL | 文件夹间排序（0..n-1 连续） |
| createdAt | INTEGER | NOT NULL | UTC 毫秒 |
| updatedAt | INTEGER | NOT NULL | UTC 毫秒（同步字段） |
| deleted | INTEGER | NOT NULL DEFAULT 0 | 墓碑（同步字段） |

### 4.2 `projects` 表新增列

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| folderId | TEXT | NULL, FK→folders.id | 所属文件夹；NULL = 未分组 |

### 4.3 排序语义变更（关键）

- `folders.sortOrder`：文件夹之间排序（0..n-1 连续）。
- `projects.sortOrder`：**由全局改为「文件夹内排序」**（未分组 = 一个隐式组，folderId NULL）。
- 抽屉/项目页展示顺序：文件夹按 sortOrder → 各文件夹内项目按 sortOrder → 未分组区项目按 sortOrder。
- 移动/删除后重排所在组（仿 `moveTask` §5.3：同一事务内更新 + 重排新旧两组）。
- **消费方审计**：`ProjectDao.watchAll/getAll`（排序查询）、`TaskProjectSwitcher`（任务编辑器项目切换）、
  `/projects` 页、抽屉。`projectsStreamProvider` 仍返回全量项目，分组在 UI/Provider 层做。

## 5. 同步设计（快照 v2）

### 5.1 快照格式变更（`snapshot.dart` / `snapshot_codec.dart`）

- `kSnapshotSchemaVersion` 1 → 2。
- `SnapshotData` 新增 `folders: List<FolderRecord>`。
- `ProjectRecord` 新增 `folderId`（String?，崩溃安全：缺失/非字符串 → null）。
- 新增 `FolderRecord`：id / name / sortOrder / createdAt / updatedAt / deleted（fromJson/toJson 崩溃安全，仿 ProjectRecord）。
- `businessToJson()` 同步加入 folders（上传 hash 优化覆盖新字段）。

### 5.2 合并引擎（`merge_engine.dart`）

- `merge()` 类型循环加入 `folders`（`_mergeType` 通用，无需新逻辑）。
- 新增纯函数 **`reconcileFolderIds(SnapshotData)`**：project.folderId 指向「不存在或 deleted=true」的
  文件夹 → 置 null（等价 `reconcileTagIds` 语义，防悬空 FK）。**必须单测**。
- 结果快照携带 folders（merge 后统一 reconcile）。

### 5.3 墓碑

- 新增类型 `'folder'`（`_kTombstoneTypeFolder`）。
- `deleteFolder` 写文件夹墓碑；同步后他端经 merge + reconcile 自动清理项目引用。

### 5.4 SyncEngine

- `Repository.exportAll()` 增加 folders；`SyncEngine` 组装 SnapshotData 时带入。
- 合并结果应用：folders 行 upsert/硬删；projects 行 upsert（含 folderId）。
- **禁止改动** `8db0045` 加固的 B 检时钟偏差逻辑（`test/core/sync/` 有回归测试守护）。

### 5.5 双端影响（文档明示）

- 快照升 v2 后，**旧版本应用读 v2 快照 → 拒绝同步并提示升级**（FR-SYNC-03 设计行为）。
- 多端需同步升级。

## 6. UI 规格

### 6.1 抽屉项目区（`app_drawer.dart`）

- 结构：`系统组 | Divider | 文件夹组（各含项目行）| 未分组区 | 新建文件夹+新建项目底部`。
- 文件夹行：`[展开/折叠箭头] [文件夹图标] 名称 [汇总未完成数]`；点击箭头或整行（当前项除外）切换展开。
- 项目行：保留色点 + 名称 + 未完成数；缩进到所属文件夹下（缩进令牌）。
- 未分组区：小标题「未分组」+ 平铺项目行（收件箱仍排除）。
- 展开状态：settings `folder_expanded_<id>`（D6）。

### 6.2 拖拽（复用 task_tree 最新模式，`LongPressDraggable` + `DragTarget`）

- **项目行**长按拖拽：
  - 拖到某文件夹行 → `moveProjectToFolder(projectId, folderId: X, newIndex: 末尾)`（入夹）；
  - 拖到未分组区 → `moveProjectToFolder(projectId, folderId: null, newIndex: 末尾)`（出夹）；
  - 拖到同组另一项目行 → 组内重排（`newIndex` 按**全量集合**计数，与 `task_tree` 最新语义一致）；
  - 折叠文件夹拖入行为：**自动展开**（更友好，实现简单）。
- **文件夹行**长按拖拽 → `moveFolder(folderId, newIndex)`（仅文件夹间排序）。
- 点击 vs 长按：`LongPressDraggable` 天然区分（长按起拖），点击跳转不受影响。
- 抽屉内滚动 + 拖拽：任务树已有成功先例，直接复用模式。

### 6.3 入口与菜单

- 抽屉底部新增「新建文件夹」入口（与「新建项目」并列，复用 `showProjectFormDialog` 同款弹窗或简版名称弹窗）。
- 文件夹长按/行尾菜单：重命名、删除；删除确认框文案明示「其中的项目将回到未分组」（D3）。

### 6.4 /projects 页（D5）

- `ProjectsPage` 列表改为：文件夹分组头 + 项目卡片 + 未分组区（不做拖拽，仅展示分组）。
- 空态（无文件夹且无项目）保持「暂无项目」。

### 6.5 令牌与 l10n

- 新设计令牌：文件夹行缩进（如 `folderIndent`）、（如需要）文件夹行图标尺寸。
- ARB（zh/en）新增：文件夹/未分组/新建文件夹/重命名文件夹/删除文件夹/删除文件夹确认/折叠等。

## 7. 实施范围（按车道）

### 7.1 数据层（车道 B）

- `tables.dart`：新增 `Folders` 表 + `Projects.folderId` 列（FK→folders.id）。
- `database.dart`：`schemaVersion` 3→4；onUpgrade `if (from < 4)` 建表 + `addColumn(projects.folderId)`。
- 跑 `build_runner build --delete-conflicting-outputs`。
- 新增 `FolderDao`（仿 ProjectDao：watchAll/getAll/getById/insert/updateById/deleteById，按 sortOrder 排序）。
- `todo_repository.dart`：
  - `createFolder(name)`（校验 1–50 字符，sortOrder = 当前文件夹数）；
  - `renameFolder(id, name)`；
  - `deleteFolder(id)`（事务：项目 folderId 置 NULL + 重排未分组组 sortOrder + 文件夹墓碑）；
  - `moveProjectToFolder(projectId, {String? folderId, required int newIndex})`（事务：更新 folderId + 重排新旧两组 sortOrder，仿 `moveTask`）；
  - `moveFolder(folderId, newIndex)`（重排文件夹）；
  - `exportAll()` 增加 folders；墓碑类型加 `'folder'`。
- `migration_test.dart`：v3→v4 迁移测试（旧 schema 造数据 → 升级 → 断言 folders 表存在、folderId 列默认 NULL、数据完整）。
- Repository 集成测试（内存 DB）：文件夹 CRUD、移动/重排、删除解收纳、级联一致性、排序连续性。

### 7.2 同步层（车道 C）

- `snapshot.dart`：`FolderRecord` + `SnapshotData.folders` + `ProjectRecord.folderId` + businessToJson。
- `snapshot_codec.dart`：`kSnapshotSchemaVersion` → 2。
- `merge_engine.dart`：merge 加 folders；新增 `reconcileFolderIds` 纯函数。
- `sync_engine.dart`：export 带 folders；应用合并结果处理 folders + projects.folderId。
- 测试：`snapshot_codec_test.dart`（v2 编解码 + v1 兼容读）、`merge_engine_test.dart`
  （文件夹 LWW + reconcileFolderIds 悬空清理）、同步集成测试（文件夹增删改/跨端移动/删除后归属修复）。

### 7.3 UI 层（车道 D）

- `app_drawer.dart`：项目区改造（文件夹组 + 未分组区 + 新建文件夹入口 + 拖拽）。
- 新建/重命名文件夹弹窗（复用项目表单同款视觉，字段仅名称）。
- 删除文件夹确认框。
- `projects_page.dart`：按文件夹分组 + 未分组区。
- 新 Provider：`foldersStreamProvider`、`projectsByFolderProvider`（分组聚合）、`folderExpandedProvider`（settings 持久化）。
- l10n（ARB zh/en）+ 新令牌。
- Widget 测试：抽屉折叠/拖拽/分组、项目页分组。

## 8. 影响面

| 文件 | 变更 |
|---|---|
| `lib/core/db/tables.dart` | +Folders 表；+Projects.folderId |
| `lib/core/db/database.dart` | schemaVersion 4 + 迁移 |
| `lib/core/db/database.g.dart` | build_runner 重新生成 |
| `lib/core/db/daos/folder_dao.dart` | 新增 |
| `lib/core/db/daos/project_dao.dart` | 排序查询语义确认/微调 |
| `lib/core/db/repositories/todo_repository.dart` | +文件夹 CRUD/移动/墓碑；exportAll |
| `lib/core/sync/snapshot.dart` / `snapshot_codec.dart` / `merge_engine.dart` / `sync_engine.dart` | 快照 v2 |
| `lib/shared/widgets/app_drawer.dart` | 项目区改造 + 拖拽 |
| `lib/features/projects/projects_page.dart` | 分组展示 |
| `lib/features/tasks/task_list_page.dart`（TaskProjectSwitcher） | sortOrder 语义审计 |
| ARB / 令牌 / 测试 | 随各层 |

## 9. 验收标准（DoD）

- [ ] 抽屉项目区：文件夹展开/折叠正常；项目入夹/出夹/组内排序正确；未分组区位置正确。
- [ ] 文件夹拖拽排序正确；点击 vs 长按无冲突。
- [ ] 删除文件夹 → 项目回未分组（确认框明示），不删项目。
- [ ] 排序连续性：任一移动/删除后组内 sortOrder 0..n-1 连续。
- [ ] 同步：文件夹增删改/移动跨端正确；文件夹删除后他端项目归属修复；v1 快照可兼容读。
- [ ] 计数恒为真实值（不受会话级过滤影响）。
- [ ] 宽屏 /projects 页分组展示一致。
- [ ] `flutter analyze` 0 error；`flutter test` 全绿；`dart format` 通过。
- [ ] 文档同步：40-data-model（folders 表 + folderId + 迁移 v4 + 排序语义）、60-sync-design（快照 v2）、
      50-ui-ux（§4 抽屉）、10-requirements（FR-NAV-01 + 新 FR-FLD-xx）、70-milestones（M6）。

## 10. 里程碑

新增 **M6 — 文件夹导航**（DoD 见 §9）。M5 打磨批与 M6 分离，保持提交粒度清晰（`feat:` 前缀）。
