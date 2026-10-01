# 编程原则的Quality Gate 化与循环依赖实测

> - **文档状态**：**待整改**
> - **文档定位**：回答"编程原则（如高聚合、低耦合）能否用质量门禁约束"，并给出 `lib/features/` **循环依赖的实测结果与整改方案**
> - **基线**：`dev` @ `9bf80a7`（`refactor(core): decouple onDataChanged with DataChangeObserver interface and lock CI flutter version`）
> - **工作树状态**：clean ｜ `origin/dev` 已同步（未推送 0 commit）
> - **上游文档**：`docs/96-`（代码质量评价）、`docs/97-`（整改核查）、`docs/98-`（剩余工作清单）
> - **产出时间**：2026-09-30
> - **报告归档**：`docs/99-principles-as-gates-and-coupling-cycles.md`
> - **只读声明**：本次为**只读审计**，**未修改任何项目代码**，未执行任何整改动作。

---

## 摘要

**核心发现：`lib/features/` 存在 14 条真实的循环依赖（circular dependencies）。**

**并且我必须先更正自己在 `docs/96` 中写下的一个错误结论。**

| 项 | 内容 |
|---|---|
| **结论一** | 编程原则**只有一半能门禁化** —— 有客观机器信号的能，"高内聚"这类依赖意图判断的**不能**，用力门禁反而会被绕过 |
| **结论二** | **`docs/96` §7.3 我写的"没有 A↔B 互指环"是错的**。实测**14 条环**，其中 4 条是长度 2 的直接互指环 |
| **结论三** | 根因是 `lib/features/projects/project_providers.dart:6-7` 的 **re-export**，让 11 个 `tasks/` 文件为拿一个 provider 而依赖整个 `features/projects` |
| **结论四** | 我对 `check_tokens.dart` "恒真断言"的批评**不成立**，已在下文更正 |
| **整改状态** | `docs/98-` 提出的4 项 P1 **已全部完成**；**循环依赖是唯一剩余的架构级发现** |

---

## 我的独立验证（`9bf80a7` 实测）

| 验证项 | 结果 |
|---|---|
| `bash tool/verify.sh` | **exit = 0**，6 道闸门全通过 |
| `dart format lib test tool` | 0 changed |
| `flutter test` | **895 通过 / 6 skip / 0 失败**（`docs/98` 时为 892，**+3**）|
| 令牌棘轮 | `size ≤ 263`、`EdgeInsets ≤ 216`（**真数量预算**，非路径白名单）|
| 巨型文件棘轮 | 15 / 15 贴顶守住 |
| **循环依赖** | **14 条**（严格路径解析 + DFS 枚举）|

---

# 第一部分：编程原则能否 Quality Gate 化

## 一、可以门禁化的（有客观机器信号）

这些原则都能归结为**对代码文本的确定性判断**，没有主观空间：

| 原则 | 判定方法 | 本项目现状 |
|---|---|---|
| **分层不被倒置** | import 方向图 | ✅ **已有闸门**（core→features、db→sync 零容忍）|
| **无循环依赖** | DFS / 拓扑排序找环 | ❌ **未做，实测 14 条环** |
| **文件体积上限** | 行数阈值 | ✅ **已有棘轮**（>800 行 ≤ 15）|
| **设计令牌统一** | 正则匹配裸值 | ✅ **已有真数量棘轮**（`9bf80a7` 完成）|
| **无遗留标记** | TODO/FIXME 计数 | ❌ 未做（当前 0 个，可加零容忍防退化）|
| **死代码** | 引用图入度 = 0 | ❌ 未做 |
| **i18n 完整** | ARB key 与硬编码文案对账 | ❌ 未做 |
| **迁移正确性** | 每版本迁移测试 | ✅ **已有**（705 + 174 行）|
| **测试存在性** | 文件名 / 引用反查 | ❌ 未做（51 个文件无测试）|
| **依赖注入倒置** | 禁用可变字段注入 | ✅ **已有**（`DataChangeObserver` 接口，`9bf80a7`）|

