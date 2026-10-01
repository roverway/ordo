# 剩余工作清单：dev @ 335890c

> - **文档状态**：**待执行**（本清单所有条目均未实施，需批准后逐项处理）
> - **文档定位**：在四轮整改（`docs/96` → `97-` → 三轮复核）之后的**剩余工作台账**，逐项列出可做之事与优先级
> - **基线**：`dev` 分支 @ `335890c`（`fix(quality-gates): ignore python cache and enforce giant file ratchet guard`）
> - **工作树状态**：clean
> - **产出时间**：2026-09-30
> - **报告归档**：`docs/98-remaining-work-dev-335890c.md`
> - **上游文档**：`docs/96-code-review-0130ee8-head.md`（代码质量评价）、`docs/97-remediation-verification-f5a22b8.md`（整改核查）
> - **只读声明**：本次整理为**只读审计**，**未修改任何项目代码**，未执行任何整改动作。

---

## 摘要

**四轮整改下来，能自动化的、低成本高收益的部分基本做完。** 6 道闸门全部建立，其中 4 道为硬阻断；巨型文件棘轮已贴顶守住。

剩余工作分三类：

| 类别 | 项数 | 合计成本 | 性质 |
|---|---:|---|---|
| 🔴 **最高优先级** | 1 | **1 分钟** | 28 commit 未推送，CI 修复未经实战验证 |
| 🟡 **P1 闸门逻辑一致性** | 3 | **约 1.5 小时** | 复用已验证可行的棘轮模式 |
| 🟡 **P1 代码问题** | 1 | **半天** | 四轮整改唯一未碰的 P1 |
| 🟢 **P2 周期性技术债** | 4 | 按需 | 不紧急 |

---

## 我的独立验证（本次实测）

| 验证项 | 结果 |
|---|---|
| `bash tool/verify.sh` | **exit = 0**，6 道闸门全部通过 |
| `dart format lib test tool` | **273 files (0 changed)** |
| `flutter test` | **892 通过 / 6 skip / 0 失败** |
| 巨型文件棘轮 | **15 / 15 贴顶守住** |
| 令牌白名单外违规 | **size 0 / EdgeInsets 0** |

---

## 本轮（`335890c`）已完成的整改

| 改动 | 评价 |
|---|---|
| **闸门③巨型文件改为真棘轮阻断** | ✅ **正确**。`MAX_ALLOWED = 15` + `sys.exit(1)`，从"只巡检"升级为硬阻断 |
| `.gitignore` 补`__pycache__/` `*.py[cod]` | ✅ 顺手修的正确细节（`check_token_discipline.py` 每次运行都产生 `.pyc`）|

实测输出：

```
🛡️  [Quality Gate 3/3] 巨型文件健康度巡检（棘轮守卫）...
ℹ️  当前 lib/ 下超过 800 行的业务/UI 文件共 15 个（棘轮基准上限: 15）
✅ 巨型文件棘轮守卫通过：当前 15/15，未发生破窗生长。
✅ 所有守卫检查全部通过！代码规范健康！
```

---

# 🔴 最高优先级：28 个 commit 未推送

**这是唯一"零成本、且决定其他工作是否有意义"的一项。**

## 事实

```
$ git rev-list --count origin/dev..dev
28

$ git log -1 --format='%h %ci %s' origin/dev
7eed57f 2026-09-28 09:50:24  build(ci): use ubuntu:20.04 container for linux AppImage glibc compatibility

$ gh run list --branch dev --limit 3
[ok] Build and Release  363677230092026-09-28
[ok] CI                  36367549986  2026-09-28
[ok] CI                  35969770349  2026-09-24
```

**`origin/dev` 停在 2026-09-28，本地 `dev` 已推进 28 个 commit（含全部四轮整改）。**

## 后果

`ci.yml` 已在 `62e1197` 改为 `branches: ['**']`（覆盖所有分支），但**这批代码从未被 push，因此 GitHub Actions 一次都没跑过它们**。

**`branches: ['**']` 这个修复目前仍是"未经实战验证的"** —— 语法正确、逻辑正确，但只有真正 push 后才能确认生效。

