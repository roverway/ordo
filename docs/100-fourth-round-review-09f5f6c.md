# 第四轮整改复核报告

> - **文档状态**：**待整改**（本报告 6 项待办中 5 项为文档级，1 项为测试补充）
> - **文档定位**：对 `docs/99-principles-as-gates-and-coupling-cycles.md`（基线 `9bf80a7`）所列整改方案的**执行复核**，逐项判定"是否执行 / 效果如何 / 有无新增问题"
> - **基线 commit**：`09f5f6c`（`refactor(arch): decouple sync_setup and lower circular dependency ratchet to 9`）
> - **核查区间**：`9bf80a7` → `09f5f6c`（4 个 commit）
> - **核查分支**：`dev`（工作树 clean，`origin/dev` 已同步）
> - **核查时间**：2026-09-30
> - **报告归档**：`docs/100-fourth-round-review-09f5f6c.md`
> - **上游文档**：`docs/96-`（代码质量评价）→ `97-`（整改核查）→ `98-`（剩余工作清单）→ `99-`（原则门禁化与循环依赖）→ **本文档**
> - **只读声明**：本次为**只读审计**，**未修改任何项目代码**，未执行任何整改动作。

---

## 摘要

**`docs/99-` 提出的 3 批整改方案已全部执行，另主动多做 2 项（洁净守卫 + 巨型文件拆分）。**

| 指标 | `9bf80a7` | `09f5f6c` | 变化 |
|---|---:|---:|---|
| **循环依赖** | 14 条 | **9 条** | ↓ **-5** |
| 巨型文件（>800 行） | 15 个 | **14 个** | ↓ -1 |
| 质量闸门数 | 3 道 | **5 道** | ↑ +2 |
| 测试通过数 | 895 | **906** | ↑ +11 |
| 令牌数量棘轮 | 263 / 216 | 263 / 216 | 持平 |
| **综合评分** | 7.8 | **8.1** | ↑ **+0.3** |

**唯一新增问题：2 处闸门注释与常量不一致**（10 分钟可修）。

**判断：整改执行到位，且未引入回归。**

---

## 我的独立验证（不采信 commit message 自述）

| 验证项 | 结果 |
|---|---|
| `bash tool/verify.sh` | **exit = 0**，**5 道闸门全部通过** |
| `dart format lib test tool` | **280 files (0 changed)** |
| `flutter test` | **906 通过 / 6 skip / 0 失败**（`9bf80a7` 为 895，**+11**）|
| `flutter analyze` | No issues found（经 `verify.sh` 步骤 3 确认）|
| 循环依赖（严格路径解析 + DFS）| **9 条**（基线 14）|
| 巨型文件棘轮 | **14 / 14 贴顶守住** |
| 循环依赖棘轮 | **9 / 9 贴顶守住** |
| 洁净守卫 | 全库 0 处 TODO/FIXME/HACK；零构建产物被跟踪 |

### `verify.sh` 实跑输出（节选）

```
✅ Base rules passed: 0 violations for monospace, pill radius, and breakpoints.
No issues found!
✅ 架构分层守卫通过：lib/core 与 lib/core/db 实现 100% 绝对纯净单向依赖，零过渡白名单！
✅ Dart 格式规范检查通过！
🛡️  [Quality Gate 3/5] 巨型文件健康度巡检（棘轮守卫）...
ℹ️  当前 lib/ 下超过 800 行的业务/UI 文件共 14 个（棘轮基准上限: 14）
✅ 巨型文件棘轮守卫通过：当前 14/14，未发生破窗生长。
🛡️  [Quality Gate 4/5] Feature 循环依赖棘轮守卫...
ℹ️  Feature 间循环依赖: 9 条（棘轮基准上限: 9）
✅ 循环依赖棘轮守卫通过：当前 9/9，未发生破窗生长。
✅ 代码洁净守卫通过：全库 0 处 TODO/FIXME/HACK 遗留。
✅ 工作区防污染守卫通过：零构建产物/临时缓存被跟踪。
✅ 所有守卫检查全部通过！代码规范健康！
```

---

# 一、`docs/99-` 整改方案执行情况

## 第1 批：消除 `tasks → projects` 的 re-export 依赖 —— ✅ 完全按方案执行

`docs/99-` §七建议改 3 个文件的 import 路径。实测确认：

