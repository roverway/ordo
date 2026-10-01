# 整改核查报告：docs/96 的 10 项建议逐项复核

> - **文档状态**：**已核查 · 待整改方确认**
> - **文档定位**：对 `docs/96-code-review-0130ee8-head.md`（基线 `0130ee8`）所列整改建议的**第三方复核**，逐项判定"是否已整改 / 整改效果如何"
> - **核查对象**：整改 commit `46bfe91`、`92a6b5c`、`f5a22b8`（分支 `refactor/quality-and-maintenance-plan`）
> - **核查区间**：`0130ee8` → `f5a22b8`（4 个 commit，另有前置 `e77e257`）
> - **核查人**：只读审计（未修改任何项目代码）
> - **核查时间**：2026-09-30
> - **报告归档**：`docs/97-remediation-verification-f5a22b8.md`

### 我的独立验证手段（不采信 commit message 的自述）

| 验证项 | 结果 |
|---|---|
| `flutter analyze` | **No issues found**（16.8s） |
| `flutter test` | **891 通过 / 6 skip / 0 失败**（基线 880，**+11**） |
| `dart format --set-exit-if-changed lib` | **194 files (0 changed)**（基线 190 files / 44 changed） |
| 索引名一致性（`tables.dart` 注解 vs `database.dart` 手写迁移） | `diff` 结果 **✅ 完全一致** |
| 死代码扫描（全仓 grep 调用方） | 发现 1 处新增死代码（见第四节） |

> ⚠️ **验证提醒**：本机 `flutter test` 需先 `unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY`（`ALL_PROXY` 存在时会劫持 VM-service 端口）。详见 `docs/96` 问题 15。

---

## 摘要

**10 项建议中：6 项完成、2 项部分完成、2 项未动。没有一项整改引入回归。综合评分 6.5 → 7.5。**

| 分类 | 项数 | 项目 |
|---|---:|---|
| ✅ 已整改且效果良好 | **6** | A（WAL+索引）、B（CI 闸门）、C（format）、E（N+1）、G（墓碑独立表）、J（分层倒置·半数） |
| 🟡 部分整改 | **2** | H（巨型 build，2/53）、I（筛选下推，零接线） |
| ❌ 未整改 | **2** | F（`_pendingAgain`）、`onDataChanged` 接口化 |
| ⚠️ 整改引入的新问题 | **2** | 死代码 `watchActiveInRange`、墓碑 upsert 非原子 |

**最关键的改善不是分数，是风险结构**：

- **性能天花板 3.5 → 6.0** —— 第四章 P0-1 那颗"尚未引爆的时间炸弹"**已拆除**
- **质量保障机制 4.0 → 7.5** —— **16 份人肉评审报告的循环可以终止**，下次需要质量扫描时跑 `bash tool/verify.sh` 即可

---

## 一、已整改且效果良好（6 项）

### ✅ A（P0-1 / 标记二）WAL + 索引 —— 完美，且超出预期

| 项 | 基线 `0130ee8` | 现在 `f5a22b8` |
|---|---|---|
| `journal_mode = WAL` | ❌ | ✅ `database.dart:146` |
| `busy_timeout = 5000` | ❌ | ✅ `database.dart:147` |
| `synchronous = NORMAL` | ❌ | ✅ `database.dart:148` |
| 索引总数 | **0** | **6** |

**索引设计比原建议更优。** 原建议提的是单列索引（`{#projectId}` 等），实际实现为**复合索引且把 `deleted` 放首位**：

```dart
// lib/core/db/tables.dart:126-140
@TableIndex(name: 'idx_tasks_deleted_project_order', columns: {#deleted, #projectId, #sortOrder})
@TableIndex(name: 'idx_tasks_deleted_parent_order',  columns: {#deleted, #parentId,  #sortOrder})
@TableIndex(name: 'idx_tasks_deleted_status_order',  columns: {#deleted, #status,     #sortOrder})
@TableIndex(name: 'idx_tasks_deleted_due',           columns: {#deleted, #endAt,     #sortOrder})
@TableIndex(name: 'idx_task_tags_tag_task',          columns: {#tagId, #taskId})          // :203
@TableIndex(name: 'idx_sync_tombstones_updated_at',  columns: {#updatedAt})                // :266
```

