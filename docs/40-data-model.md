# 40 — 数据模型（Data Model）

> 定义 Drift 表结构、字段、枚举、校验规则、派生状态算法、删除语义与迁移策略。**所有参与同步的表必须带 `id/updatedAt/deleted` 三字段**（`AGENTS.md` §3-3）。

## 1. 实体关系（ER）

```
projects 1 ──── N tasks
tasks    N ──── M tags      （经 task_tags 联表）
tasks    1 ──── N tasks     （parentId 自引用，最多 3 级）
folders  1 ──── N projects  （folderId，可空 = 未分组，62-folder-nav.md）
```

- 项目删除 → 级联删除其下所有任务（含子树）。
- 任务删除 → 级联删除其所有后代。
- 标签删除 → 仅解除引用（task_tags 行删除），任务保留。
- 文件夹删除 → 仅解除收纳（其中项目 folderId 置 NULL 回未分组），项目保留。

## 2. 表结构

### 2.1 projects

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| name | TEXT | NOT NULL, 1–100 字符 | 项目名 |
| color | INTEGER | NOT NULL | ARGB 颜色值 |
| description | TEXT | NOT NULL DEFAULT '' | 描述（可选，纯文本） |
| folderId | TEXT | NULL, FK→folders.id | 所属文件夹；NULL = 未分组（v4 起，62-folder-nav.md §4） |
| sortOrder | INTEGER | NOT NULL | **文件夹组内**排序（v4 起语义：同 folderId 组内排序，NULL 为未分组组） |
| createdAt | INTEGER | NOT NULL | UTC 毫秒 |
| updatedAt | INTEGER | NOT NULL | UTC 毫秒（同步字段） |
| deleted | INTEGER | NOT NULL DEFAULT 0 | 墓碑（同步字段） |

### 2.1a folders（v4 新增）

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| name | TEXT | NOT NULL, 1–50 字符 | 文件夹名 |
| sortOrder | INTEGER | NOT NULL | 文件夹间排序（0..n-1 连续） |
| createdAt | INTEGER | NOT NULL | UTC 毫秒 |
| updatedAt | INTEGER | NOT NULL | UTC 毫秒（同步字段） |
| deleted | INTEGER | NOT NULL DEFAULT 0 | 墓碑（同步字段） |

> 单层结构（不嵌套，D2，`62-folder-nav.md`）。参与同步（快照 v2 起）。

### 2.2 tasks

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| projectId | TEXT | NOT NULL, FK→projects.id | 所属项目 |
| parentId | TEXT | NULL, FK→tasks.id | NULL = 1 级任务 |
| title | TEXT | NOT NULL, 1–200 字符 | 标题 |
| description | TEXT | NOT NULL DEFAULT '' | 描述（纯文本 v1） |
| notes | TEXT | NOT NULL DEFAULT '' | 备注（纯文本 v1） |
| startAt | INTEGER | NULL | 开始时间（UTC 毫秒） |
| endAt | INTEGER | NULL | 截止时间（UTC 毫秒） |
| status | INTEGER | NOT NULL, 0–3 | 状态枚举（见 §3.1） |
| priority | INTEGER | NOT NULL DEFAULT 0, 0–3 | 优先级枚举（见 §3.2，滴答式 4 档：无/低/中/高） |
| sortOrder | INTEGER | NOT NULL | 同级内排序 |
| createdAt | INTEGER | NOT NULL | UTC 毫秒 |
| updatedAt | INTEGER | NOT NULL | UTC 毫秒（同步字段） |
| deleted | INTEGER | NOT NULL DEFAULT 0 | 墓碑（同步字段） |

> 层级**不存 level 字段**，由 parentId 链推导。`tagIds` 不落库于 tasks 表，经联表 `task_tags` 关联；快照层内嵌（见 `60-sync-design.md` §3）。

### 2.3 tags

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | TEXT | PK | UUID v4 |
| name | TEXT | NOT NULL, 1–50 字符, 不区分大小写唯一 | 标签名 |
| color | INTEGER | NOT NULL | ARGB 颜色值 |
| sortOrder | INTEGER | NOT NULL | 标签间排序 |
| createdAt | INTEGER | NOT NULL | UTC 毫秒 |
| updatedAt | INTEGER | NOT NULL | UTC 毫秒（同步字段） |
| deleted | INTEGER | NOT NULL DEFAULT 0 | 墓碑（同步字段） |