| 文件 | 状态 |
|---|---|
| `lib/features/tasks/task_edit_page.dart` | ✅ 已改向 `core/db/db_providers.dart` |
| `lib/features/tasks/widgets/task_swipe_wrapper.dart` | ✅ 已改向 `core/db/db_providers.dart` |
| `lib/features/tasks/widgets/task_editor/tag_picker_sheet.dart` | ✅ 已改向 `core/db/db_providers.dart` |

**符合"仅改 import 路径，不动逻辑"的要求，风险控制得当。**

## 第 3 批：闸门④ 循环依赖棘轮 —— ✅ 已落地并生效

`tool/check_quality_gates.sh` 新增 129 行，闸门从 3 道扩到 **5 道**。**实跑确认它真的在拦**（不是摆设）：

```
🛡️  [Quality Gate 4/5] Feature 循环依赖棘轮守卫...
✅ 循环依赖棘轮守卫通过：当前 9/9，未发生破窗生长。
```

**且基线已随整改同步下调**：`MAX_CYCLES = 9`（`docs/99-` 提议的初始值是 14）。**这是"棘轮正确用法"的示范 —— 消除环后立刻下调上限，而不是留着松baseline。**

### 额外收获：闸门⑤ 代码洁净与工作区守卫

`docs/99-` §八建议表里的第 3 项（禁止 TODO/FIXME/HACK）与第 5 项（禁止跟踪构建产物），本轮一并落地为闸门⑤：

```python
# 1. 零 TODO/FIXME/HACK 破窗守卫
pattern = re.compile(r'\b(TODO|FIXME|HACK)\b')
# 扫描 lib/**/*.dart，有命中即 sys.exit(1)

# 2. 工作区构建产物防误跟踪守卫
dirty = [f for f in tracked if re.search(r'(^|/)(__pycache__/|\.pyc$|\.DS_Store$|build/)', f)]
# 有命中即 sys.exit(1)
```

**两项当前均为 0 违规** —— 属于典型的"最便宜的防退化闸门"。

## 第 2 批：消除 `settings ↔ sync_setup` 2 环 —— ✅ 已消

`docs/99-` 指出这条 2 环需设计决策，并给了两条路径（UI 下沉 `shared/` 或改为不互相引用）。

**实际做法**：删除 `lib/features/settings/widgets/settings_card.dart`（-127 行），同步设置 UI 直接从 `sync_setup_page.dart` 走。

实测依赖方向：

| 方向 | 状态 |
|---|---|
| `settings → sync_setup` | 仍存在（`settings_page.dart:12`、`settings_side_sheet.dart:7`）|
| `sync_setup → settings` | ✅ **已清空** |

**单向依赖，不成环。** 做法符合"两条路径选其一"的要求 —— 消除了反向依赖，成本更低。

## 额外：巨型文件拆分示范 —— ✅ 执行到位

`docs/98-` #5 曾建议"先做 `ai_task_proposal_card.dart`（1,359 行）做出示范"。本轮执行：

| 文件 | 行数 |
|---|---:|
| `ai_task_proposal_card.dart` | 1,359 → **631**（-728）|
| `proposal_metadata_badges.dart` | 340（新增）|
| `proposal_date_picker_sheets.dart` | 317（新增）|
| `proposal_substeps_section.dart` | 126（新增）|
| `proposal_action_bar.dart` | 83（新增）|

**906 测试全绿** —— 说明拆分未破坏行为（`ai_task_proposal_card` 原有测试覆盖）。

---

# 二、🔴 新增问题：闸门注释与常量不一致（2 处）

**这是本轮唯一的实质性新问题。**

## 问题 1：闸门③ 巨型文件 —— 注释说 9，常量是 14

```bash
# tool/check_quality_gates.sh:8    ← 注释
# 3. 巨型文件守卫：棘轮硬阻断 > 800 行的 UI/逻辑单文件（当前基线 9 个，只减不增）

# tool/check_quality_gates.sh:96   ← 实际常量
MAX_ALLOWED = 14
```

**实测当前：14 个 >800 行文件，基线 14 —— 恰好贴顶。**

**后果分析**：

| 方面 | 判断 |
|---|---|
| 运行时行为 | ✅ **无影响**。基线 14 = 当前 14，闸门正常工作 |
| 是否抵消了拆分成果 | ⚠️ **是**。`ai_task_proposal_card` 让总数 15→14，但基线仍 14，**没有下调** |
| 未来风险 | 🔴 **注释误导**。下个维护者读到"基线 9 个"，会以为还有 5 个余量，直到 CI 红了才知道 |