**为什么这个设计更对**：本库 **绝大多数查询都带 `deleted = 0`**。把 `deleted` 放首位能让索引直接命中，省掉回表后的过滤步骤。尤其 `{deleted, projectId, sortOrder}` **一个索引同时解决过滤与排序** —— 精确匹配 `getAllByProject` 的 `WHERE deleted=0 AND projectId=? ORDER BY sortOrder`，无需 filesort。

`idx_task_tags_tag_task` 的列顺序（`tagId` 在前）也考虑到了 `exportAll` 的反向查询需求。

**额外加分项**（原建议未要求）：

1. `schemaVersion` 7 → **8**，且 `database.dart:11` 注释同步更新为 "schemaVersion = 8" —— **顺手修复了问题 12 的文档漂移**
2. 迁移中用 `CREATE INDEX IF NOT EXISTS` **手动建索引**，与 `@TableIndex` 注解名**逐字一致**（我用 `diff` 验证过），避免了 drift 注解与手写迁移之间的命名漂移风险
3. 迁移中**将 `settings` 表历史 JSON 墓碑导入新表**，并做 `try/catch` 降级 —— 考虑了数据连续性
4. `test/migrations/migration_test.dart` **+174 行**新测试：验证 6 个索引真实创建、2 条历史墓碑无损导入、3 条 upsert、`pruneTombstones` 后剩 2 条

**结论**：达到教科书水平。这一项可以关闭。

---

### ✅ B（标记三 / 问题 9 / 问题 13）CI 闸门 —— 超出预期

**这是本次整改中价值最高的一项**，因为它把"人肉全量评审"换成了自动检查 —— 直接针对 `docs/96` 7.4 标记三指出的"边际收益递减循环"。

**新增产物**：

| 文件 | 作用 |
|---|---|
| `tool/check_token_discipline.py` | 零容忍令牌守卫（3 类模式） |
| `tool/check_quality_gates.sh` | **3 道闸门**：① 架构分层（core→features、db→sync 零容忍）② `dart format` 阻断 ③ 巨型文件巡检 |
| `tool/verify.sh` | 统一入口，串联 4 步（令牌守卫 → 令牌 strict → `dart analyze` → 质量闸门） |
| `tool/install_hooks.sh` | git hook 安装 |
| `.github/workflows/ci.yml` | **push + pull_request 双触发**（main / dev） |

**两个设计细节值得肯定**：

1. **CI 在 `push` 和 `pull_request` 上都触发** —— 意味着从现在起**无法绕过**
2. **巨型文件守卫是"只巡检不阻断"**（打印列表后仍 `✅`）—— 这是**正确的**。若硬阻断 800 行，CI 会立刻变红（当前有多个文件超 800 行），反而会导致闸门被整体关闭

**结论**：闸门已建成。**但覆盖规则需扩充，见第三节问题 3。**

---

### ✅ C（问题 9）`dart format` —— 彻底解决

```
基线：Formatted 190 files (44 changed)
现在：Formatted 194 files (0 changed)
```

194 个文件全部合规，并已写入 `check_quality_gates.sh` 作为**阻断式**闸门。

**这是"改一次、根治"的标准处理** —— 不是逐个文件修格式，而是建立自动检查防止复发。原问题中的根因判断（"Dart 3.10 换了 tall-style 格式化器，而代码是旧版格式化后逐步手改的"）也成立。

**结论**：可以关闭。

---

### ✅ E（P0-3）`exportAll()` N+1 —— 干净利落

```dart
// 基线：N+1 查询（N 条任务 = N+1 次往返，且 task_tags.taskId 无索引）
for (final t in tasks) { taskTagIds[t.id] = await this.tags.tagIdsForTask(t.id); }

// 现在：1 次查询 + Dart 分组
final allTaskTags = await this.tags.getAllTaskTags();
for (final tt in allTaskTags) { (taskTagIds[tt.taskId] ??= []).add(tt.tagId); }
```

**额外发现（值得肯定）**：新增的 `tag_dao.dart:66 getAllTaskTags()` 不仅用于此处，还被另外两处复用：

- `lib/features/quadrant/providers/quadrant_providers.dart:327`
- `lib/features/today/today_providers.dart:226`

说明整改方**识别出了这是通用需求而非单点修补**，且顺手消除了这两处的同类 N+1。

**结论**：可以关闭。

---

### ✅ G（P0-4）墓碑独立表 —— 根治，且保留向后兼容

