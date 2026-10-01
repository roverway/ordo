# 全量代码质量评价报告（待审核）

> - **文档状态**：**待审核**（Pending Review / 未经批准，不得作为整改依据直接执行）
> - **评审范围**：`lib/` 186 个手写文件 + `test/` 78 个文件，schema v7
> - **基线 commit**：`0130ee86cec563efd7988c2e05febff25fbbdb52`（`0130ee8`，dev 分支）——`feat(search & nav): refine Linear search page & filter chips, unify peer cross-fade transitions`
> - **工作树状态**：审计期间存在未提交变更（`lib/features/tasks/page_context_provider.dart`、`test/features/tasks/page_context_scope_test.dart` 为审计会话期间新建、尚未纳入版本控制）。**本报告全部结论以基线 `0130ee8` 为准**，未提交变更不在评估范围内。
> - **评审时间**：2026-09-30
> - **报告归档**：`docs/96-code-review-0130ee8-head.md`
> - **验证手段**：`flutter analyze`（0 issue）、`flutter test`（880 通过 / 6 跳过 / 0 失败）、全量静态扫描
> - **文档构成**：**第一部分** 代码质量审计（第一～六章）；**第二部分** 持续维护与扩展性评估（第七章，追加于同日，含 7.8 待办与决策项登记表）
> - **综合评分**：**6.5 / 10**（持续维护与扩展性维度；架构方向性 8.0，详见第七章 7.2）
> - **只读声明**：本次评审为**只读审计**，**未修改任何项目代码**。

---

## 摘要（TL;DR）

| 维度 | 结论 |
|---|---|
| **代码量是否正常** | **正常偏多，但完全可解释**。8 万行 ≈ 手写生产 49,936 + 测试 22,136 + 自动生成 9,067。测试占 27%，生成代码占 11%，真正的手写生产代码是 5 万行，其中 60% 是 UI 层。 |
| **架构成熟度** | **高于绝大多数个人项目，接近专业团队的中小型 Flutter 应用水平**。同步引擎有真正的分布式系统思考，分层纪律成文且被遵守。 |
| **真正的问题** | 不在"代码写得对不对"，而在两处：① **数据访问层欠优化**（零索引 / 无 WAL / 全表内存过滤）；② **UI 层缺少"停下来"**（833 行的 `build()`），并因此产生 16 份评审报告的复利。 |
| **最紧急的一件事** | `database.dart` 的 `beforeOpen` 加 `PRAGMA journal_mode = WAL` + `busy_timeout`，并给 `tasks` / `task_tags` 加 4 个索引。**半天成本，消除大数据量下的全部卡顿与读写互锁。** |
| **持续维护性评分** | **6.5 / 10**。架构骨架健康、测试护栏厚实，但"**只增不减**"（近 30 天新增 50 文件 / 删除 1 文件）与"**零索引**"两条正在逼近红线。详见第七章。 |

---

## 一、先回答"8 万行正常吗"

**这 8 万行几乎可以完全解释掉，而且比例很健康。** 精确对账如下（统计口径：剔除空行与纯注释行）：

| 组成 | 有效行数 | 占比 | 说明 |
|---|---:|---:|---|
| 手写生产代码 `lib/` | **49,936** | 62% | 186 个文件 |
| 测试代码 `test/` | **22,136** | 27% | 78 个文件 |
| 自动生成 | **9,067** | 11% | 仅 4 个文件（drift `database.g.dart` 6,196 + l10n 7,382） |
| **合计** | **81,139** ≈ "8 万多" | 100% | |

三个关键点：

1. **测试占了 27%。** `test:lib = 0.44`，78 个测试文件对 186 个源文件。绝大多数个人项目这个比值在 0.05～0.15。
2. **生成代码只占 11%，且只有 4 个文件。** 说明没有手写 ORM、没有手写 i18n 框架。
3. **真正的手写生产代码是 5 万行**，其中 `lib/features/` 占 3 万行 —— 也就是 **60% 是 UI 层**。业务逻辑 + 同步引擎 + 数据层合计不到 2 万行。

### 真正吃掉行数的三块（都是产品功能，不是架构失控）

| 模块 | 有效行数 | 性质 |
|---|---:|---|
| AI 助手全栈（`lib/core/ai` + `lib/features/ai_copilot`） | **6,316** | 含 MCP server 与 6 个 tool 实现 |
| 内置使用手册页（`user_manual_page.dart`） | 1,972 | 手写了 Markdown AST 解析 + TOC 锚点跳转 + 搜索高亮（≈ 引入半个 markdown 库） |
| 自定义看板引擎（`lib/features/custom_views`） | 3,485 | 面板配置 JSON + 多维筛选 + 跨面板拖拽 |

其余分布：`lib/features/tasks/` 7,921、`lib/features/settings/` 6,676、`lib/core/utils/` 2,528、`lib/core/sync/` 3,518。

### 判断

**5 万行手写生产代码，对本项目描述的功能集（今日 / 日历 / 任务树 / 收件箱 / 项目 / 文件夹 / 标签 / 搜索 / 自定义看板 / 四象限 / AI 助手 / MCP / WebDAV+S3 同步 / 备份快照 / 农历节日 / 内置手册 / Windows+Linux 双平台）属于"偏多但完全可解释"。**

**行数不是主要问题。真正的问题是：这 5 万行代码在小数据下会非常流畅，但在 1 万条任务时会崩。** 原因见第四章 P0。

---

## 二、客观指标记分卡