### 2.4 task_tags（联表，不参与同步）

| 字段 | 类型 | 约束 |
|---|---|---|
| taskId | TEXT | PK 一部分, FK→tasks.id |
| tagId | TEXT | PK 一部分, FK→tags.id |

> 联表不参与同步：快照中 tagIds 内嵌于 task 记录，合并时整体重建联表（见 `60-sync-design.md` §7）。

### 2.5 settings（设备本地，不参与同步）

| 字段 | 类型 | 约束 |
|---|---|---|
| key | TEXT | PK |
| value | TEXT | NOT NULL |

存储：主题模式（`theme_mode`）、语言（`locale`）、显示/隐藏已完成任务（`hide_completed`）、文件夹展开状态（`folder_expanded_*`）、同步开关、WiFi-only、lastSyncedAt 等**非敏感**偏好（M8 起统一于此，`docs/64-local-preferences.md`；SharedPreferences 已移除）。**同步凭据禁止存这里**（走 `flutter_secure_storage`，见 `60-sync-design.md` §9）。

## 3. 枚举

### 3.1 TaskStatus

| 值 | 名称 | 含义 |
|---|---|---|
| 0 | todo | 待办 |
| 1 | inProgress | 进行中 |
| 2 | done | 已完成 |
| 3 | cancelled | 已取消 |

### 3.2 TaskPriority

| 值 | 名称 | 含义 | 旗帜颜色 |
|---|---|---|---|
| 0 | none | 无优先级 | 无 |
| 1 | low | 低 | 蓝 |
| 2 | medium | 中 | 橙 |
| 3 | high | 高 | 红 |

> 优先级是任务自带属性，与状态（§3.1）正交；有子任务的任务同样可设置优先级（其状态仍由子任务派生，AGENTS.md §3-2）。

## 4. 时间与排序约定

- 所有时间存 **UTC 毫秒整数**（`DateTime.millisecondsSinceEpoch`），仅 UI 层按本地时区格式化（`core/utils/dates.dart`）。
- `startAt`/`endAt` 语义：开始时间 / 截止时间，均可选；同时设置时 `endAt >= startAt`。
- `sortOrder`：同级内从 0 递增；拖拽移动时重排同级（见 §5.3）。
- **文件夹排序（v4 起）**：`folders.sortOrder` 为文件夹间排序（0..n-1 连续）；`projects.sortOrder` 为**文件夹组内**排序（同 folderId 一组，NULL = 未分组组）。展示顺序 = 文件夹按 sortOrder → 各文件夹内项目按 sortOrder → 未分组区项目按 sortOrder（62-folder-nav.md §4.3）。

## 5. 校验规则（写入/移动前强制）

### 5.1 深度校验（FR-TSK-03）

- 定义：根任务（parentId=NULL）深度 = 1；子任务深度 = 父深度 + 1。**最大深度 = 3**。
- 创建子任务：仅当 `depth(parent) < 3` 允许。
- 移动任务：仅当 `depth(target) + subtreeDepth(node) <= 3` 允许（`subtreeDepth` = 节点自身最大后代深度，含自身）。
- 实现：`int depthOf(Task)`、`int subtreeDepthOf(Task)` 纯函数，放 `core/utils/tree.dart`，**必须单测**。

### 5.2 防环校验（FR-TSK-07）

- 移动目标**不得**是节点自身或其任意后代。
- 实现：`bool isDescendantOf(candidate, ancestor)` 纯函数（沿 parentId 链上溯），**必须单测**。

### 5.3 排序一致性

- 同级 `sortOrder` 必须连续（0..n-1）；移动/删除后重排。
- 移动 = 更新 `parentId` + 重排新旧两组的 `sortOrder`，同一事务内完成。

### 5.4 其他

- 标题非空；`endAt >= startAt`；标签名不区分大小写唯一。

## 6. 派生状态算法（FR-TSK-10，定稿）

> **禁止**在 DB 存父任务冗余状态。以下为纯函数，放 `core/utils/derived.dart`，**必须单测**。

### 6.1 状态派生（基于直接子任务，排除 deleted）