| 项 | 基线 | 现在 |
|---|---|---|
| 存储形态 | `settings` 单行 JSON | 独立表 `sync_tombstones(type, id, updatedAt)` |
| 写入方式 | 全量 `jsonEncode` 覆盖（**O(N) 单行**） | 逐条 upsert |
| 修剪方式 | 读全量 → 过滤 → 全量重写 | `DELETE WHERE updated_at < ?` |
| 损坏后果 | `on FormatException → []` → **全部墓碑丢失 → 已删任务复活** | 表有类型约束，且历史数据已迁入 |
| 索引 | 无 | `idx_sync_tombstones_updated_at` |

**向后兼容处理得当**：`readTombstones()` 优先读新表，**表为空时回退读 `settings` 历史数据**（注释标注"若尚未迁移或测试场景"），保证迁移前后行为连续。

**但有一处实现瑕疵**，见第四节问题 B。

---

### ✅ J 半数（P1-6）分层倒置 —— 正确

- `todoRepositoryProvider` 已迁至**新增文件** `lib/core/db/db_providers.dart:14`
- `lib/features/projects/project_providers.dart` 中的定义已移除
- `check_quality_gates.sh` 新增**零容忍**守卫：禁止 `lib/core/**` 导入 `features/`，禁止 `lib/core/db/**` 导入 `sync/`，**无过渡白名单**

"修代码 + 加守卫防复发"的完整处理。

**但 J 的另一半（`onDataChanged` 接口化）未做** —— 见第三节问题 2。

---

## 二、部分整改（2 项）

### 🟡 H（P1-5）巨型 `build()` —— 拆了关键 2 个，但总量未降

| 文件 | 基线 build() | 现在 build() | 判断 |
|---|---:|---:|---|
| `task_create_sheet.dart` | **833** | **356** | ✅ **真拆了** |
| `task_row.dart` | **371** | **424** | ⚠️ **实质已修，行数反升** |
| `ai_task_proposal_card.dart` | 734 | **734** | ❌ 未动 |
| 总体 ≥100 行的 build() | 53 | **54** | ❌ 净增 1 |

#### ✅ `task_create_sheet.dart`：真拆了

833 → 356 行，子任务区抽成独立文件 `task_create_subtasks_section.dart`（+251 行）+ `task_create_sheet_options.dart`。**这是正确的做法**，也是原建议的"按表单区/选择器区/提交区拆私有 widget"的实质落地。

#### ⚠️ `task_row.dart`：我的检测手段误判，实为修复

行数从 371 涨到 424，但我核对了实现细节 —— **问题实际已解决**：

```dart
// 现在：lib/features/tasks/widgets/task_row.dart
_hoveredNotifier = ValueNotifier<bool>(false);                       // :96
_pressedNotifier = ValueNotifier<bool>(false);                      // :97
// dispose 已补齐：:101-102
ListenableBuilder(
  listenable: Listenable.merge([_pressedNotifier, _hoveredNotifier]), // :241
  builder: (context, _) => AnimatedScale(
    scale: _pressedNotifier.value && ... ,
    child: AnimatedContainer(decoration: BoxDecoration(
      color: _rowColor(colorScheme, _hoveredNotifier.value), ...)),
  ),
)
```

**关键点**：`ListenableBuilder` 包住的是 `AnimatedScale` + `AnimatedContainer`（**仅视觉层**），而不是整棵树。hover 时只有 `decoration` 重绘 —— 标题 / 描述 / 日期 / 标签 / checkbox 全部不重建。

**这正是原建议的做法**（"改为 `ValueListenableBuilder` / `AnimatedBuilder` 局部重建，或把 hover 视觉下沉到只包 `AnimatedContainer` decoration 的轻量 wrapper"）。

行数上升的两个原因：
1. 基线是 `dart format` **旧版**格式，现在是新版 tall-style（多行展开），仅格式就膨胀
2. 拆出了 `_rowColor(colorScheme, hovered)` 辅助 + 补了 `dispose`

**诚实说明**：我的自动化检测（按 `build()` 物理行数统计）读不出"局部重建"这个区别，因此给出"反而涨了"的字面结论。**这是检测手段的局限，不是整改方的问题。**

#### ❌ 剩余 52 个未处理

包括最大的 `ai_task_proposal_card.dart:624`（**734 行**，未动）、`custom_view_editor_page.dart`（632）、`filter_criteria_sheet.dart`（617）。

**建议降级为 P2** —— 理由见第五节：闸门已建成（防止新增巨型文件），存量治理是纯体力活且无风险收益比优势。