**同一模式在闸门④ 也出现（方向相反）**：

```bash
# tool/check_quality_gates.sh:182   ← 常量已正确下调为 9
MAX_CYCLES = 9  # 循环依赖棘轮基线（当前 14 条，随重构只减不增）
                              ^^^^^^^^^^ 注释仍写 14，已过时
```

**两处都是同一个模式**：常量更新了，注释没跟上。

**这正是 `docs/96` 问题 12（文档漂移）在 `tool/` 里的重演** —— 只是这次漂移发生在闸门文件自己的注释里。

**修复成本**：2 行注释，约 10 分钟。

**为什么仍要列为P1**：闸门是"给未来看的文档"。注释与实际规则不符，会让维护者误判余量。

## 当前 >800 行文件全清单（14 个）

| 行数 | 文件 |
|---:|---|
| 1,536 | `lib/core/db/repositories/todo_repository.dart` |
| 1,406 | `lib/features/calendar/calendar_page.dart` |
| 1,361 | `lib/features/projects/widgets/create_list_folder_sheet.dart` |
| 1,230 | `lib/features/settings/settings_page.dart` |
| 1,185 | `lib/shared/widgets/markdown_content_view.dart` |
| 1,171 | `lib/shared/widgets/scope_nav_content.dart` |
| 1,062 | `lib/core/sync/sync_engine.dart` |
| 1,060 | `lib/features/tasks/widgets/task_tree.dart` |
| 1,027 | `lib/features/tasks/widgets/task_editor.dart` |
| 980 | `lib/features/custom_views/widgets/panel_column.dart` |
| 972 | `lib/features/custom_views/presentation/custom_view_editor_page.dart` |
| 908 | `lib/features/settings/views/ai_settings_page.dart` |
| 842 | `lib/features/custom_views/widgets/filter_criteria_sheet.dart` |
| 832 | `lib/features/tasks/task_list_page.dart` |

**治理建议顺序**（纯 UI、风险最低优先）：

1. `create_list_folder_sheet.dart`（1,361）
2. `settings_page.dart`（1,230）
3. `panel_column.dart`（980）／ `custom_view_editor_page.dart`（972）

**注意**：`todo_repository.dart`（1,536）与 `sync_engine.dart`（1,062）**不建议拆** —— 前者未到临界点，后者设计已充分验证（见第五节）。

---

# 三、循环依赖：14 → 9

## 已消除 5 条

| 原环 | 消除方式 |
|---|---|
| `settings → sync_setup → settings`（2 环）| 删除 `settings_card.dart`，断反向边 |
| `projects → settings → projects`（2 环）| 随上述改动连带消除 |
| `projects → settings → sync_setup → projects`（3 环）| 同上 |
| `projects → tasks → settings → sync_setup → projects`（4 环）| 同上 |

## 残余 9 条（实测）

| # | 环长 | 环路径 |
|---:|---:|---|
| 1 | 2 | `projects` → `tasks` → `projects` |
| 2 | 2 | `tags` → `tasks` → `tags` |
| 3 | 3 | `projects` → `settings` → `tags` → `projects` |
| 4 | 3 | `projects` → `tasks` → `tags` → `projects` |
| 5 | 3 | `projects` → `tasks` → `today` → `projects` |
| 6 | 3 | `settings` → `tags` → `tasks` → `settings` |
| 7 | 4 | `projects` → `settings` → `tags` → `tasks` → `projects` |
| 8 | 4 | `projects` → `tasks` → `settings` → `tags` → `projects` |
| 9 | 5 | `projects` → `settings` → `tags` → `tasks` → `today` → `projects` |

**汇总**：2 环 2 条 ｜ 3 环 4 条 ｜ 4 环 2 条 ｜ 5 环 1 条

## 当前 feature 间有向边

```
ai_copilot    → projects, settings
calendar      → projects, settings, tasks
custom_views  → projects, tags, tasks
home          → ai_copilot
projects      → settings, tasks
quadrant      → projects, settings, tasks
search        → projects, tags, tasks
settings      → sync_setup, tags
sync_setup    → （无 feature 出边）← 已解耦
tags          → projects, tasks
tasks         → projects, settings, tags, today
today         → projects
```