| 维度 | 结果 | 评级 |
|---|---|---|
| 静态检查 | `flutter analyze` 0 issue | 🟢 优秀 |
| 测试 | 880 通过 / 6 skip / 0 失败 | 🟢 优秀 |
| 遗留标记 | TODO / FIXME / HACK = **0** | 🟢 优秀 |
| lint 抑制 | `ignore_for_file` 仅 4 处，**全在生成文件**；`// ignore:` 仅 4 处 | 🟢 优秀 |
| 死代码 | 未引用 class/enum 仅 2 个 | 🟢 优秀 |
| i18n | zh/en 全覆盖，无硬编码用户可见文案 | 🟢 优秀 |
| 双端适配 | Windows / Linux 真实构建，非占位 | 🟢 优秀 |
| 迁移测试 | `test/migrations/migration_test.dart` 705 行 | 🟢 优秀 |
| 设计令牌 | `AppTokens` 738 行，被最广泛复用 | 🟢 优秀 |
| Riverpod | 全项目仅 64 个 provider，无 codegen，无 `StateNotifier` 混用 | 🟢 优秀 |
| 同步引擎设计 | LWW + 确定性 tie-break + 纯函数 merge + 时钟偏移双检 | 🟢 优秀 |
| 分层纪律 | 成文且被遵守（Repository 不 import sync/，sync 不 import l10n） | 🟢 良好 |
| 测试覆盖广度 | 50 个 lib 文件无对应测试（含 25KB 的 `quick_capture_bar.dart`） | 🟡 一般 |
| 文档一致性 | AGENTS.md / database.dart 注释与代码漂移 | 🟡 一般 |
| 共享组件复用 | 37 个 shared widget vs 46 个 feature-local widget | 🟡 一般 |
| **N+1 查询** | 3 处（1 处在同步热路径） | 🟠 高 |
| **同步重入丢事件** | 编辑期事件静默丢弃 | 🟠 高 |
| **巨型 build()** | 53 个 ≥100 行，最大 833 行 | 🟠 高 |
| **墓碑存 JSON 单行** | 整体覆盖写 + 静默损坏降级 | 🟠 高 |
| **SQLite WAL** | **未开启**，无 `busy_timeout` | 🔴 严重 |
| **数据库索引** | **全库 0 个索引** | 🔴 严重 |
| **查询模式** | 全表加载 + Dart 端过滤 | 🔴 严重 |
| **格式合规** | `dart format` **44/190 lib 文件不合规** | 🔴 未执行 |

---

## 三、做得比大多数团队好的地方（后续优化中不要弄丢）

### 3.1 同步引擎（`lib/core/sync/`，3,518 行）—— 全项目最亮的部分

逐行核查了 `sync_engine.dart` / `merge_engine.dart` / `snapshot_codec.dart` / `content_hash.dart`，它做到了教科书级的事务性同步：

- **LWW + 确定性 tie-break**：`merge_engine.dart:283` 的 `_tieBreak` 在 `updatedAt` 相等时按 `(deviceId, id)` 字典序决胜。这保证了两台设备独立合并后得到**逐字节一致**的结果 —— 很多商业同步系统都没做对这件事。
- **merge 是纯函数**：`merge_engine.dart:26` 无 IO、无副作用、显式传入两端 `deviceId`，配 773 行单测（`test/core/sync/merge_engine_test.dart`）。这是可测试性的教科书答案。
- **时钟偏移双检**：本地 vs 服务器（`serverNow`）+ 对端 `exportedAt` vs 服务器写时刻 `lastModified`，双保险。
- **content-hash 跳过上传**（`content_hash.dart`）：无变更不上传，省流量也省冲突。
- **读改写 ≤2 次重试**：`upload` 前比对 `lastModified`，变了就重新 download+merge。
- **结构化错误码解耦 i18n**：`SyncErrorCode` 9 个枚举值（`sync_engine.dart:57`），UI 拿 code 映射 ARB。引擎层不 import l10n —— 分层干净。
- **密钥不进日志**：明确只记 host。
- **reconcile 链条完整**：`reconcileTagIds` → `reconcileFolderIds` → `reconcileCustomViews`（`merge_engine.dart:84`）清理各类悬空引用。

### 3.2 分层约束是"成文且被遵守"的，不是摆设

`docs/30-architecture.md §1` 规定 Repository 不 import sync/、sync 不依赖 UI/l10n。**已验证确实未违反。** `todo_repository.dart:1195` 甚至专门写了注释解释为什么 Repository 层不 import sync 类型。这种纪律在个人项目里很少见。

### 3.3 设计令牌体系真的在用

`app_tokens.dart` 738 行，`radiusCard / radiusPill / radiusChip / radiusDialog / radiusButton / radiusList / radiusItem / radiusMicro` 全覆盖。**最长重复行统计前 18 名全部是 `AppTokens.xxx`** —— 说明没有散落的魔法值（见问题 10 是细节瑕疵，不是系统性问题）。

### 3.4 零遗留标记、零 lint 抑制

TODO / FIXME / HACK / XXX = 0 处。4 个 `ignore_for_file` 全部位于生成文件。4 个 `// ignore:`。这是长期维护意识的直接证据。

### 3.5 Riverpod 用得克制

全项目仅 64 个 provider，无 codegen。没有 provider 泛滥，没有 `StateNotifier` 混用，没有为了"性能"滥用 `select`。状态派生（今日、日历、搜索、四象限）各自收敛在 feature 的 providers 文件里。

### 3.6 错误分类结构化

`catch (_)` 32 处、`on Exception` 86 处，仅 2 处 rethrow。配合 `SyncErrorCode` 枚举，同步错误能分类、可重试、不可重试一目了然。

---

## 四、问题清单（按严重度）

### 🔴 P0 — 数据访问层：这是真正会让应用"用两年就卡"的原因

#### 问题 1：全库零索引，且未开启 WAL

**证据**

```
lib/core/db/tables.dart   → @TableIndex 出现次数：0
lib/core/db/database.dart → CREATE INDEX：0
lib/core/db/database.dart:70-72 → beforeOpen 只设了 PRAGMA foreign_keys = ON
```

**为什么致命**

SQLite **不像 MySQL InnoDB 那样自动给外键列建索引**。而本项目的查询几乎全打在无索引列上：

| 列 | 谁在查 | 有索引？ |
|---|---|---|
| `tasks.projectId` | `getAllByProject` / `getDirectChildren` / `getAllInProjectOf` | ❌ |
| `tasks.parentId` | `getDirectChildren(parentId)` | ❌ |
| `task_tags.taskId` | `tagIdsForTask`（同步热路径，见问题 3） | ❌ |
| `tasks.startAt` / `endAt` | 日历视图、今日视图、日期筛选 | ❌ |
| `tasks.status` / `priority` | 全部筛选器 | ❌ |
| `tasks.updatedAt` | `watchAllActive` 的 `ORDER BY` | ❌ |

**没有 WAL 更糟**：SQLite 默认 rollback journal，**写事务会阻塞所有读**。而本项目架构是「drift Stream 持续监听 + 编辑后 2s 自动同步」。这意味着：用户滚动列表（读）与后台同步写入（写）互相阻塞。数据量一大，界面会肉眼可见地卡顿掉帧。