---

### 🟡 I（P0-2）筛选下推 SQL —— 做了，但是死代码

`task_dao.dart:95` 新增了 `watchActiveInRange()`，SQL 写法**正确**：

```dart
Stream<List<Task>> watchActiveInRange({required int startMs, required int endMs}) {
  return (_db.select(_db.tasks)
        ..where((t) => t.deleted.equals(0) &
            ((t.startAt.isSmallerOrEqualValue(endMs) &
                (t.endAt.isNull() | t.endAt.isBiggerOrEqualValue(startMs))) |
             (t.endAt.isBiggerOrEqualValue(startMs) &
                t.endAt.isSmallerOrEqualValue(endMs))))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
      .watch();
}
```

重叠区间判定逻辑正确，且能命中新增的 `idx_tasks_deleted_due` 索引。

**但全仓库搜索的结果是零调用方**：

```
$ grep -rn "watchActiveInRange" --include="*.dart" .
./lib/core/db/daos/task_dao.dart:95:  Stream<List<Task>> watchActiveInRange({   ← 仅定义
```

这是一个 **"建好高速公路但没有匝道"** 的状态：今日 / 日历 / 搜索视图**仍然**走 `watchAllActive()` 拉全表 + Dart 端过滤。

**因此 P0-2 在用户可感知的层面完全没有改善。**

**客观评价**：不算错误。DAO 层新增下推能力本身是正确的基础设施投资，有朝一日接上即可。**但不构成"已整改"。**

**建议二选一，且必须做**（否则会变成永久死代码）：

- **接线**：把 `today_providers.dart` / `calendar_providers.dart` / `search_providers.dart` 切到 `watchActiveInRange()`
- **删除**：若短期不打算接线，先删掉，等真需要时再加（避免"看起来已优化"的误导）

---

## 三、需要整改但未整改（6 项）

### 🔴 未整改 1：`_pendingAgain`（P1-8 / 待办 F）—— 成本最低、收益最高，却未动

`lib/core/sync/sync_engine.dart:211-226` **逐字未改**：

```dart
Future<SyncResult> run() async {
  if (_running) {
    return const SyncResult(ok: false, skipped: true,
        errorCode: SyncErrorCode.skippedRunning,
        message: '同步进行中，本次触发已跳过');   // ← 仍然直接丢弃
  }
  _running = true;
  _setState(const SyncState(status: SyncStateStatus.syncing));
  try {
    return await _run();
  } finally {
    _running = false;
  }
}
```

原注释（含"被丢弃的编辑会在下一次触发时自然补上"的完整论证）也一字未动。

**风险重申**：编辑防抖 2 秒 + 指数退避最长数分钟，而一次 WebDAV 上传大快照经常 > 2 秒。**用户在同步期间的每次编辑都被静默丢弃，且最后一次编辑也可能丢**，直到下次手动同步或重启应用。

**成本 5 行。建议升级为 P0。**

---

### 🔴 未整改 2：`onDataChanged` 接口化（P1-7）

`lib/main.dart:38` 仍是裸赋值：

```dart
repo.onDataChanged = syncTriggers.onEdit;      // 未改
```

`todo_repository.dart:202` 仍是可变字段：

```dart
Future<void> Function()? onDataChanged;        // 未改
```

**原问题四个要点全部存在**：

- 无接口约束（任何 `void Function()` 都能塞进去）
- 无生命周期（谁负责清空？）
- 依赖 `main()` 内赋值顺序（隐式契约）
- 测试中若忘记赋值，自动同步静默不工作，无任何提示

**补充观察**：新增的 `db_providers.dart:9` 注释反而把现状**文档化**了 —— *"编辑自动同步接线（FR-SYNC-02）：Repository.onDataChanged 在 **main.dart**"*。这说明整改方**知道**这个设计并有意保留，而非遗漏。

**为何架构守卫拦不住**：质量闸门检查的是 `import` 方向，管不到"可变字段注入"这种运行期耦合。属于工具盲区。

**建议**：抽 `abstract interface class TaskChangeNotifier { void notifyChanged(); }`，`SyncTriggers` 实现，在 provider 内用 `ref.watch` 组装（天然处理顺序依赖）。

---

### 🟡 未整改 3：令牌绕过（问题 10）—— 数字完全没动，且闸门锁错了地方