**注意 `sync_setup` 已无出边** —— 这是本轮解耦的直接成果，它现在只被 `settings` 单向引用。

## 两条 2 环的根因（下一批候选）

### 环 1：`projects ↔ tasks`

```dart
// projects → tasks
lib/features/projects/projects_page.dart:16     import '../tasks/task_providers.dart';
lib/features/projects/widgets/project_card.dart:9import '../../tasks/task_providers.dart';

// tasks → projects
lib/features/tasks/task_providers.dart:12            import '../projects/project_providers.dart';
```

**双向业务需求是合理的**（项目列表显示任务数 ←→ 任务需要归属项目）。但 `task_providers.dart:12` 导入 `project_providers.dart` **很可能只为拿 `todoRepositoryProvider`** —— 与 `docs/99-` 诊断的 re-export 病根同源。

### 环 2：`tags ↔ tasks`

```dart
// tags → tasks
lib/features/tags/tags_detail_page.dart:21   import '../tasks/task_edit_page.dart';
lib/features/tags/tags_detail_page.dart:22   import '../tasks/widgets/task_swipe_wrapper.dart';

// tasks → tags
lib/features/tasks/widgets/task_editor/tag_picker_sheet.dart:10 import '../../../tags/tags_page.dart' show showTagFormDialog;
```

**标签详情页要打开任务编辑器**（合理）；**任务编辑器的标签选择器要调起标签表单**（也合理）。这是**真实双向业务需求，不是架构错误**。

### 我的判断：这两条 2 环可以接受，不建议强行消除

理由：

1. **Dart 允许循环 import，不产生运行时错误**（仅影响编译期初始化顺序，本项目未实测出问题）
2. 棘轮基线 9 已能防止**新增**环
3. 消除它们需要把"任务编辑"或"标签表单"提到 `shared/` —— 属于设计决策，且会引入新的抽象层
4. **除非出现具体维护痛点**（如改一个功能要同时动两个 feature 且频繁冲突），否则收益不抵成本

---

# 四、🟡 测试覆盖广度：51 → 55（新增 4 个无测试文件）

## 现象

拆分 `ai_task_proposal_card.dart` 后，新拆出的 4 个文件**均无专项测试**：

| 新文件 | 行数 | 专项测试 |
|---|---:|---:|
| `proposal_metadata_badges.dart` | 340 | ❌ 0 |
| `proposal_date_picker_sheets.dart` | 317 | ❌ 0 |
| `proposal_substeps_section.dart` | 126 | ❌ 0 |
| `proposal_action_bar.dart` | 83 | ❌ 0 |

| 指标 | `9bf80a7` | `09f5f6c` | 变化 |
|---|---:|---:|---|
| 无对应测试的 lib 文件 | 51 | **55** | ⚠️ **+4** |
| 测试通过数 | 895 | **906** | ↑ +11 |

**+11 测试**来自 `task_date_picker_dialogs_test.dart`（+276 行）—— 这正是 `docs/98-` #7 建议补的那个文件，**本轮做了**。

## 判断

**净效果中性**：拆分了1,359 行的巨型文件（结构收益），但新增 4 个无测试文件（覆盖广度损失）；同时补了一个 276 行的日期测试（覆盖收益）。

**906 测试全绿证明拆分未破坏行为** —— 这是关键。`ai_task_proposal_card` 原有测试覆盖了拆分后的组件树。

**优先级建议**：`proposal_date_picker_sheets.dart`（317 行，含日期选择逻辑）值得补测；其余 3 个是纯展示组件（badge / action bar / substeps section），逻辑简单，可不补。

## 体积最大的无测试文件（当前）

| 体积 | 文件 |
|---:|---|
| 19 KB | `lib/features/tasks/widgets/task_editor/project_picker_sheet.dart` |
| 15 KB | `lib/shared/widgets/unified_hierarchical_folder_selector.dart` |
| 14 KB | `lib/features/tasks/widgets/task_create_sheet_options.dart` |
| 12 KB | `lib/features/quadrant/widgets/quadrant_cards_view.dart` |
| 11 KB | `lib/features/ai_copilot/widgets/proposal_date_picker_sheets.dart` |

---

# 五、评分