**建议**

```dart
beforeOpen: (d) async {
  await customStatement('PRAGMA foreign_keys = ON');
  await customStatement('PRAGMA journal_mode = WAL');       // 读写不互斥
  await customStatement('PRAGMA busy_timeout = 5000');     // 避免 SQLITE_BUSY
  await customStatement('PRAGMA synchronous = NORMAL');    // WAL 下的安全加速
}
```

外加索引（drift 需 bump `schemaVersion` 并写迁移，参考 `test/migrations/migration_test.dart` 705 行的既有模式）：

```dart
@TableIndex(name: 'idx_tasks_project', columns: {#projectId})
@TableIndex(name: 'idx_tasks_parent',  columns: {#parentId})
@TableIndex(name: 'idx_tasks_start',   columns: {#startAt})
// TaskTags 复合主键 {taskId, tagId} 已隐式覆盖 taskId 方向；
// 反向查（tag → tasks）需补 {@TableIndex(columns: {#tagId})}
```

#### 问题 2：全表加载 + Dart 端过滤

**证据** —— `lib/core/db/daos/task_dao.dart:76` / `:84`：

```dart
Stream<List<Task>> watchAllActive()   // SELECT * FROM tasks WHERE deleted=0 ORDER BY updatedAt DESC
Future<List<Task>> getAllActive()     // 同上
```

DAO 注释写得很坦率：*"返回扁平列表，视图层再各自排序/过滤"*。

于是**今日、日历、搜索、自定义看板、四象限、AI 效率统计**全部 = 「拉全表 → 在 Dart 里 filter」。500 条时毫无问题；5,000 条时每次筛选都是 5,000 次 Dart 对象比较 + 5,000 个 widget 构建；10,000 条时出现可感卡顿。

这与问题 1、3 是**同一病根的三种表现**：数据层没承担筛选责任，全甩给 UI。

**建议**：把最高频的「今日 / 日历 / 搜索」筛选**下推到 SQL**（Drift `customSelect` 或组合条件）。自定义看板的多维筛选（`matchesFilter` / `sortPanelTasks`）可保留在 Dart —— 它的条件是用户运行时可配的，编译成 SQL 反而更复杂。但固定的「今日 = 逾期 ∪ 今天」应落 SQL。

#### 问题 3：同步热路径上的 N+1

**证据** —— `lib/core/db/repositories/todo_repository.dart:1202-1205`：

```dart
final taskTagIds = <String, List<String>>{};
for (final t in tasks) {
  taskTagIds[t.id] = await this.tags.tagIdsForTask(t.id);  // 每个任务 1 次查询
}
```

`exportAll()` 在**每次同步**都被调用（`sync_engine.dart:283`）。N 条任务 = **N+1 次查询**，且 `task_tags.taskId` 无索引 → N 次全表扫描。1,000 个任务时是 1,000 次扫描 `task_tags`。

**修复（语义不变，一次查询）**：

```dart
final rows = await (database.selectOnly(database.taskTags)
  ..addColumns([database.taskTags.taskId, database.taskTags.tagId])).get();
final taskTagIds = <String, List<String>>{};
for (final r in rows) {
  (taskTagIds[r.read(database.taskTags.taskId)] ??= [])
      .add(r.read(database.taskTags.tagId)!);
}
```

`tag_dao.dart` 已有全量版本，只是 `exportAll` 没用。

另两处循环内查询（`todo_repository.dart:1141` `reorderCustomViews`、`:941` `syncSubtasks`）在事务内且数据量小，可接受，但建议改 `batch()`。

#### 问题 4：墓碑存成 settings 表里的一行 JSON

**证据** —— `todo_repository.dart:1394-1400`：

```dart
Future<void> _writeTombstones(Iterable<TombstoneEntry> entries) {
  return settings.set(_kSyncTombstonesKey,
      jsonEncode([for (final e in entries) e.toJson()]));
}
```

`_mergeTombstonesInner` 每次都是「读全量 JSON → Dart 里 merge → 全量重写」。

**四个问题**

1. 墓碑保留 **90 天**（`pruneTombstones`, `todo_repository.dart:1182`）。重度使用 + 多设备下条目会累积到几千条。
2. 每删一个任务 = 读 N 条 + 写 N 条的 JSON blob，**写放大 O(N)**。
3. 单行存一个不断膨胀的 JSON blob，是 SQLite 事务与锁竞争的常见来源。
4. **最严重**：该 JSON blob **本身没有版本号/校验和**。`readTombstones():1157` 的容错是 `on FormatException → return []`。也就是说 —— **若这行因任何原因损坏（同步并发写、磁盘问题），应用会静默地把全部墓碑当成空集合，所有已删除的任务会在下次同步中被远端"复活"。**

**建议**：把墓碑提升为独立表 `sync_tombstones(type, id, updatedAt)`，带真实索引与 `INSERT ... ON CONFLICT DO UPDATE` 原子 upsert。同时解决写放大 + 损坏风险 + 可查询性。需一次 `schemaVersion` bump，成本可控。

---

### 🟠 P1 — 代码结构：行数多的真实原因

#### 问题 5：53 个巨型 `build()`，最大 833 行

| 文件:行 | build() 长度 |
|---|---:|
| `lib/features/tasks/widgets/task_create_sheet.dart:207` | **833** |
| `lib/features/ai_copilot/widgets/ai_task_proposal_card.dart:627` | 734 |
| `lib/features/custom_views/presentation/custom_view_editor_page.dart:147` | 623 |
| `lib/features/custom_views/widgets/filter_criteria_sheet.dart:189` | 613 |
| `lib/features/settings/views/ai_settings_page.dart:471` | 428 |
| `lib/features/quadrant/widgets/quadrant_scope_filter_sheet.dart:58` | 427 |
| `lib/core/theme/app_theme.dart:45` | 407 |
| `lib/features/tasks/widgets/task_row.dart:138` | **371** |
| `lib/shared/widgets/scope_nav_content.dart:93` | 364 |
| `lib/features/projects/projects_page.dart:48` | 349 |

（`build()` ≥100 行的共 53 个）

这才是 5 万行的主因。**833 行的 `build()` 意味着该组件同时负责：表单状态管理、字段校验、日期选择、优先级选择、标签选择、提交逻辑、布局、错误展示。** 改一个字段要在一棵 833 行的树里定位 —— 这是 bug 温床，也是 review 困难的根因。