## 二、不能门禁化的（无机器信号）

| 原则 | 为什么不能 |
|---|---|
| **高内聚** | 内聚度衡量"一起变化的代码是否放在一起"。**"是否会一起变化"是意图，不在代码里** —— 只能靠人或 AI 读语义判断 |
| **命名是否达意** | `Text(flagLabel)` 叫 `flagLabel` 还是 `l` 都能通过所有门禁 |
| **抽象是否合理** | 该抽接口还是直接调用，是设计判断 |
| **错误处理是否得当** | 有 `catch` 不等于处理得当 |
| **性能是否够用** | 门禁只能查形状（有无索引），查不出实际耗时 |
| **"该不该拆这个类"** | 1,519 行的 `TodoRepository` 是否该拆，取决于同步实体数量这类**产品演进节奏** |

**这一类只能靠三样东西**：code review、测试、文档约定。**门禁在这里是无效的，用力门禁反而会被绕过。**

## 三、最关键的洞察：「能测」和「有用」是两件事

### 反面教材：`check_token_discipline.py` 的两轮演进

**第1～3 轮（`46bfe91`～`62e1197`）**：它是**路径白名单**（111 条硬编码路径永久豁免），文件头写着 "Ratchet Pattern" 但实现不是棘轮。

**后果**：`task_row.dart` 等 111 个文件被永久冻结，它们承载了**全部 479 处存量违规**。给这些文件加 `size: 999`，闸门永远绿灯。**一道绿色的门禁，零实际拦截力。**

**第 4 轮（`9bf80a7`）**：改为**真数量预算**：

```python
MAX_SIZE_BUDGET = 263
MAX_EDGE_BUDGET = 216
# 统计全部违规（含豁免文件），超预算即 sys.exit(1)
```

**这次是真棘轮** —— 清理任一老文件即自动降预算，不需改闸门代码；冻结区无法恶化。

### 门禁有效的三个必要条件

| 条件 | 说明 | 正例（巨型文件棘轮、令牌数量棘轮） | 反例（令牌路径白名单） |
|---|---|---|---|
| **1. 覆盖真实违规** | 规则要匹配**实际发生的问题** | ✅ 基线 263/216 是真实违规数 | ❌ 守的是本来就没问题的角落 |
| **2. 存量用棘轮、增量零容忍** | 不能因"存量太多"就放弃约束 | ✅ 只减不增 | ❌ 豁免区可无限恶化 |
| **3. 有升级路径** | 存量清理要能自动降预算 | ✅ 改一个数字 | ❌ 需手动改代码 |

**三个条件缺一个，门禁就会退化成"永远绿的摆设"。**

### ⚠️ 需要更正：我的另一处批评也不成立

我在 `docs/97` 第三节写过：`check_tokens.dart` 是"**恒真断言**"。

**这个批评是错的。** 该工具 6 条规则（`fontSize:` / `Color(0x` / `withValues(alpha:` / `Radius.circular(` / `monospace` / `Duration(milliseconds:`）**确实是真正清零了** —— 这些特定模式已被清理干净，所以 `--strict` 是恰当的。`9bf80a7` 也同步重写了它的注释以反映这一点。

**我的错误来源**：我统计"裸数字"时用的是 `\b(fontSize|size|elevation|radius|...)\s*:\s*\d+` 这种**宽口径**，包含了 `size:` / `elevation:` / `spacing:` / `BorderRadius.circular` —— 而这些**恰好由 `check_token_discipline.py` 的数量棘轮覆盖**（`size ≤ 263` / `EdgeInsets ≤ 216`）。

**两套闸门覆盖面不重叠，合起来是完整的。** 我把"宽口径统计出的存量"错当成了"另一套窄口径规则的未清零项"。

---