| 项 | 基线 | 现在 |
|---|---:|---:|
| 裸数字样式字面量（`size:` / `fontSize:` 等） | 345 | **345** |
| 纯数字 `EdgeInsets` | 166 | **167** |

**新增的 `tool/check_token_discipline.py` 只检查 3 类极窄模式**：

```python
1. fontFamily: 'monospace'                     → 用 AppTokens.fontMonoFamily
2. circular(999) / circular(100)               → 用 AppTokens.radiusPill
3. MediaQuery...size.width > 数字               → 用 AppBreakpoints
```

**完全没有覆盖原问题指出的两类主力违规** —— `size: 18` / `size: 16` / `fontSize: 14` 和 `EdgeInsets.all(2)` / `EdgeInsets.fromLTRB(8, 4, 12, 2)`。

**这是本次核查中最值得指出的一点**：闸门建好了，但**闸门锁的是仓库里本来就没问题的三个角落**。我实测确认这三类模式当前均为 0 违规 —— 也就是说，**这个守卫目前是一条永远为真的恒真断言，对防止 `docs/96` 问题 10 复现毫无作用。**

违规最集中的两个文件原报告已指出，仍未处理：

- `lib/features/ai_copilot/` （尤以 `ai_task_proposal_card.dart` 为甚）
- `lib/features/calendar/calendar_page.dart`

**建议**：把 `size:` / `fontSize:` / `elevation:` 等裸数字、`EdgeInsets.*` 纯数字字面量纳入 `check_token_discipline.py`（可先设"存量白名单 + 新增零容忍"模式，避免一次性改动过大）。

---

### 🟡 未整改 4：文档漂移（问题 12 / 待办 D）—— 3 处修了 1 处

| 项 | 状态 |
|---|---|
| `database.dart:11` `schemaVersion` 注释 | ✅ 已修为 8 |
| `00-project-brief.md` 补 AI 章节 | ❌ **grep "AI" 仍 0 命中** |
| `AGENTS.md` 收录 M6–M9 | ❌ **grep M6/M7/M8/M9 仍 0 命中** |

**现状仍是"代码远超文档描述范围、文档仍在描述 v1"**。AI 助手已是 6,316 行生产代码 + 3,823 行测试的核心卖点，却不在 `00-project-brief.md` 里。

这会让未来的任何 agent（含三个月后的作者本人）基于错误的范围认知做决策。

---

### 🟡 未整改 5：`AGENTS.md` 测试前置条件（问题 15）—— 未补充

`grep "ALL_PROXY\|flutter clean" AGENTS.md` → **0 命中**。

本次审计实际踩过的两个坑仍未记录：

1. `ALL_PROXY=socks5://...` 存在时会**劫持 VM-service 端口**，导致全部测试文件 `HttpException: Connection closed before full header was received`。原 `AGENTS.md §2.5` 只写了 `unset http_proxy https_proxy`，**实测不够**
2. `.dart_tool` 增量编译缓存陈旧时会报出**明显不存在的编译错误**（如 `Undefined name 'inboxProjectId'`），需 `flutter clean`

**成本 3 行文档，建议补。**

---

### 🟡 未整改 6：50 个无测试文件（问题 11）—— 一个未补

新增了 `page_context_scope_test.dart`（373 行）与 `migration_test.dart`（+174 行），测试数 **880 → 891（+11）**。

但需明确：**这是新增功能的配套测试，不是我点名文件的补测。** 原报告点名的 50 个无测试文件一个未动，包括最大的两个：

- `lib/features/tasks/widgets/quick_capture_bar.dart`（**25 KB**，快速录入 = 高频入口）
- `lib/features/tasks/widgets/task_editor/task_date_picker_dialogs.dart`（**19 KB**，日期逻辑复杂 + 含农历/节假日）

**优先级判断**：`quick_capture_bar.dart` 作为高频入口且 25 KB，建议优先补。

---

## 四、整改引入的新问题（2 项）

### ⚠️ 新问题 A：死代码 `watchActiveInRange`

见第二节 🟡 I。**`flutter analyze` 不报"未使用的公共方法"，所以 CI 闸门拦不住**，需要人工决策（接线 or 删除）。

### ⚠️ 新问题 B：墓碑 upsert 是"读-改-写"两段式，非原子

`lib/core/db/repositories/todo_repository.dart:1392-1420`：