同时，四轮整改中"commit 能成功"这件事，是靠**本机 pre-commit hook** 保证的（`.git/hooks/pre-commit`，2026-09-17 装，仅本机有效），**不是靠 CI**。

## 动作

```bash
git push origin dev
# 推送后确认 CI 真的跑起来：
gh run list --branch dev --limit 3
```

**预期**：应看到 `62e1197` 与 `335890c` 对应的 CI 运行记录，且状态为 success。

**若失败**：说明 `ci.yml` 的 `branches: ['**']` 在实际环境有问题（可能需改成省略 `branches` 字段），届时需修正。

---

# 🟡 P1：闸门逻辑的 3 处不一致（约 1.5 小时）

## #1 令牌白名单 → 真数量棘轮（1 小时）

### 问题

`tool/check_token_discipline.py` 文件头写着 `Implements the Ratchet Pattern`，但实现是 **111 条硬编码路径永久豁免**（`SIZE_LEGACY_FILES` 68 条 + `EDGE_INSETS_LEGACY_FILES` 43 条）：

```python
if not is_token_file and rel_path not in SIZE_LEGACY_FILES:   # 命中白名单则整段跳过
    if re.search(r'\b(fontSize|size):\s*\d+(\.\d+)?\b', line):
        violations.append(...)
```

### 这不是棘轮

**真棘轮是"数量预算"，这里是"路径黑名单"。**

| | 路径白名单（现状） | 数量棘轮（目标） |
|---|---|---|
| 新文件 | ✅ 零容忍 | ✅ 零容忍 |
| 111 个豁免文件 | ❌ **可无限新增违规** | ✅ 清理任一个即降预算 |
| 预算收缩 | ❌ 需手动改代码 | ✅ 自动 |

### 具体后果

`task_row.dart` 在 `SIZE_LEGACY_FILES` 里，所以给它加 `size: 999`、`size: 888`、加一百个 —— **闸门永远绿灯**。

**实测这 111 个文件承载了全部 479 处存量违规**：

| | 白名单内 | 白名单外 |
|---|---:|---:|
| 裸 `size` / `fontSize` | **263** | 0 |
| 裸 `EdgeInsets` | **216** | 0 |

**换句话说：闸门守住了新文件，但债务集中区（479 处违规）可以随意恶化。**

### 改法

把路径白名单换成数量预算，与本轮刚完成的巨型文件棘轮**完全同构**：

```python
# 数量棘轮：当前实测值，只减不增（清理存量后手动下调）
SIZE_BUDGET = 263
EDGE_BUDGET = 216

# 统计全部违规（含豁免文件），超预算即 sys.exit(1)
```

**收益**：清理任一老文件即自动降预算，**不需要改闸门代码**；冻结区无法恶化。

**注意**：切换后需重新实测基线数字（我给出的是当前值，若期间有代码变动需重测）。

---

## #2 `check_tokens.dart` 二选一（10 分钟）

### 问题

`tool/verify.sh:21` 写死：

```bash
dart run tool/check_tokens.dart --strict
```

而它的 6 条规则**全部 0 命中**（实测）：

```
bare-font-size    0  |  bare-color    0  |  bare-alpha   0
bare-radius       0  |  monospace     0  |  bare-duration  0
合计违规：0 处
```

同时该工具自带的 `--max N` 棘轮（文件注释里明确设计了）**从未启用**。

### 现状描述

**两套令牌闸门并存**：

| 工具 | 规则数 | 命中 | 模式 | 实际作用 |
|---|---:|---:|---|---|
| `check_token_discipline.py` | 5 | 0（白名单外） | 路径白名单 | 部分有效 |
| `check_tokens.dart` | 6 | 0 | `--strict` 零容忍 | **恒真断言** |

### 建议

二选一，不要并存：

- **方案 A**：启用其自带棘轮 —— `dart run tool/check_tokens.dart --max <实测值>`
- **方案 B**：从 `verify.sh` 移除，只保留 `check_token_discipline.py`

**推荐方案 A**，因为 `check_tokens.dart` 的规则（`Color(0x` / `withValues(alpha:` / `Radius.circular` / `Duration(milliseconds:`）与 py 脚本的规则**不重叠**，覆盖面更广。

---