# 第二部分：`docs/96` 结论更正与循环依赖实测

## 四、⚠️ 更正：`docs/96` §7.3 的"没有 A↔B 互指环"是错的

### 我当时怎么错的

`docs/96` §7.3 我写过：

> **没有 A↔B 互指环。**
> ...这种非对称说明依赖方向是**被主动维护的**...

**我的判断依据是边数统计**：

```
tasks    → projects  11
projects → tasks      2      ← 看到不对称，我据此下结论"无环"
```

**"边数不对称" ≠ "无环"** —— 环可以横跨 3～4 个 feature，而我用的指标对多跳环完全不敏感。**这是"用错误指标下结论"的典型案例。**

### 两次数字修正

| 我的报告 | 报的环数 | 实际情况 |
|---|---:|---|
| `docs/96` §7.3 | **0 条** | ❌ 错 |
| 上一轮口头汇报 | 6 条 | ❌ 仍错（正则有bug，产生了 `..` 伪边）|
| **本文档（严格路径解析）** | **14 条** | ✅ 正确 |

第二次错误的原因：我的正则 `import\s+'(\.\./)+([^/']+)/'` 在遇到 `../../core/` 这类路径时，把 `..` 误当成了 feature 名，产生了伪边并污染了图。

**修正方法**：改为把每个 import 路径用 `os.path.normpath` 解析成绝对路径，再匹配 `lib/features/([^/]+)/`。

---

## 五、循环依赖实测：14 条

### 完整清单（按环长排序）

| # | 环长 | 环路径 |
|---:|---:|---|
| 1 | 2 | `projects` → `settings` → `projects` |
| 2 | 2 | `projects` → `tasks` → `projects` |
| 3 | 2 | `settings` → `sync_setup` → `settings` |
| 4 | 2 | `tags` → `tasks` → `tags` |
| 5 | 3 | `projects` → `settings` → `sync_setup` → `projects` |
| 6 | 3 | `projects` → `settings` → `tags` → `projects` |
| 7 | 3 | `projects` → `tasks` → `settings` → `projects` |
| 8 | 3 | `projects` → `tasks` → `tags` → `projects` |
| 9 | 3 | `projects` → `tasks` → `today` → `projects` |
| 10 | 3 | `settings` → `tags` → `tasks` → `settings` |
| 11 | 4 | `projects` → `settings` → `tags` → `tasks` → `projects` |
| 12 | 4 | `projects` → `tasks` → `settings` → `sync_setup` → `projects` |
| 13 | 4 | `projects` → `tasks` → `settings` → `tags` → `projects` |
| 14 | 5 | `projects` → `settings` → `tags` → `tasks` → `today` → `projects` |

**汇总**：2 环 **4 条** ｜ 3 环 **6 条** ｜ 4 环 **3 条** ｜ 5 环 **1 条**

### 4 条 2 环的精确证据

```dart
// 环 3：settings ↔ sync_setup
lib/features/settings/settings_page.dart:12          import '../../features/sync_setup/sync_setup_providers.dart';
lib/features/sync_setup/sync_setup_providers.dart:30 import '../settings/settings_providers.dart';

// 环 2：projects ↔ tasks
lib/features/projects/projects_page.dart:16          import '../tasks/task_providers.dart';
lib/features/projects/widgets/project_card.dart:9    import '../../tasks/task_providers.dart';
lib/features/tasks/task_providers.dart:12            import '../projects/project_providers.dart';

// 环 1：projects ↔ settings
lib/features/settings/settings_providers.dart:10     import '../projects/project_providers.dart';
lib/features/projects/widgets/create_list_folder_sheet.dart:14 import '../../settings/settings_providers.dart';

// 环 4：tags ↔ tasks
lib/features/tags/tags_detail_page.dart:21           import '../tasks/task_edit_page.dart';
lib/features/tasks/widgets/task_editor/tag_picker_sheet.dart:10 import '../../../tags/tags_page.dart' show showTagFormDialog;
```