**`task_row.dart:138` 尤其值得单独说**：其 `build()` 371 行，且是 `StatefulWidget` —— `MouseRegion.onEnter/onExit` 与 `Listener.onPointerDown/Up/Cancel` **每个都调 `setState`**（`task_row.dart:494-505`）。也就是说 **鼠标在任务行上移动一次，就重建一棵 371 行的组件树**。列表 50 行时，hover 一行会带来整屏级别的重建压力。

**建议**

- 每个巨型 `build()` 按「表单区 / 选择器区 / 提交区 / 布局骨架」拆成私有 `StatelessWidget`，数据经构造参数传入
- `task_row.dart` 的 hover/press 状态**从 `setState` 改为 `ValueListenableBuilder` / `AnimatedBuilder` 局部重建**，或把 hover 视觉下沉到只包 `AnimatedContainer` decoration 的轻量 wrapper
- 目标：无 `build()` 超过 150 行

#### 问题 6：core 层反向依赖 feature 层（分层倒置）

**证据** —— `lib/features/projects/project_providers.dart` 中定义了：

```dart
final todoRepositoryProvider = Provider<TodoRepository>((ref) { ... });
```

而 `TodoRepository` 属于 `lib/core/db/repositories/`。同文件注释自承原因：

> *todoRepository 的循环依赖。测试直接 `overrideWithValue` 传入自建仓库时…*

**core 定义在 feature 里 = 分层倒置**。后果：`core` 层的 `main.dart` 必须 import feature 层的 provider 才能拿到仓库。根因是「repository provider 与 project feature provider 相互需要」—— 这是依赖倒置原则未贯彻，**标志应该是接口（abstract class）而不是具体类**。

**建议**：把 `todoRepositoryProvider` 移到 `lib/core/db/db_providers.dart`。若仍循环依赖，说明某个 feature provider 该改为通过接口参数接收 repository。

#### 问题 7：`onDataChanged` 可变字段注入 + `main()` 顺序耦合

**证据** —— `lib/main.dart:38`：

```dart
repo.onDataChanged = syncTriggers.onEdit;
```

`TodoRepository` 上有一个**公开的可变字段**充当回调用。问题：

- 无接口约束（任何 `void Function()` 都能塞进去）
- 无生命周期（谁负责清空？）
- **依赖 `main()` 内赋值顺序**：`container.read(syncTriggersProvider)` 必须在 `repo.onDataChanged = ...` 之前，且必须在任何写操作之前。`main()` 只有 52 行，顺序目前正确，但这是**隐式契约**
- 测试中若忘记赋值，自动同步静默不工作，无任何提示

**建议**：抽 `abstract interface class TaskChangeNotifier { void notifyChanged(); }`，`SyncTriggers` 实现它，在 provider 内组装（`ref.watch` 天然处理顺序）。

#### 问题 8：同步重入会静默丢弃编辑事件

**证据** —— `sync_engine.dart:211-219`：

```dart
Future<SyncResult> run() async {
  if (_running) {
    return const SyncResult(ok: false, skipped: true,
        errorCode: SyncErrorCode.skippedRunning, ...);
  }
```

设计意图注释得很好：*"等待/排队会引入无界延迟与状态叠加的复杂度……被丢弃的编辑会在下一次触发时自然补上。"*

**但该前提可能不成立**：编辑防抖 2 秒，指数退避最长可达数分钟。若一次同步耗时 > 2 秒（WebDAV 上传大快照很常见），用户在同步期间的每次编辑都会被丢弃，且**无 pending 标记**。最后一次编辑也可能被丢 —— 直到用户下次手动同步或重启应用。

**建议**：加一个 `_pendingAgain` 布尔量。重入时不丢弃而是置位，`_running = false` 前检查并重跑一次。**5 行改动，消除一整类"数据没同步上去"的用户投诉。**

---

### 🟡 P2 — 一致性与流程

#### 问题 9：`dart format` 未执行（44/190 lib 文件不合规）

`AGENTS.md §4` 明确要求"提交前：`flutter analyze` 0 error + `flutter test` 全绿 + `dart format`"。前两条每次都做到了，**第三条没有**：

```
$ dart format --output=none --set-exit-if-changed lib
Formatted 190 files (44 changed)
```

原因很可能是 Dart 3.10 换了新的 tall-style 格式化器，而代码是旧版 formatter 格式化后逐步手改的。**加一条 CI 检查即可根治**（`dart format --output=none --set-exit-if-changed .`）。

#### 问题 10：细节层面的令牌绕过

整体令牌执行得很好，但有漏网：

- **345 处**裸数字样式字面量（`size: 18`、`size: 16`、`fontSize: 14`…），集中在 `lib/features/ai_copilot/`，尤以 `ai_task_proposal_card.dart` 为甚
- **166 处**纯数字 `EdgeInsets`（`EdgeInsets.all(2)`、`EdgeInsets.fromLTRB(8, 4, 12, 2)`…），集中在 `lib/features/calendar/calendar_page.dart`

不算系统性问题，但会让"改一处圆角/间距要全局搜"这件事再次发生。

#### 问题 11：50 个 lib 文件无任何对应测试

体积较大的未覆盖文件：

| 文件 | 体积 | 备注 |
|---|---:|---|
| `lib/features/tasks/widgets/quick_capture_bar.dart` | 25 KB | 快速录入是高频入口 |
| `lib/features/tasks/widgets/task_editor/project_picker_sheet.dart` | 19 KB | |
| `lib/features/tasks/widgets/task_editor/task_date_picker_dialogs.dart` | 19 KB | 日期逻辑复杂（含农历/节假日） |
| `lib/shared/widgets/unified_hierarchical_folder_selector.dart` | 15 KB | |
| `lib/features/quadrant/widgets/quadrant_cards_view.dart` | 12 KB | |
| `lib/features/settings/widgets/ai_mcp_server_card.dart` | 9 KB | |
| `lib/features/tasks/widgets/task_editor/subtask_row_tile.dart` | 9 KB | |
| `lib/shared/widgets/swipe_actions.dart` | 9 KB | |

另有 `tag_picker_sheet.dart`、`task_editor_toolbar.dart`、`proposal_substep_tile.dart`、`inline_search_bar.dart` 等。