```dart
Future<void> _mergeTombstonesInner(Iterable<TombstoneEntry> entries) async {
  final list = entries.toList();
  if (list.isEmpty) return;
  for (final e in list) {
    if (e.id.isEmpty) continue;
    final existing = await (database.select(database.syncTombstones)..where(          // ① 查询
          (t) => t.entityType.equals(e.type) & t.entityId.equals(e.id),
        )).getSingleOrNull();
    if (existing == null) {
      await database.into(database.syncTombstones).insert(...);                        // ② 插入
    } else if (e.updatedAt > existing.updatedAt) {
      await (database.update(database.syncTombstones)..where(...)).write(...);         // ③ 更新
    }
  }
}
```

**每次写墓碑 = 2 次数据库往返**（N 条墓碑 = 2N 次）。而 v8 表已建好，`insertOnConflictUpdate` 完全可用 ——

**关键观察：这个方法在 `database.dart` 的 v8 迁移里已经用了**：

```dart
// lib/core/db/database.dart:112
await into(syncTombstones).insertOnConflictUpdate(
  SyncTombstonesCompanion.insert(entityType: ..., entityId: ..., updatedAt: ...),
);
```

**迁移里用了，Repository 里没用 —— 同一张表，两种写法。** 统一即可，能把 2N 次往返降到 N 次。

#### ⚠️ 重要：这是回归还是进步？

| 维度 | 基线（settings JSON） | 现在（独立表两段式） |
|---|---|---|
| 数据库往返 | 1 次（单行全量覆盖） | 2N 次 |
| 复杂度 | O(N) | O(N) |
| **原子性** | ✅ **单行写入原子** | ❌ 多行非原子 |

**结论：不应回退。** 单行原子性其实更强，且独立表解决了写放大、损坏风险、可查询性三个更严重的问题。

**建议向前修**：改为单次 `insertOnConflictUpdate`（用 `updatedAt` 做条件更新，或先读出 max 再批量 upsert），恢复原子性并减少往返。

---

## 五、`docs/96` 7.8 待办表更新建议

| # | 原状态 | 核查结论 | 建议 |
|---|---|---|---|
| A | ☐ | ✅ **已完成（超出预期）** | **关闭** |
| B | ☐ | ✅ **已完成（含 GitHub Actions）** | **关闭**，但需扩充 `check_token_discipline.py` 规则（第三节问题 3） |
| C | ☐ | 🟡 **部分**：闸门建了，"回收日"未做 | **保留** |
| D | ☐ | 🟡 **1/3**：schemaVersion 注释已修 | **保留** |
| E | ☐ | ✅ **已完成** | **关闭** |
| F | ☐ | ❌ **未做** | **⬆ 升级为 P0**（5 行，零风险，收益最高） |
| G | ☐ | ✅ **已完成** | **关闭** + 顺手改 `insertOnConflictUpdate`（第四节问题 B） |
| H | ☐ | 🟡 **2/53**（`task_row` 实为已修） | **⬇ 降级 P2**（闸门已防新增，存量治理是体力活） |
| I | ☐ | 🟡 基础设施已建、**零接线** | **接线 or 删除**，二选一必须做 |
| J | ☐ | 🟡 分层已修；`onDataChanged` 未修 | **保留**（P3） |

**净变化**：关闭 4 项（A / B / E / G），保留 5 项（C / D / H / I / J），新增 1 项待决策（F 升级 P0）。

---

## 六、评分变化

| 维度 | 基线 | 现在 | 变化原因 |
|---|---:|---:|---|
| 架构方向正确性 | 8.0 | **8.5** | ↑ 分层倒置已修 + CI 零容忍守卫强制 |
| 测试护栏 | 8.0 | **8.5** | ↑ +11 测试 + v8 迁移专项测试 |
| 演进节奏 | 5.0 | **5.5** | ↑ 闸门建成，净增长趋势开始受控 |
| 扩展成本 | 4.5 | **4.5** | — 未变（同步实体仍 5 个） |
| UI 层可维护性 | 4.0 | **4.5** | ↑ `task_create_sheet` 真拆 + `task_row` 局部重建已修 |
| **质量保障机制** | 4.0 | **7.5** | ↑↑ **最大改善**：人肉全量评审可退役 |
| 文档可信度 | 4.5 | **4.5** | — 1/3（brief + AGENTS.md 未动） |
| **性能天花板** | 3.5 | **6.0** | ↑↑ WAL + 6 复合索引 + N+1 消除 |
| **综合** | **6.5** | **7.5** | **+1.0** |