---

## 六、根因：`project_providers.dart` 是一个「万能入口」

### 问题所在

`lib/features/projects/project_providers.dart:6-7`：

```dart
export '../../core/db/db_providers.dart'
    show todoRepositoryProvider, TodoRepository, inboxProjectId;
```

**这个 re-export 让 `features/projects` 成了通往 `core` 数据层的"中转站"。**

后果：**11 个 `tasks/` 文件为了拿一个 `todoRepositoryProvider`，必须 import 整个 `features/projects`**（162 行，含 6 个 provider + 文件夹展开状态）。

### 逐文件实测：多数文件根本不需要 `projects` 的任何符号

| 文件（相对 `lib/features/tasks/`）| 用 repo 符号 | 用 projects 符号 | 能否直接改 import |
|---|---:|---:|---|
| `task_edit_page.dart` | 3 | **0** | ✅ **可改** |
| `widgets/task_swipe_wrapper.dart` | 4 | **0** | ✅ **可改** |
| `widgets/task_editor/tag_picker_sheet.dart` | 2 | **0** | ✅ **可改** |
| `widgets/task_create_sheet_options.dart` | 0 | 1 | ⚠️ 保留 |
| `widgets/task_create_sheet.dart` | 2 | 1 | ⚠️ 保留 |
| `widgets/task_tree.dart` | 11 | 1 | ⚠️ 保留 |
| `widgets/quick_capture_bar.dart` | 6 | 1 | ⚠️ 保留 |
| `task_list_page.dart` | 5 | 3 | ⚠️ 保留 |
| `task_providers.dart` | 6 | 2 | ⚠️ 保留 |
| `widgets/task_editor.dart` | 0 | 3 | ⚠️ 保留 |
| `widgets/task_editor/project_picker_sheet.dart` | 7 | 4 | ⚠️ 保留 |

**3 个文件（`repo > 0` 且 `projects = 0`）可以立刻把import 从 `../projects/project_providers.dart` 改为 `../../core/db/db_providers.dart`** —— 这会直接消除 `tasks → projects` 这条边，从而**一次性消掉 6 条环**（环 2、7、8、9、11、13 中的相关项）。

### 根边分析：切断哪条边消掉最多环

我逐条模拟了删除每条边后的环数：

| 切断的边 | 消除环数 | 剩余环数 |
|---|---:|---:|
| **`projects` → `tasks`** | **6** | 8 |
| `projects` → `settings` | 5 | 9 |
| `settings` → `tags` | 5 | 9 |
| `tags` → `tasks` | 4 | 10 |
| `tasks` → `settings` | 4 | 10 |
| `settings` → `sync_setup` | 3 | 11 |

**注意**：这张表反映的是"删哪条边最省事"，**不代表应该那样做**。`projects → tasks` 消除环最多，但 `projects_page.dart` 和 `project_card.dart` 导入 `task_providers.dart` 往往是**合理的业务依赖**（项目列表要显示任务数）。

**真正的根因是re-export**，而不是任何单条业务边。

---

## 七、给编码 agent 的整改方案

### 分3 批，每批独立可提交，每批跑一次 `verify.sh` + `flutter test`

#### 第 1 批：消除 `tasks → projects` 的re-export 依赖（低风险，建议先做）

**动作**：改 3 个文件的 import：

```dart
// lib/features/tasks/task_edit_page.dart:25
- import '../projects/project_providers.dart';
+ import '../../core/db/db_providers.dart';

// lib/features/tasks/widgets/task_swipe_wrapper.dart:10
- import '../../projects/project_providers.dart';
+ import '../../../core/db/db_providers.dart';

// lib/features/tasks/widgets/task_editor/tag_picker_sheet.dart:8
- import '../../../projects/project_providers.dart';
+ import '../../../../core/db/db_providers.dart';
```