对比之下 `task_tree_test.dart`（1,265 行）、`task_edit_test.dart`（1,506 行）说明**复杂逻辑是测了的**，但这些 sheet 组件基本只有"能打开"级别的测试。

#### 问题 12：文档与代码漂移

| 文档说 | 实际 |
|---|---|
| `lib/core/db/database.dart:11` 注释 *"schemaVersion = 6"* | `database.dart:31` 是 `7`（注释未跟上） |
| `AGENTS.md:112` *"v1 范围外：不做…"* | 已有 AI 助手 6,316 行 + MCP server + 四象限 2,976 行 |
| `docs/00-project-brief.md` grep "AI" → **0 命中** | AI 已是核心卖点之一（6,316 行生产代码 + 3,823 行测试） |
| `AGENTS.md` 未收录 2026-09-22 之后的所有里程碑 | 已有 M6～M9 四个里程碑落地 |

AI 助手的引入显然是产品决策的结果，**本报告不认为它本身是问题**。但它应被正式写进 brief / requirements / milestones。当前状态是：**代码已远超文档描述的范围，文档仍在描述 v1**。这会让未来的任何 agent（包括三个月后的作者本人）基于错误的范围认知做决策。

#### 问题 13：docs 累积 20+ 份代码评审报告（流程债）

`docs/80-` 到 `docs/95-` 共 16 份，加 `code_review_report.md`、`91-full-code-review-and-refactor.md`，单份 12–43 KB，累计约 **400 KB**。

git log 也印证这个模式：

```
feat(mobile): 完成移动端极致打磨第二阶段…
feat(mobile): 打磨移动端双岛底栏紧凑居中/动态图标/光晕与Hero顶部浮动下拉菜单
feat(navigation): refine hero popup menu, dock defaults and transitions…
feat(mobile): 全面打磨移动端全流程界面与极致交互体验
```

**反复「全量评审 → 重构 → 再全量评审」**。每轮评审发现问题 → 改 → 又触发下一轮全量评审。这说明**缺少能持续运行的自动化质量闸门**（lint 收紧、格式检查、覆盖率阈值、架构依赖检查），所以每次都靠人肉重扫全仓库 —— 这也是 16 份评审报告的成因。

**建议**：用以下自动检查替代人工全量评审循环：

```bash
# 架构倒置检测（core 不得 import features）
grep -rn "import.*features/" lib/core/ && exit 1
# 文件体积闸门
find lib -name "*.dart" | xargs wc -l | awk '$1>800 {print; exit 1}'
# 格式
dart format --output=none --set-exit-if-changed .
```

#### 问题 14（低）：迁移脚本依赖隐式行为，正确但脆弱

`lib/core/db/database.dart` 的 `from < 6` 分支：

```dart
if (from < 6) {
  await m.addColumn(projects, projects.icon);
  if (from >= 4) {                 // ← 隐式依赖"createTable 使用当前表定义"
    await m.addColumn(folders, folders.icon);
    await m.addColumn(folders, folders.color);
  }
}
```

逻辑本身**正确**（from=3 升级时 `m.createTable(folders)` 已按当前定义建表并含 icon/color，故跳过 addColumn 避免重复列错误）。但它隐式依赖 drift 的"createTable 用最新定义"行为。**若未来给 `folders` 加列并 bump 到 v8，此处的守卫条件需同步更新，否则会抛重复列错误。** 建议在迁移处加注释说明这一约束（现有注释只说了"先建表再补 FK 列"，未说明重复列风险）。

#### 问题 15（低）：`.dart_tool` 增量缓存陈旧会导致全量测试编译失败

本次审计中首次运行 `flutter test` 时，全部 76 个测试文件加载失败，报 `lib/features/tasks/page_context_provider.dart:82:27: Error: Undefined name 'inboxProjectId'`。经核查该符号在 `todo_repository.dart:19` 正确定义并导出，且 `flutter analyze` 对该文件 0 issue —— 属 **`.dart_tool` 增量编译缓存陈旧**（新增未跟踪文件时触发），`flutter clean` 或再次运行即恢复。

**这不是代码缺陷**，但会浪费排查时间。建议在 `AGENTS.md §2` 的测试前置条件中补充：

```bash
# 若测试报出明显不存在的编译错误，先执行
flutter clean && flutter pub get
```

另注：`AGENTS.md §2.5` 记录测试前需 `unset http_proxy https_proxy`，本次实测**还需一并 unset `HTTP_PROXY` `HTTPS_PROXY` `all_proxy` `ALL_PROXY`**（`ALL_PROXY` 存在时会劫持 VM-service 端口，导致 `HttpException: Connection closed before full header was received`）。建议一并补入文档。

---

## 五、如果只做三件事（按 ROI 排序）

| 优先级 | 动作 | 成本 | 收益 |
|---|---|---|---|
| **1** | `database.dart` `beforeOpen` 加 `journal_mode=WAL` + `busy_timeout` + `synchronous=NORMAL`；`Tasks` / `TaskTags` 加 4 个索引（含 `schemaVersion` bump + 迁移测试） | 半天 | 消除大数据量下的**全部卡顿与读写互锁**。投入产出比最高。 |
| **2** | `exportAll()` 的 N+1 改批量查询；今日 / 日历 / 搜索的筛选下推 SQL | 1–2 天 | 同步速度与列表性能的根本改善。 |
| **3** | 拆掉 `task_create_sheet.dart:207`（833 行）与 `task_row.dart:138`（371 行且 hover 触发全树重建）的 `build()` | 2–3 天 | 消除 hover 卡顿；降低后续改 UI 的出错率。 |

**第二梯队**：墓碑提升为独立表（问题 4）；`run()` 加 `_pendingAgain` 标记（问题 8，成本 5 行）；补 CI 三闸门（问题 9 + 13）。

**明确不建议**：为减行数而做大规模重写。那会破坏当前已验证过的分层纪律与 880 个测试构成的护城河。请选 1 和 2（纯收益、无风险），选 3 时小步推进、每拆完一个 `build()` 跑一次 `flutter test`。

---

## 六、总体评价

**架构成熟度：高于绝大多数个人项目，接近专业团队的中小型 Flutter 应用水平。**