## #3 hook 版本化 + 减重（25 分钟）

### 问题一：hook 不随仓库分发

```
$ ls .githooks                → ❌ 不存在
$ git config core.hooksPath   → ❌ 未设置
$ stat .git/hooks/pre-commit  → 存在，2026-09-17 13:15，175 bytes
```

`.git/hooks/` **不在版本控制内**。所以：

| 环境 | pre-commit hook | `verify.sh` |
|---|---|---|
| 你本机 | ✅（2026-09-17 装） | ✅ |
| CI runner | ❌ | ❌（`ci.yml` 显式调用，不依赖 hook） |
| **换机器 / 新克隆** | ❌ | ✅ 但没人调用 |

`tool/install_hooks.sh` **从未被自动调用** —— 只是躺在仓库里等人手动跑。

### 问题二：hook 太重（实测 19.3 秒）

| 步骤 | 耗时 |
|---|---:|
| `check_token_discipline.py` | 0.2s |
| `check_tokens.dart` | 0.8s |
| **`dart analyze`** | **15.3s** |
| `dart format`（全量 273 文件） | 3.1s |
| **合计** | **19.3s** |

**19 秒的 pre-commit 是"绕过诱因"** —— 总有人会打 `--no-verify`，闸门就永久失效了。这是所有本地门禁最常见的死法。

### 做法

**hook 移入版本控制**：

```bash
# .githooks/pre-commit（新增，进版本控制）
#!/usr/bin/env bash
set -e
cd "$(git rev-parse --show-toplevel)"
bash tool/check_quality_gates.sh          # 架构 + 格式 + 棘轮，约 3.5s
python3 tool/check_token_discipline.py    # 0.2s
# 不跑 dart analyze（15.3s）—— 交给 CI

git config core.hooksPath .githooks
git add .githooks && git commit -m "chore: version pre-commit hook"
```

**收益**：commit 从 **19.3s → 约 3.7s**；换机器自动生效。

**验证**：`time git commit --allow-empty -m test` 应 < 5s。

---

# 🟡 P1：唯一的 P1 级代码问题（半天）

## #4 `onDataChanged` 接口化

### 现状

`lib/main.dart:38` 仍是裸赋值：

```dart
repo.onDataChanged = syncTriggers.onEdit;      // 仍是可变字段
```

`lib/core/db/repositories/todo_repository.dart:202`：

```dart
Future<void> Function()? onDataChanged;        // 仍是可变字段
```

**这是 `docs/96` 第三节问题 7，也是四轮整改中唯一没被碰的 P1 级代码问题。**

### 四个原始问题全在

| 问题 | 现状 |
|---|---|
| 无接口约束 | ❌ 任何 `void Function()` 都能塞进去 |
| 无生命周期 | ❌ 谁负责清空？|
| 依赖 `main()` 赋值顺序 | ❌ 隐式契约：`container.read(syncTriggersProvider)` 必须早于赋值 |
| 测试忘记赋值时静默失效 | ❌ 自动同步不工作，无任何提示 |

**补充观察**：`lib/core/db/db_providers.dart:9` 的注释反而把现状**文档化**了 —— *"Repository.onDataChanged 在 **main.dart**"*。说明这是**有意保留的设计**，而非遗漏。

**为何闸门拦不住**：质量闸门检查的是 `import` 方向，管不到"可变字段注入"这种运行期耦合。属工具盲区。

### 做法

```dart
// 1. 抽接口
abstract interface class TaskChangeNotifier {
  void notifyChanged();
}

// 2. TodoRepository 改为持有接口而非裸函数类型
class TodoRepository {
  TaskChangeNotifier? changeNotifier;
  void _notify() => changeNotifier?.notifyChanged();
  // 29 处 onDataChanged?.call() → _notify()
}

// 3. SyncTriggers 实现该接口

// 4. 在 provider 内用 ref.watch 组装（天然处理顺序依赖，替代 main() 裸赋值）
final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final repo = TodoRepository(...);
  repo.changeNotifier = ref.watch(syncTriggersProvider);
  return repo;
});
```

**收益**：消除顺序依赖、消除"测试忘记赋值"的静默失效、类型安全。

---