**注意**：`tag_picker_sheet.dart:10` 还导入了 `../../../tags/tags_page.dart`（用 `showTagFormDialog`），那一条**保留**（它是 `tasks → tags` 边，与本次改动无关）。

**预期效果**：`tasks → projects` 边消失（当且仅当这 3 个文件是唯一不需 projects 符号的），消除 **6 条环**。

**风险**：低。仅改import 路径，符号来源不变（`db_providers.dart` re-export 了同样的符号）。

#### 第 2 批：消除 `settings ↔ sync_setup` 2 环（中风险）

**问题**：
```dart
// settings → sync_setup（2 处）
lib/features/settings/settings_page.dart:12          import '../../features/sync_setup/sync_setup_providers.dart';
lib/features/settings/widgets/settings_side_sheet.dart:7 import '../../sync_setup/sync_setup_page.dart';

// sync_setup → settings（2 处）
lib/features/sync_setup/sync_setup_page.dart:31      import '../settings/widgets/settings_card.dart';
lib/features/sync_setup/sync_setup_providers.dart:30 import '../settings/settings_providers.dart';
```

**方案**：把同步设置的 UI（`settings_card.dart`、`sync_setup_page.dart`）下沉到 `lib/shared/`，或让 `settings` 不直接引用 `sync_setup`（改为路由跳转 / 注入回调）。

**⚠️ 这需要设计判断 —— 门禁帮不上忙。** 两条路径各选其一即可，不必都改。

#### 第 3 批：加入循环依赖棘轮闸门（必须做）

见第八节。

### 明确不建议

- ❌ **不要一次性消掉 14 条环** —— 环有重叠，改 1 条边常顺带消多条。按批推进，每批跑测试。
- ❌ **不要为了消环而改变业务逻辑** —— 只改 import 归属，不动逻辑。
- ❌ **不要把 `projects_page.dart → task_providers.dart` 改掉** —— 那是合理业务依赖，消环应从 re-export 入手。

---

## 八、建议新增的门禁

### 🟢 闸门④：循环依赖棘轮（最高优先级）

与巨型文件棘轮**完全同构**，可直接复制其模式：

```bash
# 追加到 tool/check_quality_gates.sh 作为闸门④
echo "🛡️  [Quality Gate 4/4] feature 循环依赖棘轮..."
python3 - << 'EOF'
import os, re, collections, sys

def resolve(importer, rel):
    t = os.path.normpath(os.path.join(os.path.dirname(importer), rel))
    m = re.match(r'lib/features/([^/]+)/', t)
    return m.group(1) if m else None

g = collections.defaultdict(set)
for root, _, files in os.walk('lib/features'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f)
        src = re.match(r'lib/features/([^/]+)/', p).group(1)
        for line in open(p, encoding='utf-8'):
            m = re.match(r"\s*import\s+'([^']+)'", line)
            if not m:
                continue
            imp = m.group(1)
            if imp.startswith('package:ordo/features/'):
                dst = imp[len('package:ordo/features/'):].split('/')[0]
            elif imp.startswith('package:'):
                continue
            else:
                dst = resolve(p, imp)
            if dst and dst != src:
                g[src].add(dst)

cycles = set()
def dfs(start, node, path, seen):
    for nxt in sorted(g.get(node, ())):
        if nxt == start:
            c = path[:]
            if c[0] != min(c):
                c = c[c.index(min(c)):]
            cycles.add(tuple(c))
        elif nxt not in path and nxt not in seen and nxt >= start:
            dfs(start, nxt, path + [nxt], seen | {nxt})
for n in sorted(g):
    dfs(n, n, [n], set())

MAX_CYCLES = 14          # 棘轮基线：当前 14，只减不增
print(f"ℹ️  feature 循环依赖: {len(cycles)} 条（棘轮上限 {MAX_CYCLES}）")
for c in sorted(cycles, key=lambda x: (len(x), x)):
    print(f"   ({len(c)}) " + " → ".join(c) + f" → {c[0]}")
if len(cycles) > MAX_CYCLES:
    print(f"\n❌ [棘轮违规] 循环依赖 {len(cycles)} > 上限 {MAX_CYCLES}，禁止新增")
    sys.exit(1)
print(f"✅ 循环依赖棘轮守卫通过：{len(cycles)}/{MAX_CYCLES}")
EOF
```