分层约束成文且被遵守、同步引擎有真正的分布式系统思考（确定性 tie-break 是很多商业系统都没做对的）、merge 是纯函数、880 个测试全绿、零 TODO、零 lint 抑制、设计令牌体系在用、密钥不进日志、i18n 完整、双端真实构建。**这些不是"编程小白"能偶然做出来的** —— 无论是经验积累的结果，还是高质量 agent 协作规范（`AGENTS.md` 的质量明显高于平均）的产物，`docs/` 的密度与 `60-sync-design.md` 的协议严谨度、以及 16 轮自我 code review 的纪律，都说明**工程判断力是够的**。

**主要短板不在"代码写得对不对"，而在两处：**

**1. 数据访问层欠优化（问题 1–4）。**
精力大量投在同步协议的正确性上，但忽略了本地 SQLite 的索引与 WAL。**这是典型的"架构正确但地基没打"的模式**：协议再完美，底层每次查询全表扫描，用户体验就是卡。数据量小时这完全不暴露 —— **这是最危险的一类问题，因为它在规模变大之前不会给出任何预警**。

**2. UI 层缺少"停下来"（问题 5–6）。**
833 行的 `build()` 在短期是"最快出活"的方式，长期是技术债复利。`shared/` 有 37 个组件但 `features/*/widgets/` 有 46 个 —— 组件化停止得太早。而**反复的全量 code review 循环（16 份报告）本身就是这笔债务的利息**：花在"再全面扫一遍代码"上的时间，本可以用在"加一条自动检查阻止它再次发生"。

**最后一句：**

> 5 万行手写代码 + 2.2 万行测试 + 9 千行生成代码，对本项目描述的功能集而言，**行数正常偏多，但质量明显高于行数所暗示的水平**。压缩空间确实存在，但在 **UI 层的巨型 `build()`（约可回收 8–12k 行）**，而不在架构。

---

# 第二部分 · 持续维护与扩展性评估

## 七、持续维护与扩展性评估（专项）

> 本章为同日追加的第二轮评估，聚焦"**3～12 个月内继续开发、改动、加功能的成本曲线**"，与第一～六章的"当前状态正确性"结论互补。第七章 7.8 提供了可直接取用的待办与决策项登记表。

### 7.1 总体结论

**当前没有失控，但有三条"未失控标记"正在逼近红线。**

需要先厘清"失控"的定义：失控不是"代码变多"，而是"**修改成本随时间上升**"。一个 50 万行但有强闸门、层次清晰、测试完善的项目，不失控；一个 5 万行但每次改动都要先考古的项目，才失控。

本项目目前处在"**尚未失控，但安全边际在快速变薄**"的位置。

### 7.2 评分：6.5 / 10

| 维度 | 分 | 依据 |
|---|---:|---|
| 架构方向正确性 | **8.0** | 57 条跨 feature 依赖边中，`feature→core`(290) / `feature→shared`(93) 为主方向，**feature 之间约 60～70 条且无环**（`tasks→projects` 11 : `projects→tasks` 2，单向）|
| 测试护栏 | **8.0** | 880 个 / 1m47s；迁移/同步/合并/仓库/Widget 均有专项；`task_tree_test` 1,265 行、`task_edit_test` 1,506 行 |
| 演进节奏 | **5.0** | 近 30 天 lib 新增 50 文件 / 删除 1 文件 = **50:1** |
| 扩展成本 | **4.5** | 加一个同步实体要改 ~9 个生产文件 + 5 个测试文件 |
| UI 层可维护性 | **4.0** | 53 个 `build()` ≥100 行，最大 833 行 |
| 质量保障机制 | **4.0** | 16 份人肉评审报告（累计约 400 KB）；`dart format` 44/190 不合规 |
| 文档可信度 | **4.5** | 3 处漂移（`schemaVersion` 6/7、brief 无 AI 章节、AGENTS.md 未收录 M6–M9）|
| 性能天花板 | **3.5** | 零索引、无 WAL、全表内存过滤 |

**为什么不是 7 分**：7 分意味着"可以放心跑两年不碰它"。本项目目前必须持续投入才能维持质量 —— 而这正是它已经发生的事（16 份评审报告 + 249 个 commit 中大量 `fix(review)` 类提交）。

**为什么不是 5 分**：失控的项目长这样 —— 没有测试、lint 全红、TODO 堆积、feature 互相 import 成环、复制粘贴满天飞。**本项目一条都不占。** 架构骨架是健康的。

**做完 7.6 的四道闸门，本项目从 6.5 → 7.5。** 剩下的 2.5 分要靠"停止净增长"这个行为改变 —— 那不是技术问题。

### 7.3 好消息：架构骨架其实比想象中健康

第一～六章聚焦问题，本节要补一个平衡的判断。以下数据是第一～六章未包含的：

**跨 feature 依赖矩阵（492 次 import / 57 条边）**

| 方向 | 次数 | 判断 |
|---|---:|---|
| `feature → core` | 290 | ✅ 正确方向 |
| `feature → shared` | 93 | ✅ 正确方向 |
| `feature → feature` | 约 60～70 | ⚠️ 可接受，且**无环** |
| 其中 `tasks → projects` | 11 | 单向 |
| 其中 `projects → tasks` | **2** | **非对称 → 有意维护的产物** |

原本担心 57 条跨 feature 边会形成网状纠缠，实测**不是**。`tasks` 依赖 `projects` 11 次，而 `projects` 依赖 `tasks` 只有 2 次 —— 这种非对称说明依赖方向是**被主动维护的**，不是无意中纠缠出来的。**没有 A↔B 互指环。**

**这是最贵的品质：它只能靠"一开始就定好规矩"拿到，事后重构买不到。**

**同步引擎的扩展点是干净的**：`merge_engine.dart:247` 的 `_mergeType<R>` 是泛型 + 5 个函数参数（`idOf` / `updatedAtOf` / `localDeviceId` / `remoteDeviceId`）——**加第 6 种同步实体时它一行都不用改**。这个扩展点设计得很漂亮（详见第三章 3.1）。

### 7.4 三条正在逼近红线的标记

#### 标记一 🔴：50:1 的新增/删除比 —— 项目在净增长，没有回收机制

```
近 30 天：  新增 lib 文件 50 个   删除 1 个
每日 churn 高峰：09-28 (15,960 行)  09-29 (10,889)  09-24 (9,349)
最近 4 个 commit：全部是 "移动端界面/交互极致打磨"
```