# 🟢 P2：周期性技术债（不紧急）

以下不是"该修的 bug"，而是需要排期的存量治理。**闸门已建成并贴顶守住，不会继续恶化**，所以可以按需慢慢做。

## #5 巨型文件存量治理

**现状：15 个文件 > 800 行**（棘轮基线，已贴顶守住）

| 文件 | 行数 | 备注 |
|---|---:|---|
| `lib/core/db/repositories/todo_repository.dart` | **1,519** | 见 #8，暂不建议拆 |
| `lib/features/calendar/calendar_page.dart` | 1,406 | UI |
| `lib/features/projects/widgets/create_list_folder_sheet.dart` | 1,361 | UI |
| `lib/features/ai_copilot/widgets/ai_task_proposal_card.dart` | 1,359 | UI，**建议从这里开始** |
| `lib/features/settings/settings_page.dart` | 1,230 | UI |
| `lib/shared/widgets/markdown_content_view.dart` | 1,185 | Markdown 渲染器 |
| `lib/shared/widgets/scope_nav_content.dart` | 1,171 | UI |
| `lib/core/sync/sync_engine.dart` | 1,062 | **不应拆**，设计已验证 |
| `lib/features/tasks/widgets/task_tree.dart` | 1,060 | |
| `lib/features/tasks/widgets/task_editor.dart` | 1,027 | |
| 其余 5 个 | 908–980 | |

**建议做法**：从 `ai_task_proposal_card.dart`（1,359 行）开始 —— **纯 UI、无业务逻辑、无测试覆盖要求**，风险最低。拆完后：

```bash
# 同步下调棘轮基线（15 → 14）
# tool/check_quality_gates.sh: MAX_ALLOWED = 14
```

**做出一个示范后**，再决定是否批量推进。**不要一次性拆 15 个** —— 收益递减且风险累积。

---

## #6 巨型 `build()` 存量

**现状：54 个 `build()` ≥ 100 行**（`docs/96` 基线 53，**净增 1**）

| 文件:行 | build() 长度 |
|---|---:|
| `lib/features/ai_copilot/widgets/ai_task_proposal_card.dart:624` | **734** |
| `lib/features/custom_views/presentation/custom_view_editor_page.dart:147` | 632 |
| `lib/features/custom_views/widgets/filter_criteria_sheet.dart:189` | 617 |
| `lib/features/settings/views/ai_settings_page.dart:475` | 432 |
| `lib/features/quadrant/widgets/quadrant_scope_filter_sheet.dart:58` | 427 |
| `lib/features/tasks/widgets/task_row.dart:148` | 424（**已改局部重建，实为已修**） |
| `lib/core/theme/app_theme.dart:45` | 407 |
| 其余 47 个 | 100–365 |

**注意**：`task_row.dart` 是**误报** —— 它已改`ListenableBuilder` 局部重建（`docs/97` 第一节已核实），只是行数上升。按物理行数统计读不出这个区别。

**现状评价**：`docs/96` 说"53 个"，现为"54 个"。**闸门只管 >800 行文件，不管 build() 长度**，所以这个数字仍会缓慢上升。

**建议**：若认为需要治理，在闸门里加一条 `build() ≥ 400 行` 的棘轮（当前基线 7 个）。**但优先级低于 #5** —— build() 长度是指标，不是缺陷本身。

---

## #7 无测试文件

**现状：51 个 lib 文件无对应测试**（`docs/96` 基线 50，**净增 1**）

体积最大的：

| 文件 | 体积 | 备注 |
|---|---:|---|
| `lib/features/tasks/widgets/task_editor/project_picker_sheet.dart` | 19 KB | |
| `lib/features/tasks/widgets/task_editor/task_date_picker_dialogs.dart` | 19 KB | **日期逻辑复杂，含农历/节假日** |
| `lib/shared/widgets/unified_hierarchical_folder_selector.dart` | 15 KB | |
| `lib/features/tasks/widgets/task_create_sheet_options.dart` | 14 KB | 新增文件 |
| `lib/features/quadrant/widgets/quadrant_cards_view.dart` | 12 KB | |
| `lib/features/settings/widgets/ai_mcp_server_card.dart` | 9 KB | |

