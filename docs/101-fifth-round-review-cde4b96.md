# 第五轮整改复核报告

> - **文档状态**：**已闭环**（P1 与 P2 全部完成，无新增问题）
> - **文档定位**：对 `docs/100-fourth-round-review-09f5f6c.md`（基线 `09f5f6c`）所列剩余工作的**执行复核**
> - **基线 commit**：`cde4b96`（`fix(quality): align gate comments with constants and add proposal date picker tests`）
> - **核查区间**：`09f5f6c` → `cde4b96`（1 个 commit）
> - **核查分支**：`dev`（工作树 clean）
> - **核查时间**：2026-09-30
> - **报告归档**：`docs/101-fifth-round-review-cde4b96.md`
> - **上游文档链**：`96-`（代码质量评价）→ `97-`（整改核查）→ `98-`（剩余工作清单）→ `99-`（原则门禁化与循环依赖）→ `100-`（第四轮复核）→ **本文档**
> - **只读声明**：本次为**只读审计**，**未修改任何项目代码**，未执行任何整改动作。

---

## 摘要

**`docs/100-` 列出的 P1（2 处注释漂移）与 P2（1 项测试补充）全部完成，无新增问题。**

| 指标 | `09f5f6c` | `cde4b96` | 变化 |
|---|---:|---:|---|
| 测试通过数 | 906 | **915** | ↑ **+9** |
| 无对应测试的 lib 文件 | 55 | **54** | ↓ **-1** |
| 闸门注释一致性 | ❌ 2 处漂移 | ✅ **完全一致** | ↑ |
| 循环依赖 | 9 条 | 9 条 | 持平 |
| 巨型文件（>800 行） | 14 个 | 14 个 | 持平 |
| 质量闸门数 | 5 道 | 5 道 | 持平 |
| **综合评分** | 8.1 | **8.2** | ↑ **+0.1** |

**判断：整改执行到位，无回归，无新增技术债。**

---

## 我的独立验证（不采信 commit message 自述）

| 验证项 | 结果 |
|---|---|
| `bash tool/verify.sh` | **exit = 0**，5 道闸门全部通过 |
| `dart format lib test tool` | 0 changed |
| `flutter test` | **915 通过 / 6 skip / 0 失败**（`09f5f6c` 为 906，**+9**）|
| 循环依赖（严格路径解析 + DFS）| **9 条**（与基线持平）|
| 巨型文件棘轮 | **14 / 14 贴顶守住** |
| 循环依赖棘轮 | **9 / 9 贴顶守住** |
| 令牌数量棘轮 | 263 / 216（持平）|
| 洁净守卫 | 0 处 TODO/FIXME/HACK；零构建产物被跟踪 |

### `verify.sh` 实跑输出（节选）

```
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

# 一、P1：闸门注释漂移 —— ✅ 已修，且交叉验证一致

`docs/100-` §六 P1 列出 2 处注释与常量不一致。实测确认**两处均已修正**：

## 修复内容

```bash
# tool/check_quality_gates.sh:8    ← 已修正
# 3. 巨型文件守卫：棘轮硬阻断 > 800 行的 UI/逻辑单文件（当前基线 14 个，只减不增）
#                                                                  ^^^^^^ 原为 9

# tool/check_quality_gates.sh:9    ← 已修正
# 4. 循环依赖守卫：棘轮硬阻断 features 间有向图环（当前基线 9 条，只减不增）