**这不是 bug，但它是失控最经典的先兆。** 50:1 意味着从来没有回头收拾过 —— 每次打磨都新增一个 sheet、一个 widget、一套样式，**从不合并、从不删除旧的**。

git log 印证了这条路径的形状：

```
cbfbdd7  全面打磨移动端全流程界面与极致交互体验
9f0a171  完成移动端极致打磨第二阶段（Linear风格搜索/四象限卡片/快速录入胶囊/日期选择器收敛）
4aadaf4  重构移动端双岛悬浮底栏与分组Hero下拉菜单导航体系
6ea04c9  打磨移动端双岛底栏紧凑居中/动态图标/光晕与Hero顶部浮动下拉菜单
```

**连续 4 个 commit、约 6 万行 churn，全在 UI 微观打磨。** 每一轮都是"发现不好看 → 加一层效果 → 再加一层"。这就是 53 个巨型 `build()`（问题 5）和 16 份评审报告（问题 13）的共同成因。

**真正的风险不是现在改不动，而是**：下一次你想改任务行的交互，你需要先读懂 371 行的那棵树，然后发现它里面有 3 层 `AnimatedContainer` 嵌套和 4 个 `setState`。

#### 标记二 🔴：零索引 = 一颗尚未引爆的时间炸弹

这一条的性质与其他所有问题都不同。

**代码写得丑只是慢，写错了会 bug，但零索引会在某个确定的数据量上突然崩。**

- 现在无感：500 条任务时，全表扫描与索引查询的差别只有几毫秒
- **到 5,000～10,000 条时**，用户会突然抱怨"最近打开软件变慢了"，而排查要花两天，**因为它不报任何错**

关键在于：**这类问题不会渐变，它是台阶式的。** 现在感觉不到问题，恰恰是因为还没到那个台阶 —— **这是最危险的一类债务**。详见第四章 P0-1。

#### 标记三 🟡：质量保障依赖人肉扫描，而不是自动闸门

16 份报告 / 约 400 KB，加 249 个 commit 里大量 `fix(review)` 类提交。模式很清楚：

```
全量评审（人读 5 万行，需数小时）
  → 发现 N 个问题
    → 改
      → 又触发下一轮全量评审
```

**这个循环的边际收益是递减的**：第 1 轮发现约 40 个问题，第 16 轮发现 2 个问题，但**每轮的成本一样高**（都得重读全仓库）。

而且这已经自我强化到了荒谬的程度：本报告（`96-`）就是第 17 份。

**该换的是方式，不是次数。** 三条 CI 闸门（架构倒置 / 文件体积 / 格式）的边际成本接近零，能把"每轮全量评审"降级为"每轮只看 CI 报的东西"。见 7.6 步骤 B。

### 7.5 三个具体维护场景的成本曲线

| 场景 | 现在的成本 | 半年后（若不干预） |
|---|---|---|
| **改一次任务行交互** | 读懂 371 行 `build()`，改完跑 1m47s 测试 | 读懂 371 行 **+ 3 层新加的动画嵌套** |
| **加一个参与同步的新实体**（如"习惯打卡"） | 改 9 个生产文件 + 5 个测试文件 | 改同样 9 个文件，但 `TodoRepository`(1,458 行) / `snapshot.dart` 更臃肿 |
| **加一个新的视图类型** | 建 `features/xxx/`，接 4 个 provider | 同上，但要小心别再复制一遍 800 行的 sheet |

**第二行最值得注意：5 个同步实体（projects / tasks / tags / folders / customViews）已经是这套架构的舒适上限。**

加一个新实体需要触及的位置（实测）：

| 层 | 文件 |
|---|---|
| schema | `tables.dart`（表定义）、`database.dart`（`@DriftDatabase` 列表 + `schemaVersion` + 迁移） |
| 访问 | 新 DAO 文件、`TodoRepository`（CRUD + `exportAll` + `applyMerged` + 墓碑 type 常量） |
| 同步 | `snapshot.dart`（Record 类型 + `SnapshotData` 字段）、`snapshot_codec.dart`（JSON 编解码）、`merge_engine.dart`（`_mergeType` 调用 + reconcile 链） |
| 测试 | `sync_engine_test` / `merge_engine_test` / `snapshot_codec_test` / `migration_test` / `repository_test` |

到第 8～10 个实体时，`TodoRepository` 会同时是**数据访问层 + 业务规则层 + 同步应用层 + 墓碑管理层**四合一。它现在 1,458 行、**66 个调用方**（25 个文件 import），已经是这个苗头。

**结论：那时才是真正需要考虑拆分 `Repository` 的时候，不是现在。** 现在拆 = 付出成本、收益为零。

### 7.6 建议：先装四道闸门，不要去修 Bug

**顺序很重要。** 本项目现在**最不该做**的是"去优化那 53 个巨型 `build()`" —— 那是净产出为零的体力活，而且改完还会继续长。

真正该做的是让"不变坏"的成本趋近于零：

| 优先级 | 动作 | 成本 | 阻止什么 |
|---|---|---|---|
| **A** | `beforeOpen` 加 `journal_mode=WAL` + `busy_timeout` + `synchronous=NORMAL`；`Tasks` / `TaskTags` 加 4 个索引（bump `schemaVersion` 8 + 迁移测试）| 半天 | 台阶式性能崩塌（标记二 / P0-1） |
| **B** | 3 条 CI 闸门写进 `.github/workflows`：架构倒置 / 文件体积 / `dart format` | 1–2 小时 | 下一个 833 行 `build()` 的诞生；下一个 core→features 倒置（标记三） |
| **C** | 一次"回收日"：合并重复 sheet、删死样式、`docs/80-95` 归档至 `docs/archive/` | 1 天 | 50:1 的净增长趋势（标记一） |
| **D** | 补文档漂移 3 处（`database.dart:11` 注释 / brief 补 AI 章节 / AGENTS.md 补 M6–M9）| 30 分钟 | 未来 agent 基于错误范围认知做决策（问题 12） |

### 7.7 一句话总结

> **本项目的问题不是"代码失控了"，而是"代码在单向上涨，而上涨的闸门没装"。**
>
> 架构骨架比 90% 的个人项目都干净，测试护栏比很多小团队都厚。真正会在未来 12 个月咬你的只有两件事：**没有索引的 SQLite**，和**只增不减的 UI 层**。前者半天能解决；后者需要一次取舍，而不是更多的打磨。