```
TaskStatus derivedStatus(Task parent, List<Task> directChildren):
  if directChildren.isEmpty: return parent.status        // 手动
  if all(c.status == done):        return done
  if any(c.status == inProgress):  return inProgress
  if all(c.status == cancelled):   return cancelled
  return todo
```

### 6.2 完成度（基于整棵子树，排除 cancelled 与 deleted）

```
double progress(Task root, List<Task> subtree, {bool includeSelf = true}):
  total = count(t in subtree, t != root 或 includeSelf, 有效状态 != cancelled)
  done  = count(t in subtree, t != root 或 includeSelf, 有效状态 == done)
  return total == 0 ? 0.0 : done / total
```

**includeSelf 双口径（用户定稿 2026-08）**：

- `includeSelf: true`（默认，**项目级总进度**）：`root` 自身计入——项目列表
  卡片进度条（`projectSummaryProvider` / `projectProgressProvider`）中顶层
  任务是真实任务，应参与；
- `includeSelf: false`（**UI 进度环**）：父任务只是容器不参与计算，仅统计
  子树后代——与行尾 x/y 数字进度（只算子任务）口径一致。深度仍为整棵
  子树递归（`taskProgress`），cancelled/deleted 排除规则不变。

### 6.3 UI 约束

- 有子任务的任务：状态控件禁用，显示派生徽标；完成度以进度环 + 百分比展示（55-ui-redesign §5 `progressRing`）。
- 无子任务的任务：状态手动可改。

## 7. 删除语义（FR-PRJ-03 / FR-TSK-09 / FR-TAG-03）

| 操作 | 本地行为 | 同步行为 |
|---|---|---|
| 删除任务 | 硬删该任务 + 级联硬删所有后代（事务） | 每个被删任务在快照中保留墓碑（deleted=true） |
| 删除项目 | 硬删项目 + 级联硬删其下所有任务（含子树） | 同上，逐条墓碑 |
| 删除标签 | 硬删标签 + 删除 task_tags 引用行 | 标签墓碑；合并后 reconciliation 清理悬空 tagIds |
| 删除文件夹（v4） | 硬删文件夹 + 其中项目 `folderId` 置 NULL（回未分组，事务） | 文件夹墓碑；合并后 reconciliation 清理悬空 folderId（`reconcileFolderIds`） |

- 墓碑仅存在于快照，本地 DB 不保留已删行（`40-data-model.md` §7 与 `60-sync-design.md` §6 一致）。
- 墓碑清理：快照压缩时清理 >90 天的墓碑（`60-sync-design.md` §8）。

## 8. 迁移策略

- `schemaVersion` 从 1 开始，每次表结构变更 +1。
- 迁移用 Drift `MigrationStrategy` 的 `onUpgrade` 逐步执行（`m1 → m2 → …`），禁止跳版本。
- 每个迁移步骤必须写**迁移测试**：从旧版本 schema 造数据 → 升级 → 断言数据完整。
- 预留扩展（v1 不实现）：提醒字段（remindAt）、重复规则字段（recurrence）。**新增字段必须带默认值**，保证旧快照可读。
- 改表后：更新本文档字段表 + 写迁移步骤 + 跑 `dart run build_runner build --delete-conflicting-outputs`。

### 已执行迁移

| 版本 | 变更 | 说明 |
|---|---|---|
| 1 | 初始 schema | M1 建全部 5 张表 |
| 2 | `tasks.priority` | 新增优先级列（INTEGER NOT NULL DEFAULT 0），`m.addColumn(tasks, tasks.priority)`；旧行默认 `none` |
| 3 | `projects.description` | 新增描述列（TEXT NOT NULL DEFAULT ''），`m.addColumn(projects, projects.description)`；旧行默认 `''` |
| 4 | `folders` 表 + `projects.folderId` | 新增 folders 表（`m.createTable(folders)`）+ folderId 列（TEXT NULL，`m.addColumn(projects, projects.folderId)`）；旧行默认未分组（62-folder-nav.md §7.1） |

## 9. 数据量假设

- 个人使用，目标规模 <5 万条任务。列表查询用 Drift 流式 + 分页（`limit/offset` 或游标）；快照解析在 isolate 执行（NFR-02）。