**收益**：
- 立即生效（基线 14 = 当前值，不会红）
- 每消除一条环就把 `MAX_CYCLES` 下调 1
- **防止新增环** —— 这是"低耦合"唯一能真正被机械约束的部分

### 🟢 其他低成本门禁

| # | 门禁 | 实现要点 | 成本 |
|---:|---|---|---|
| 2 | **fan-out 上限棘轮** | 单 feature 依赖 feature 数 ≤ 4（当前 `tasks`=4 最高）| 20 分钟 |
| 3 | **禁止 TODO/FIXME/HACK** | 计数 > 0 即失败（**当前 0 个，最便宜的防退化闸门**）| 10 分钟 |
| 4 | **禁止未引用 public 符号** | 引用图入度 = 0 | 40 分钟 |
| 5 | **禁止跟踪构建产物** | 检查 `build/` `__pycache__/` 是否被 git 跟踪 | 15 分钟 |

### 🔴 必须人来做（门禁无效）

- **高内聚** —— 意图不在代码里
- **第 2 批的消环决策**（`settings ↔ sync_setup` 该往哪拆）—— 设计判断

---

## 九、评分调整

| 维度 | `docs/98` | 本文档 | 原因 |
|---|---:|---:|---|
| 架构方向正确性 | 8.5 | **7.8** | ↓ **`docs/96` "无环"结论被证伪，实测 14 条环**（其中 4 条为直接互指环）|
| 测试护栏 | 8.7 | **8.8** | ↑ 895 测试（`+3`，含 `DataChangeObserver` 专项 87 行）|
| 演进节奏 | 5.5 | **5.5** | — 存量未减 |
| 扩展成本 | 4.5 | **4.5** | — 同步实体仍 5 个 |
| UI 层可维护性 | 4.5 | **4.5** | — |
| **质量保障机制** | 8.2 | **9.0** | ↑↑ **`docs/98` 的 4 项 P1 全部完成**：令牌真数量棘轮、hook 版本化、`check_tokens` 文档对齐、`DataChangeObserver` 接口 |
| 文档可信度 | 5.8 | **5.8** | — |
| 性能天花板 | 6.0 | **6.0** | — |
| **综合** | **8.0** | **7.8** | 门禁体系大幅提升，但架构分因环下调 |

**说明**：门禁维度涨了 0.8，架构维度掉了 0.7，净效果 −0.2。**这正是"质量门禁化"的真实价值 —— 它把不可见的问题（环）暴露了出来。** 如果没有这轮门禁建设，14 条环可能还要再过半年才会被发现。

---

## 十、`docs/98-` 待办完成情况核对

| # | `docs/98` 待办 | 状态 | 证据 |
|---:|---|---|---|
| 🔴 | `git push origin dev` | ✅ **完成** | 未推送 0 commit，`origin/dev @ 9bf80a7` |
| #1 | 令牌白名单 → 真数量棘轮 | ✅ **完成** | `MAX_SIZE_BUDGET = 263`、`MAX_EDGE_BUDGET = 216` |
| #2 | `check_tokens.dart` 二选一 | ✅ **完成** | 注释重写为"已达成清零，`--strict` 常驻"，规则未变 |
| #3 | hook 版本化 + 减重 | ✅ **完成** | `.githooks/pre-commit`（744 B）已入库；`tool/install_hooks.sh` 同步更新 |
| #4 | `onDataChanged` 接口化 | ✅ **完成** | `lib/core/db/data_change_observer.dart` + `DataChangeObserver` 接口 + 87 行专项测试；`main.dart` 已无裸赋值 |
| #5 | 拆 `ai_task_proposal_card.dart` | ⬜ 未做 | 仍 1,359 行 |
| #6 | `build()` 棘轮 | ⬜ 未做 | 仍 54 个 ≥100 行 |
| #7 | 补 `task_date_picker_dialogs.dart` 测试 | ⬜ 未做 | — |
| #8 | 拆 `TodoRepository` | ⬜ 未做（**不建议**） | 仍 1,519 行，未到临界点 |