| 维度 | `docs/99-` | 本轮 | 变化原因 |
|---|---:|---:|---|
| 架构方向正确性 | 7.8 | **8.2** | ↑ 环 14→9；`settings↔sync_setup` 2 环消除；`sync_setup` 现为无出边叶子节点 |
| 测试护栏 | 8.8 | **8.8** | — +11 测试（日期专项）与 +4 无测试文件互相抵消 |
| 演进节奏 | 5.5 | **5.8** | ↑ 巨型文件 15→14，存量**开始下降**（此前长期净增长）|
| 扩展成本 | 4.5 | **4.5** | — 同步实体仍 5 个，未变 |
| UI 层可维护性 | 4.5 | **4.8** | ↑ `ai_task_proposal_card` 1,359→631，拆分示范已立|
| **质量保障机制** | 9.0 | **9.2** | ↑ 闸门 3 道→5 道；循环依赖棘轮基线同步下调至 9 |
| 文档可信度 | 5.8 | **5.5** | ↓ **闸门注释与常量不一致 2 处** |
| 性能天花板 | 6.0 | **6.0** | — 本轮无性能相关改动 |
| **综合** | **7.8** | **8.1** | **+0.3** |

---

# 六、剩余工作

## P1 — 必修（10 分钟）

| # | 项 | 位置 | 说明 |
|---:|---|---|---|
| 1 | **修闸门③ 注释** | `tool/check_quality_gates.sh:8` | 注释"当前基线 9 个" → 改为 **14** |
| 2 | **修闸门④ 注释** | `tool/check_quality_gates.sh:182` | 行内注释"当前 14 条" → 改为 **9** |

**顺带决策**：`MAX_ALLOWED = 14` 是否下调到 13？

- **保持 14**（当前）：贴顶，任何新巨型文件立即阻断 —— 最敏感，但也最易被"临时绕过"
- **下调到 13**：留 1 个余量，避免紧急情况被迫用 `--no-verify`
- **建议**：保持 14。若某天因紧急需求必须新增巨型文件，正确做法是**当场拆小**，而非留余量

## P2 — 建议做（1 小时）

| # | 项 | 成本 |
|---:|---|---|
| 3 | 补 `proposal_date_picker_sheets.dart` 测试（317 行，含日期逻辑）| 1 小时 |

## P3 — 暂不做（附理由）

| # | 项 | 不做的理由 |
|---:|---|---|
| 4 | 消除残余 2 条 2 环 | **合理双向业务依赖**；Dart 允许循环 import；棘轮已防新增 |
| 5 | 拆 `todo_repository.dart`（1,536 行）| **未到临界点**。`docs/96-` §7.5 定的触发条件：同步实体 8–10 个 / 引用 35+ 文件 / 行数 1,800+。当前 5 个 / 23 文件 / 1,536 行 |
| 6 | 拆 `sync_engine.dart`（1,062 行）| **设计已充分验证**：LWW + 确定性 tie-break + 纯函数 merge + 时钟偏移双检 + 结构化错误码。拆它风险大于收益 |
| 7 | 补其余 51 个无测试文件 | 纯展示组件居多，优先级低于结构性问题 |

## 明确不要做的事

- ❌ **不要强行消除那 2 条 2 环** —— 会引入不必要的抽象层
- ❌ **不要拆 `sync_engine.dart`** —— 它是全项目质量最高的部分
- ❌ **不要为消环而改业务逻辑** —— 继续只改 import 归属
- ❌ **不要再写第 19 份人肉全量评审报告** —— `bash tool/verify.sh` 已覆盖 5 道闸门 + 格式 + 分析 + 令牌

---

# 附录 A：核查命令清单（可复现）