> `docs/96` §7.6 曾预测"做完四道闸门，本项目从 6.5 → 7.5"。**实测正好 7.5。**

---

## 七、给整改方的建议

### 执行力很强，但**排序有问题**

先做了大动作（schema v8 迁移、CI 工具链、组件拆分），把**"小改动高收益"**（F `_pendingAgain`、`onDataChanged` 接口化）和**"补文档"**留到了最后。

**这在一次性交付里是合理的取舍**（先拿硬成果）。但下一轮若继续按"先大后小"的顺序，F 和补文档会继续被推迟。

### 下一轮建议：只做这 4 件小事，不再碰大动作

| # | 动作 | 成本 | 收益 |
|---|---|---|---|
| **1** | **`sync_engine.dart` 加 `_pendingAgain`** | **5 行** | **消除"编辑没同步上去"整类问题** |
| **2** | **扩充 `check_token_discipline.py`**：把 `size:` / `fontSize:` / `EdgeInsets` 裸数字纳入（存量白名单 + 新增零容忍） | 30 分钟 | **让闸门真正起作用**，否则是恒真断言 |
| **3** | **`watchActiveInRange` 二选一**：接线到今日/日历/搜索，或删除 | 接线 2–3h / 删除 5 分钟 | 消除死代码；或真正兑现 P0-2 |
| **4** | **墓碑 upsert 改 `insertOnConflictUpdate`** | 20 分钟 | 2N 次往返 → N 次，恢复原子性 |

**外加两项文档（合计 < 10 分钟）**：

- `AGENTS.md §2.5` 补 `unset ALL_PROXY all_proxy HTTP_PROXY HTTPS_PROXY` + `flutter clean` 兜底
- `00-project-brief.md` 补 AI 助手章节；`AGENTS.md` 补 M6–M9 里程碑

### 明确**不要**做的事

- ❌ **不要现在拆 `TodoRepository`** —— `docs/96` §7.5 已论证：5 个同步实体尚未到临界点，现在拆是净成本
- ❌ **不要回退墓碑独立表** —— 独立表方向正确，只是 upsert 写法需优化（第四节问题 B 已说明不应回退）
- ❌ **不要为行数目标大改 UI** —— 53 → 54 的 build() 数字变化无意义；闸门已防新增，存量按需改即可
- ❌ **不要再写第 18 份人肉全量评审报告** —— `bash tool/verify.sh` 已覆盖格式 / 分析 / 分层 / 令牌，机器比人扫得准

### 一句话

> **大动作做得很好（schema v8 + CI 工具链是本轮最有价值的产出）。但下一轮请把力气花在"5 行就能消除一类用户投诉"的事情上，而不是"行数能降 8 千"的事情上。**

---

## 附录 A：核查命令清单（可复现）

```bash
# 前置：清空全部代理变量（含 ALL_PROXY，否则 VM-service 端口被劫持）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

# 1. 整改范围
git log --oneline 0130ee8..HEAD
git diff --stat 0130ee8..HEAD

# 2. P0-1 索引与 WAL
grep -c "TableIndex" lib/core/db/tables.dart
grep -n "PRAGMA" lib/core/db/database.dart
grep -n "int get schemaVersion" lib/core/db/database.dart

# 3. 索引名一致性（tables.dart 注解 vs 手写迁移）
grep -oE "idx_[a-z_]+" lib/core/db/tables.dart    | sort -u > /tmp/idx_a
grep -oE "idx_[a-z_]+" lib/core/db/database.dart | sort -u > /tmp/idx_b
diff /tmp/idx_a /tmp/idx_b && echo "✅ 一致"

# 4. P0-3 N+1 是否消除（应见 getAllTaskTags 批量调用，非 tagIdsForTask 循环）
grep -n "tagIdsForTask\|getAllTaskTags" lib/core/db/repositories/todo_repository.dart

# 5. P0-4 墓碑是否已从 settings JSON 迁走
grep -rn "_kSyncTombstonesKey\|syncTombstones" lib --include="*.dart" | grep -v "\.g\.dart"

# 6. 第二问题 A 死代码（应只有定义、零调用方）
grep -rn "watchActiveInRange" . --include="*.dart" | grep -v "\.dart_tool\|build/"

# 7. 第三问题 F _pendingAgain（应无命中 = 未整改）
grep -n "_pendingAgain" lib/core/sync/sync_engine.dart

# 8. 格式与测试
dart format --output=none --set-exit-if-changed lib   # 期望 0 changed
flutter analyze                                          # 期望 No issues found
flutter test --reporter=compact                          # 期望 All tests passed

# 9. P1-5 巨型 build() 现状
#    （注意：按物理行数统计会误判 task_row.dart —— 它已改 ListenableBuilder 局部重建）
```