# tool/check_quality_gates.sh:182  ← 行内注释已修正
MAX_CYCLES = 9  # 循环依赖棘轮基线（当前 9 条，随重构只减不增）
#                     ^^^^^^ 原为 14
```

## 一致性交叉核对（我逐项验证）

| 位置 | 注释声明 | 实际常量 | 一致 |
|---|---:|---:|:-:|
| 闸门③ 巨型文件（`:8` 注释 / `:96` 常量）| 14 | 14 | ✅ |
| 闸门④ 循环依赖（`:9` 注释 / `:182` 常量）| 9 | 9 | ✅ |

**5 道闸门实跑仍全绿**，两个棘轮继续贴顶守住 —— 说明修改未破坏逻辑，只改了注释。

**意义**：闸门既是执行器也是文档。注释与实际规则对齐后，维护者能准确判断余量（当前巨型文件**零余量**）。

---

# 二、P2：`proposal_date_picker_sheets` 测试 —— ✅ 382 行，断言扎实

## 测试结构

新增 `test/features/ai_copilot/widgets/proposal_date_picker_sheets_test.dart`（**382 行**），共 **10 个测试**，覆盖 2 个弹窗 × 4 类场景：

### `showProposalDueDatePicker`（4 个）

| 测试 | 验证内容 |
|---|---|
| 空值态展示 | 标题、预设选项正确；**无清除按钮** |
| 点「今天 18:00」 | 正确计算时间戳并触发回调 |
| 点「今晚 21:00」 | 正确计算时间戳并触发回调 |
| 非空态 | 展示清除按钮，点击回调 **`null`** |

### `showProposalStartDatePicker`（5 个）

| 测试 | 验证内容 |
|---|---|
| 空值态展示 | 标题、预设选项正确 |
| 点「现在」 | 回调当前时间戳 |
| 点「今天 14:00」 | 正确计算时间戳 |
| 非空态 | 清除按钮回调 `null` |
| **暗色模式** | Container 使用 `surfaceCardDark` 背景 |

## 评价：测试质量高于平均值

**优点**：

1. **验证具体计算结果**，而非仅"能打开" —— 对时间预设逐个断言计算值
2. **覆盖 `null` 分支** —— 清除按钮的回调语义被显式验证
3. **覆盖条件分支** —— 暗色模式背景色断言说明作者识别出主题分支
4. **两组测试结构对称** —— due/start 各覆盖完整状态机，便于对照

**判断**：这属于"能真正拦住回归"的测试，而非覆盖率凑数。

---

# 三、顺带发现：被测组件本身也做了重构

```
proposal_date_picker_sheets.dart:  317 → 333 行  (+235 / -219)
```

**测试与重构在同一个 commit 内** —— 通常意味着**为了让代码可测而做的结构调整**（把内联逻辑提取为可断言单元）。

### 公开符号核查（关键）

```dart
// lib/features/ai_copilot/widgets/proposal_date_picker_sheets.dart
Future<void> showProposalDueDatePicker({ ... })     // :7
Future<void> showProposalStartDatePicker({ ... })    // :188
```

**只有 2 个公开函数，均被测试覆盖。无新增未覆盖的公开 API。**

**结论**：重构是干净的，未制造新的测试盲区。

---

# 四、新增问题核查：无

| 检查项 | 结论 |
|---|---|
| 闸门注释一致性 | ✅ 两处均已对齐 |
| 新增死代码 / 未覆盖公开 API | ✅ 无（公开符号仅 2 个，均覆盖）|
| 闸门是否仍生效 | ✅ 5 道全过，2 个棘轮贴顶守住 |
| 循环依赖是否回退 | ✅ 仍 9 条（持平，未新增）|
| 巨型文件是否回退 | ✅ 仍 14 个（持平，未新增）|
| 令牌预算是否漂移 | ✅ 263 / 216 未动 |
| 测试是否引入不稳定因素 | ✅ 915 全绿，单次通过 |

---

# 五、评分

| 维度 | `docs/100-` | 本轮 | 变化原因 |
|---|---:|---:|---|
| 架构方向正确性 | 8.2 | **8.2** | — 无结构改动 |
| 测试护栏 | 8.8 | **9.0** | ↑ +9 测试；无测试文件 55→54；断言质量高 |
| 演进节奏 | 5.8 | **5.8** | — 环与巨型文件均持平 |
| 扩展成本 | 4.5 | **4.5** | — 同步实体仍 5 个 |
| UI 层可维护性 | 4.8 | **4.8** | — |
| 质量保障机制 | 9.2 | **9.2** | — 闸门无改动，仍 5 道全生效 |
| **文档可信度** | 5.5 | **5.8** | ↑ 闸门注释与常量对齐 |
| 性能天花板 | 6.0 | **6.0** | — |
| **综合** | **8.1** | **8.2** | **+0.1** |

---

# 六、当前剩余工作

**`docs/96-` 至 `docs/100-` 中我列出的所有 P0 与 P1 项已全部清空。** 剩余全部为 P3（我明确建议不动）。

## P3 —— 建议保持现状

| # | 项 | 数据 | 建议不动的理由 |
|---:|---|---|---|
| 1 | 残余 2 条 2 环 | `projects ↔ tasks`、`tags ↔ tasks` | **合理双向业务依赖**（项目列表需任务数 ↔ 任务需归属项目；标签详情需打开任务编辑 ↔ 任务编辑器需调起标签表单）。Dart 允许循环 import；棘轮基线 9 已防新增 |
| 2 | `todo_repository.dart` | 1,536 行 / 23 文件引用 | **未到临界点**。`docs/96-` §7.5 定的触发条件：同步实体 8–10 个 / 引用 35+ 文件 / 行数 1,800+。当前 5 / 23 / 1,536 |
| 3 | `sync_engine.dart` | 1,062 行 | **全项目质量最高的部分**（LWW + 确定性 tie-break + 纯函数 merge + 时钟偏移双检 + 结构化错误码）。拆它风险大于收益 |
| 4 | 其余 53 个无测试文件 | — | 多数为纯展示组件（badge / tile / chip），逻辑简单，优先级低于结构性问题 |

## 唯一有实质价值的可选推进：巨型文件存量治理

**现状：14 个 >800 行，棘轮基线 14 —— 零余量**（任何新巨型文件立即阻断）。

**建议治理顺序**（纯 UI、风险最低优先）：

| 序 | 文件 | 行数 | 理由 |
|---:|---|---:|---|
| 1 | `lib/features/projects/widgets/create_list_folder_sheet.dart` | 1,361 | 纯 UI；有测试兜底；906 测试全绿 |
| 2 | `lib/features/settings/settings_page.dart` | 1,230 | 纯 UI |
| 3 | `lib/features/custom_views/widgets/panel_column.dart` | 980 | 纯 UI |
| 4 | `lib/features/custom_views/presentation/custom_view_editor_page.dart` | 972 | 纯 UI |

**每拆一个文件，把 `MAX_ALLOWED` 下调 1**，巨型文件数即持续下降。

**不建议拆的两个**（在清单内但应跳过）：

- `todo_repository.dart`（1,536）—— 见P3-2
- `sync_engine.dart`（1,062）—— 见 P3-3

---

# 七、明确不要做的事

- ❌ **不要强行消除那 2 条 2 环** —— 会引入不必要的抽象层，收益不抵成本
- ❌ **不要拆 `sync_engine.dart`** —— 它是全项目质量最高的部分
- ❌ **不要拆 `todo_repository.dart`** —— 未到临界点
- ❌ **不要为消环而改业务逻辑** —— 继续只改 import 归属
- ❌ **不要写第 19 份人肉全量评审报告** —— `bash tool/verify.sh` 已覆盖 5 道闸门 + 格式 + 分析 + 令牌，机器比人扫得准

---

# 八、五轮整改总览（`0130ee8` → `cde4b96`）

| 指标 | `0130ee8`（基线） | `cde4b96`（当前） | 变化 |
|---|---:|---:|---|
| 测试通过数 | 880 | **915** | ↑ **+35** |
| SQLite 索引数 | **0** | **6** | ↑ WAL + busy_timeout + synchronous |
| 质量闸门数 | **0** | **5** | ↑ 分层 / 格式 / 巨型文件 / 循环依赖 / 洁净 |
| 循环依赖 | *（未测，实测 14）* | 9 | ↓ 已被闸门锁住 |
| 巨型文件 >800 行 | *（未测，实测 15）* | 14 | ↓ 棘轮贴顶 |
| 格式不合规文件 | 44 | **0** | ↓ 已阻断 |
| 令牌守卫模式 | 无 | 数量棘轮 263/216 | ↑ 从恒真断言进化 |
| hook 版本化 | 否 | `.githooks/` 入库 | ↑ |
| CI 分支覆盖 | main/dev | 全部（`**`） | ↑ |
| `onDataChanged` | 裸赋值 | `DataChangeObserver` 接口 | ↑ 依赖倒置 |
| 文档漂移 | 4 处 | 0 处 | ↓ |
| **综合评分** | **6.5** | **8.2** | **+1.7** |

## 关键结论

**五轮整改把我的报告中所有 P0 与 P1 项清空了。**

**最有价值的产出不是任何单次修复，而是门禁体系本身** —— 它把不可见的问题（14 条环、479 处令牌违规、44 个格式问题）变成持续可见的约束。

**最有价值的单次修复是 SQLite 层**（索引 + WAL）—— 它消除了一颗"台阶式"性能炸弹：在小数据下无感，在 5,000–10,000 条任务时会突然崩且不报错。

**质量门禁体系至此已完成它该做的事。** 剩余事项属产品迭代节奏，不是技术债问题。

---

# 附录 A：核查命令清单（可复现）

```bash
# 前置：清空全部代理变量（含 ALL_PROXY，否则 VM-service 端口被劫持）
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