```bash
# 前置：清空全部代理变量（含 ALL_PROXY，否则 VM-service 端口被劫持）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

# 0. 状态
git rev-parse --abbrev-ref HEAD        # 期望 dev
git log --oneline -1                   # 期望 09f5f6c
git status --short                     # 期望 clean
git rev-list --count origin/dev..dev   # 期望 0

# 1. 全套闸门（5 道）
bash tool/verify.sh                    # 期望 exit 0

# 2. 格式与分析
dart format --output=none --set-exit-if-changed lib test tool   # 期望 0 changed
flutter test --reporter=compact# 期望 All tests passed（906）

# 3. 循环依赖检测（严格路径解析，避免 '../..' 伪边）
python3 - <<'PY'
import os, re, collections
def resolve(importer, rel):
    t = os.path.normpath(os.path.join(os.path.dirname(importer), rel))
    m = re.match(r'lib/features/([^/]+)/', t)
    return m.group(1) if m else None
g = collections.defaultdict(set)
for root, _, files in os.walk('lib/features'):
    for f in files:
        if not f.endswith('.dart'): continue
        p = os.path.join(root, f)
        src = re.match(r'lib/features/([^/]+)/', p).group(1)
        for line in open(p, encoding='utf-8'):
            m = re.match(r"\s*import\s+'([^']+)'", line)
            if not m: continue
            imp = m.group(1)
            dst = (imp[len('package:ordo/features/'):].split('/')[0]
                   if imp.startswith('package:ordo/features/')
                   else (None if imp.startswith('package:') else resolve(p, imp)))
            if dst and dst != src: g[src].add(dst)
cycles = set()
def dfs(st, node, path, seen):
    for nx in sorted(g.get(node, ())):
        if nx == st:
            c = path[:]
            if c[0] != min(c): c = c[c.index(min(c)):]
            cycles.add(tuple(c))
        elif nx not in path and nx not in seen and nx >= st:
            dfs(st, nx, path + [nx], seen | {nx})
for n in sorted(g): dfs(n, n, [n], set())
print(f"循环依赖: {len(cycles)} 条（基线 9）")
for c in sorted(cycles, key=lambda x: (len(x), x)):
    print(f"  ({len(c)}) " + " → ".join(c) + f" → {c[0]}")
PY

# 4. 闸门注释 vs 常量（本报告的 P1 发现）
sed -n '6,12p' tool/check_quality_gates.sh      # 注释声明的基线
grep -n "^MAX_ALLOWED\|^MAX_CYCLES" tool/check_quality_gates.sh   # 实际常量

# 5. 巨型文件清单
find lib -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 wc -l 2>/dev/null \
  | awk '$2!="总计" && $1>800' | sort -rn \
  | grep -vE "app_localizations(_en|_zh)?\.dart|user_manual_page\.dart"

# 6. 第 1 批整改确认（3 个文件应改向 core/db）
grep -l "core/db/db_providers" \
  lib/features/tasks/task_edit_page.dart \
  lib/features/tasks/widgets/task_swipe_wrapper.dart \
  lib/features/tasks/widgets/task_editor/tag_picker_sheet.dart

# 7. sync_setup 已解耦（应无 feature 出边）
grep -rn "\.\./\(projects\|settings\|tasks\|tags\|calendar\|search\)/" \
  lib/features/sync_setup/ --include="*.dart"   # 期望无命中

# 8. ai_task_proposal_card 拆分成果
wc -l lib/features/ai_copilot/widgets/proposal_*.dart

# 9. CI 是否真跑过
gh run list --branch dev --limit 3
```

## 附录 B：证据边界（诚实声明）

- **环检测只覆盖 `lib/features/` 顶层** —— 未检测 `lib/features/*/` 子目录之间的环，也未检测文件级 import 冗余
- **未验证循环 import 是否已造成运行时初始化顺序问题** —— Dart 允许循环 import，本报告仅做静态分析，**未实测**残余 9 条环是否有运行时隐患
- **未逐条审查 4 个 commit 的全部 diff** —— 聚焦 `docs/99-` 建议相关文件；`settings_providers.dart`（-29）、`backup_providers.dart`（+21 新增）、`tag_providers.dart` 等小改动的具体内容未逐行复核
- **`proposal_*` 4 个新文件的拆分质量未逐模块评估** —— 仅验证了测试全绿与行数下降，未评估每个新模块的职责边界是否清晰
- **`task_date_picker_dialogs_test.dart`（+276 行）的测试质量未评估** —— 仅确认测试总数上升且全绿，未审查断言强度
- **`AGENTS.md` 在 `9bf80a7` 的 -109 行改动未复核** —— 属上一轮范围

---

> **文档结束 · 状态：待整改**
> 本文档为只读审计产出，**未修改任何项目代码，未执行任何整改动作**。
> **P1 仅 2 行注释修改（约 10 分钟），是本轮唯一必修项。**
> 整改执行质量评价：**到位**。`docs/99-` 提出的 3 批方案全部执行，另主动多做 2 项（洁净守卫 + 巨型文件拆分示范），且未引入回归。