**测试总数**：892（`docs/96` 基线 880，**+12**）

**说明**：新增的 12 个测试来自 `page_context_scope_test.dart`（373 行）与 `migration_test.dart`（+174 行），属**新增功能配套**，非存量补测。

**建议优先级**：
1. `task_date_picker_dialogs.dart` —— 逻辑复杂且含农历/节假日，**bug 风险最高**
2. `project_picker_sheet.dart` —— 19KB，交互分支多
3. `quick_capture_bar.dart` —— 高频入口（注：本次统计显示它已有测试，未在列）

---

## #8 `TodoRepository` 拆分 —— **暂不建议**

**现状**：1,519 行 / 23 个文件引用

**`docs/96` §7.5 已论证**：5 个同步实体（projects / tasks / tags / folders / customViews）尚未到架构临界点，**现在拆是净成本**。

**重新评估的触发条件**（满足任一再议）：

- 同步实体从 5 个增加到 **8–10 个**
- 引用文件数从 23 增加到 **35+**
- 行数突破 **1,800 行**

**当前状态**：未到临界点，**不要动**。

---

# 评分现状

| 维度 | 分数 | 说明 |
|---|---:|---|
| 架构方向正确性 | **8.5** | 分层倒置已修 + 零容忍守卫强制 |
| 测试护栏 | **8.7** | 892 测试 + v8 迁移专项 + `_pendingAgain` 真并发测试（`Completer` 控时序）|
| 演进节奏 | **5.5** | 棘轮已建成，但存量未减（15 巨型文件 / 54 build() / 51 无测试）|
| 扩展成本 | **4.5** | 同步实体仍 5 个，未变 |
| UI 层可维护性 | **4.5** | 2/54 已拆，`task_row` 已实质修复 |
| **质量保障机制** | **8.2** | 6 道闸门，4 道硬阻断；**扣分点**：令牌白名单非棘轮 + `check_tokens` 恒真 + hook 未版本化 |
| 文档可信度 | **5.8** | 漂移 3/3 已清 + `AGENTS.md` 测试前置已补 |
| 性能天花板 | **6.0** | WAL + 6 复合索引 + N+1 消除 + 墓碑批量原子 upsert |
| **综合** | **8.0** | 基线 `0130ee8` 为 6.5 |

---

# 执行建议：顺序与成本

| 序 | 动作 | 类别 | 成本 | 阻断性 |
|---:|---|---|---|---|
| **1** | **`git push origin dev`** | 🔴 | **1分钟** | 验证 CI 配置是否真生效 |
| **2** | 令牌白名单 → 数量棘轮 | 🟡 #1 | 1 小时 | 阻止 479 处存量违规区恶化 |
| **3** | hook 版本化 + 减重到 ~3.7s | 🟡 #3 | 25 分钟 | 防"`--no-verify` 绕过" |
| **4** | `check_tokens.dart` 二选一 | 🟡 #2 | 10 分钟 | 消除恒真断言 + 消除双闸门困惑 |
| **5** | `onDataChanged` 接口化 | 🟡 #4 | 半天 | 消除四轮唯一未碰的 P1 |
| 6 | 拆 `ai_task_proposal_card.dart`（1,359 行）| 🟢 #5 | 半天 | 巨型文件治理示范；拆完下调棘轮至 14 |
| 7 | 补 `task_date_picker_dialogs.dart` 测试 | 🟢 #7 | 2 小时 | 日期/农历逻辑，bug 风险最高 |
| 8 | `build()` 棘轮（可选）| 🟢 #6 | 30 分钟 | 阻断 54 个 build() 继续增长 |

**第 1 项必须先做** —— 它零成本，且决定第 2–8 项的 CI 保障是否真实存在。

---

# 明确不要做的事

- ❌ **不要回退墓碑独立表** —— `sync_tombstones` 方向正确（已解决写放大 / 损坏风险 / 可查询性），upsert 已原子化，无需再改
- ❌ **不要现在拆 `TodoRepository`** —— 见 #8，未到临界点
- ❌ **不要为行数目标大改 UI** —— 棘轮已防新增，存量按需拆
- ❌ **不要再写第 18 份人肉全量评审报告** —— `bash tool/verify.sh` 已覆盖格式 / 分析 / 分层 / 令牌 / 巨型文件 / 棘轮，机器比人扫得准
- ❌ **不要同时拆多个巨型文件** —— 一次一个，拆完跑一次 `verify.sh` + `flutter test`