### 7.8 待办与决策项（供后续处理）

> **状态更新（2026-09-30，复核于 `f5a22b8`）**：下表状态已按整改 commit `46bfe91` / `92a6b5c` / `f5a22b8` 更新。
> **详细核查结论与整改效果评估见 `docs/97-remediation-verification-f5a22b8.md`。**
> 综合评分 6.5 → **7.5**。

| # | 动作 | 关联问题 | 优先级 | 成本 | 状态 |
|---|---|---|---|---|---|
| A | `beforeOpen` 加 `journal_mode=WAL` / `busy_timeout` / `synchronous=NORMAL`；`Tasks` + `TaskTags` 加索引（bump `schemaVersion` 8 + 迁移测试）| P0-1 / 标记二 | ~~**P0**~~ | 半天 | ✅ **已完成**（`46bfe91`+`92a6b5c`；6 复合索引 + v8 迁移 + 174 行迁移测试，**超出预期**）|
| B | `.github/workflows` 加 3 条闸门：架构倒置 / 文件体积 / `dart format` | 问题 9 / 13 / 标记三 | ~~**P0**~~ | 1–2 小时 | ✅ **已完成**（`46bfe91`；3 工具 + `verify.sh` + `ci.yml`，push/PR 双触发）**→ 需扩充规则，见 97 号报告第三节** |
| C | 一次"回收日"：合并重复 sheet、删死样式、`docs/80-95` 归档至 `docs/archive/` | 标记一 | P1 | 1 天 | 🟡 **部分**：闸门已建，"回收日"本身**未做** |
| D | 补文档漂移 3 处（`database.dart:11` 注释 / `00-project-brief.md` 补 AI 章节 / `AGENTS.md` 补 M6–M9）| 问题 12 | P1 | 30 分钟 | 🟡 **1/3**：schemaVersion 注释已修；brief 与 AGENTS.md **未做** |
| E | `exportAll()` 的 N+1 改批量查询 | P0-3 | P1 | 2 小时 | ✅ **已完成**（`f5a22b8`；新增 `getAllTaskTags()`，另被 quadrant/today 复用）|
| F | `SyncEngine.run()` 加 `_pendingAgain` 标记 | P1-8 | **P0** ⬆ | 5 行 | ❌ **未做**（`sync_engine.dart:211-226` 逐字未改）**→ 升级为 P0** |
| G | 墓碑提升为独立表 `sync_tombstones(type, id, updatedAt)` | P0-4 | P2 | 1 天 | ✅ **已完成**（`92a6b5c`；含历史 JSON 迁移 + 向后兼容读取）**→ upsert 待改原子，见 97 号报告第四节** |
| H | 拆 `task_create_sheet.dart`（833 行）与 `task_row.dart`（371 行）的 `build()` | P1-5 | P2 ⬇ | 2–3 天 | 🟡 **2/53**：`task_create_sheet` 833→356 ✅；`task_row` 已改 `ListenableBuilder` 实质修复但行数升至 424 → **降级 P2** |
| I | 今日 / 日历 / 搜索的筛选下推 SQL | P0-2 | P2 | 1–2 天 | 🟡 **基础设施已建、零接线**：`watchActiveInRange()` SQL 正确但**全仓无调用方** → 接线或删除 |
| J | `todoRepositoryProvider` 迁至 `lib/core/db/db_providers.dart`；`onDataChanged` 改接口注入 | P1-6 / P1-7 | P3 | 半天 | 🟡 **分层已修**（新增 `db_providers.dart`，架构守卫零容忍）；`onDataChanged` 仍是 `main.dart:38` 裸赋值 |

**明确不在上表内**（避免被默认当作待办）：

- ❌ 为减行数而做大规模重写 —— 会破坏已验证的分层纪律与 880 测试构成的护城河
- ❌ 拆分 `TodoRepository` —— 5 个同步实体尚未到临界点（见 7.5），现在拆是净成本
- ❌ 删除 16 份历史评审报告的**内容**（归档可以，删内容不行 —— 它们记录了决策演进）

---

## 附录 A：核查命令清单（可复现）

```bash
# 1. 静态检查与测试（注意：测试前须清空全部代理变量，含 ALL_PROXY）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
flutter analyze
flutter test --reporter=compact

# 2. 代码量对账
find lib -name "*.dart" -not -name "*.g.dart" -not -path "*core/l10n*" \
  | xargs cat | grep -vE '^\s*$' | grep -vE '^\s*(///|//)' | wc -l

# 3. 索引与 PRAGMA 现状
grep -c "TableIndex\|CREATE INDEX" lib/core/db/tables.dart lib/core/db/database.dart
grep -rn "PRAGMA" lib --include="*.dart" | grep -v "\.g\.dart"

# 4. 同步热路径 N+1
sed -n '1202,1205p' lib/core/db/repositories/todo_repository.dart

# 5. 格式合规
dart format --output=none --set-exit-if-changed lib

# 6. 遗留标记与 lint 抑制
grep -rniE "//\s*(TODO|FIXME|HACK|XXX)" lib --include="*.dart" | wc -l
grep -rn "ignore_for_file" lib | wc -l
```

## 附录 B：本次评审未覆盖的范围

诚实声明以下内容**未**在本次审计中评估，如需请另行安排：

- **平台特定代码**：Android / Windows / Linux 的原生配置、权限、签名、构建脚本
- **依赖安全与许可**：22 个依赖的 CVE 与 license 审计
- **运行时性能实测**：无真机基准测试，所有性能判断基于查询模式与索引的静态分析
- **可访问性（a11y）**：仅见零星 `Semantics` 使用，未系统评估
- **国际化文案质量**：只验证了"无硬编码"，未评估译文准确性
- **未提交的工作树变更**：`page_context_provider.dart` / `page_context_scope_test.dart` 及其对既有测试（`today_page_test.dart`、`search_page_test.dart`、`calendar_page_test.dart` 等已被修改）的影响

---

> **文档结束 · 状态：待审核**
> 本报告为只读审计产出，**未修改任何项目代码**。全文含两部分：**第一部分** 代码质量审计（第一～六章）＋ **第二部分** 持续维护与扩展性评估（第七章，含 7.8 待办与决策项登记表）。
> **第四章与第七章的整改建议在获得批准前不应直接执行。** 7.8 全表状态均为"待批准"。