---

## 附录 B：逐项核查索引表（15 项）

| 报告章节 | 问题 | 状态 | 一句话结论 |
|---|---|---|---|
| P0-1 | 全库零索引 / 无 WAL | ✅ 已整改 | 6 复合索引 + 3 条 PRAGMA，`deleted` 置首位优于建议 |
| P0-1 | v7→v8 迁移与测试 | ✅ 已整改 | 迁移 + 174 行测试，索引名与注解逐字一致 |
| P0-2 | 全表加载 + Dart 端过滤 | 🟡 部分 | `watchActiveInRange` 已建但**零调用方** |
| P0-3 | `exportAll` N+1 | ✅ 已整改 | 批量查询，且被另两处复用 |
| P0-4 | 墓碑存 settings JSON | ✅ 已整改 | 独立表 + 历史迁移 + 兼容读取 |
| P0-4 | 墓碑 upsert 原子性 | ⚠️ 新问题 | 两段式读-改-写，非原子（迁移里已用原子写法） |
| P1-5 | 833 行 `task_create_sheet` | ✅ 已整改 | 833 → 356，抽 `task_create_subtasks_section.dart` |
| P1-5 | `task_row` hover 全树重建 | ✅ 已整改 | 改 `ListenableBuilder` 局部重建（行数升是格式所致） |
| P1-5 | 其余 51 个巨型 build() | ❌ 未整改 | 54 vs 基线 53；含最大 734 行 |
| P1-6 | core→features 分层倒置 | ✅ 已整改 | 迁至 `db_providers.dart` + 零容忍守卫 |
| P1-7 | `onDataChanged` 可变字段 | ❌ 未整改 | `main.dart:38` 裸赋值仍在 |
| P1-8 | `_pendingAgain` 丢事件 | ❌ 未整改 | `sync_engine.dart:211-226` 逐字未改 |
| P2-9 | `dart format` 不合规 | ✅ 已整改 | 194 文件 0 changed + 阻断式闸门 |
| P2-10 | 令牌绕过（345/166） | ❌ 未整改 | 数字未动；守卫只覆盖 3 类恒真模式 |
| P2-12 | 文档漂移 3 处 | 🟡 1/3 | 仅 schemaVersion 注释已修 |
| P2-15 | `AGENTS.md` 测试前置 | ❌ 未整改 | `ALL_PROXY` / `flutter clean` 未补 |
| 问题 11 | 50 个文件无测试 | ❌ 未整改 | +11 测试均为新增功能配套 |
| 标记三 | 人肉质量保障 | ✅ 已整改 | **3 工具 + verify.sh + ci.yml 双触发** |

---

## 附录 C：本次核查未覆盖的范围

诚实声明：

- **未做真机性能基准测试** —— WAL 与索引的收益是**基于查询模式与执行计划推断的**，未实测 1,000 / 5,000 / 10,000 条任务下的 P99 延迟
- **未逐条审查 4 个 commit 的全部 diff** —— 聚焦 `docs/96` 所列问题相关文件；`f5a22b8` 涉及 29 个文件（含 AI、calendar、projects、settings 等），其中与本报告问题无关的改动未审查
- **未验证迁移在真机真实数据下的表现** —— 仅依赖 `migration_test.dart` 的内存库测试；**建议在真机或生产数据副本上跑一次 v7→v8 迁移验证**
- **未审查 CI 在 GitHub Actions 上的实际运行结果** —— 仅静态核查 `ci.yml` 内容与本地 `verify.sh` 可执行性
- **未评估 `e77e257`（`page_context_scope` 重构）** —— 该 commit 属另一条工作线（scoped action dispatcher），不在 `docs/96` 建议范围

---

> **文档结束 · 状态：已核查 · 待整改方确认**
> 本次核查为**只读审计**，**未修改任何项目代码**。所有"已完成"判定均经独立验证手段复核（见文首验证表），未采信 commit message 自述。
> `docs/96-code-review-0130ee8-head.md` 的 §7.8 状态列已同步更新为本核查结论。