---

## 附录 A：核查命令清单（可复现）

```bash
# 前置：清空全部代理变量（含 ALL_PROXY，否则 VM-service 端口被劫持）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

# 0. 当前状态
git rev-parse --abbrev-ref HEAD          # 期望 dev
git status --short                       # 期望 clean
git rev-list --count origin/dev..dev     # 未推送 commit 数（当前 28）

# 1. 全套闸门
bash tool/verify.sh                      # 期望 exit 0
dart format --output=none --set-exit-if-changed lib test tool   # 期望 0 changed
flutter analyze                                          # 期望 No issues found
flutter test --reporter=compact                          # 期望 All tests passed

# 2. 巨型文件棘轮（期望 15/15）
python3 - <<'EOF'
import os
IGNORE={'lib/core/l10n/app_localizations.dart',
        'lib/core/l10n/app_localizations_en.dart',
        'lib/core/l10n/app_localizations_zh.dart',
        'lib/features/settings/user_manual_page.dart'}
n=[]
for r,_,fs in os.walk('lib'):
    for f in fs:
        if f.endswith('.dart') and not f.endswith('.g.dart'):
            p=os.path.relpath(os.path.join(r,f),'.')
            if p in IGNORE: continue
            L=sum(1 for _ in open(os.path.join(r,f),encoding='utf-8'))
            if L>800: n.append((p,L))
print(f">800 行: {len(n)} 个（基线 15）")
for p,l in sorted(n,key=lambda x:-x[1])[:5]: print(f"   {l:>5}  {p}")
EOF

# 3. 令牌白名单规模与豁免区违规量
python3 - <<'EOF'
import importlib.util,os,re
s=importlib.util.spec_from_file_location('c','tool/check_token_discipline.py')
m=importlib.util.module_from_spec(s); s.loader.exec_module(m)
print(f"SIZE_LEGACY_FILES: {len(m.SIZE_LEGACY_FILES)}")
print(f"EDGE_INSETS_LEGACY_FILES: {len(m.EDGE_INSETS_LEGACY_FILES)}")
EOF

# 4. 未整改项确认
grep -n "repo.onDataChanged" lib/main.dart                    # 期望有命中 = 仍未改
grep -n "check_tokens.dart" tool/verify.sh                     # 期望 --strict
ls .githooks 2>/dev/null || echo "❌ .githooks 不存在（hook 未版本化）"
git config core.hooksPath || echo "❌ core.hooksPath 未设置"

# 5. CI 是否真跑过
gh run list --branch dev --limit 5

# 6. 巨型 build() 数量（当前 54）
grep -c "" lib/core/db/repositories/todo_repository.dart       # 1519 行
```

## 附录 B：本清单的证据边界（诚实声明）

- **未做真机性能基准测试** —— WAL / 索引 / 墓碑批量的收益基于查询模式推断，未实测1,000 / 5,000 / 10,000 条数据下的 P99 延迟
- **未验证 v7→v8 迁移在真机真实数据下的表现** —— 仅依赖 `migration_test.dart` 内存库测试；**建议在真机或生产数据副本上跑一次**
- **未验证 `branches: ['**']` 在 GitHub Actions 上的实际行为** —— 语法与逻辑正确，但因28 commit 未推送，**尚未实战运行**
- **`check_token_discipline.py` 白名单覆盖度为静态实测** —— 用脚本按其自身正则统计（size 263 / EdgeInsets 216，均在白名单内，白名单外 0），未考虑跨行匹配等边界
- **未审查本次未涉及的代码** —— 仅聚焦闸门逻辑与 `docs/96` 所列问题相关文件

---

> **文档结束 · 状态：待执行**
> 本清单为只读审计产出，**未修改任何项目代码，未执行任何整改动作**。
> 所有条目状态为"待执行"，需批准后逐项处理。建议执行顺序见"执行建议"章节（**第 1 项 `git push` 零成本且必须最先做**）。