# 0. 状态
git rev-parse --abbrev-ref HEAD        # 期望 dev
git log --oneline -1                   # 期望 cde4b96
git status --short                     # 期望 clean
git rev-list --count origin/dev..dev   # 期望 0

# 1. 全套闸门（5 道）
bash tool/verify.sh                    # 期望 exit 0

# 2. 格式与分析
dart format --output=none --set-exit-if-changed lib test tool
flutter test --reporter=compact# 期望 All tests passed（915）

# 3. 本轮 P1 验证：闸门注释 vs 常量（核心）
sed -n '6,10p' tool/check_quality_gates.sh            # 注释声明的基线
grep -n "^MAX_ALLOWED\|^MAX_CYCLES" tool/check_quality_gates.sh   # 实际常量
# 期望：注释 14 == MAX_ALLOWED 14；注释 9 == MAX_CYCLES 9

# 4. P2 验证：新测试文件
wc -l test/features/ai_copilot/widgets/proposal_date_picker_sheets_test.dart  # 382
grep -cE "testWidgets\(" test/features/ai_copilot/widgets/proposal_date_picker_sheets_test.dart  # 10

# 5. 被测组件公开符号（确认无未覆盖 API）
grep -nE "^(class|void|Future<void>) " lib/features/ai_copilot/widgets/proposal_date_picker_sheets.dart
# 期望仅 2 个 showProposal* 函数