**`docs/98` 的 4 项 P1 + 1 项最高优先级，全部完成。**

**本轮新增的发现（`9bf80a7` 之后）**：14 条循环依赖。

---

# 附录 A：核查命令清单（可复现）

```bash
# 前置
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

# 0. 状态
git rev-parse --abbrev-ref HEAD        # 期望 dev
git status --short                     # 期望 clean
git rev-list --count origin/dev..dev   # 期望 0

# 1. 全套闸门
bash tool/verify.sh                    # 期望 exit 0
flutter test --reporter=compact# 期望 All tests passed

# 2. 循环依赖检测（严格路径解析，避免 '../..' 伪边）
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
print(f"循环依赖: {len(cycles)} 条")
for c in sorted(cycles, key=lambda x: (len(x), x)):
    print(f"  ({len(c)}) " + " → ".join(c) + f" → {c[0]}")
PY

# 3. 根因：project_providers 的 re-export
head -8 lib/features/projects/project_providers.dart

# 4. tasks→projects 逐文件符号需求（判断哪些 import 可直接改）
grep -rl "\.\./projects/\|features/projects/" lib/features/tasks/ --include="*.dart"

# 5. 确认 docs/98 的 P1 已完成
grep -n "MAX_SIZE_BUDGET\|MAX_EDGE_BUDGET" tool/check_token_discipline.py
ls .githooks/
grep -n "check_tokens.dart" tool/verify.sh
cat lib/core/db/data_change_observer.dart
grep -n "onDataChanged" lib/main.dart      # 期望无裸赋值
```

## 附录 B：证据边界（诚实声明）

- **环检测只覆盖 `lib/features/` 顶层** —— 未检测 `lib/features/*/` 子目录之间的环，也未检测文件级循环（同一文件内无环概念）
- **环的"严重程度"未做定性评估** —— 本文档只客观列出 14 条环与根因，**"该不该拆、往哪拆"是设计判断，本文档不越权代做**
- **未验证 `import` 是否有 unused** —— 部分跨 feature import 可能实际未被使用（未用到的 import 只会造成无谓的环），本检测不区分"真依赖"与"冗余 import"
- **未做运行时验证** —— 14 条环在Dart 中**不会导致运行时错误**（Dart 允许循环 import），只影响可维护性与编译期初始化顺序；本报告未实测是否已造成初始化顺序问题
- **`docs/96` §7.3 的其他结论未重审** —— 仅更正"无环"这一条；"非对称说明依赖方向被主动维护"的推论虽基于错误前提，但 feature 间**确实没有 A↔B 全对称泛滥**，该观察仍部分成立
- **未审查 `9bf80a7` 的全部 diff** —— 聚焦 `docs/98` 待办相关文件；`AGENTS.md` -109 行的内容变更未逐条复核

---

> **文档结束 · 状态：待整改**
> 本文档为只读审计产出，**未修改任何项目代码，未执行任何整改动作**。
> 建议顺序：**第 1 批（3 个文件改 import）→ 第 3 批（加闸门④ 棘轮）→ 第 2 批（消 `settings ↔ sync_setup`，需设计决策）**。
> 第 1 批与第 3 批合计约 40 分钟，风险极低，收益是消除 6 条环并防止新增。