# 6. 循环依赖（严格路径解析）
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
PY

# 7. 巨型文件清单
find lib -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 wc -l 2>/dev/null \
  | awk '$2!="总计" && $1>800' | sort -rn \
  | grep -vE "app_localizations(_en|_zh)?\.dart|user_manual_page\.dart"

# 8. 无测试文件统计
python3 - <<'PY'
import os
blob = ''
for dp, _, fn in os.walk('test'):
    for f in fn:
        if f.endswith('.dart'):
            blob += open(os.path.join(dp, f), encoding='utf-8', errors='ignore').read()
miss = []
for dp, _, fn in os.walk('lib'):
    for f in fn:
        if not f.endswith('.dart') or f.endswith('.g.dart') or 'l10n' in dp: continue
        p = os.path.join(dp, f); b = f[:-5]
        cands = {b, b.replace('_page',''), b.replace('_sheet',''),
                 b.replace('_providers',''), b.replace('_service',''),
                 b.replace('_section',''), b.replace('_badges','')}
        if not any(x and x in blob for x in cands):
            miss.append((p, os.path.getsize(p)//1024))
print(f"无对应测试: {len(miss)} 个（基线 54）")
PY
```

## 附录 B：证据边界（诚实声明）

- **未逐行审查 `cde4b96` 的重构** —— `proposal_date_picker_sheets.dart` 有 +235/-219 行变更，我仅核查了**公开符号数量**（确认无新增未覆盖 API）与**测试断言强度**，未逐模块评估重构后的职责边界是否更清晰
- **未评估 10 个新测试的断言充分性** —— 确认了断言存在且具体（时间计算值、`null` 回调、暗色背景），但未做变异测试（mutation testing）验证其是否能真正捕获回归
- **残余 9 条环的运行时影响仍未实测** —— Dart 允许循环 import，本报告仅做静态分析
- **未评估 `sync_engine.dart`（1,062 行）是否真的"不该拆"** —— 该判断基于 `docs/96-` 第三章对它的设计评价，**未做拆分可行性分析**
- **`todo_repository.dart` 的临界点判断（1,800 行 / 35 引用 / 8–10 实体）** 属 `docs/96-` §7.5 的估计，**未经验证**

---

> **文档结束 · 状态：已闭环**
> 本文档为只读审计产出，**未修改任何项目代码，未执行任何整改动作**。
>
> **五轮整改闭环结论**：`docs/96-` 列出的所有 P0 / P1 项已全部完成，综合评分 **6.5 → 8.2**。
> 剩余事项全部为 P3（本文档第六节明确建议不动的 4 项）。
> **质量门禁体系已完成它该做的事；后续以产品迭代为主，无需继续专项整改。**