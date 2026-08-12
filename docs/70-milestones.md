# 70 — 里程碑与验收标准（Milestones & DoD）

> 每个里程碑有明确的 DoD（Definition of Done）。代理完成某里程碑后，必须按 DoD 逐条自检，并在交付说明中列出自检结果。**DoD 未全绿不得进入下一里程碑。**

## 通用提交门槛（每个里程碑都适用）

- `flutter analyze` 0 error
- `flutter test` 全绿
- `dart format .` 通过
- 无硬编码用户可见字符串（全部走 ARB）
- 无魔法值（全部走设计令牌）
- 依赖版本未漂移（`pubspec.lock` 与 `20-tech-stack.md` §4 一致）

---

## M0 — 项目脚手架（骨架）

**目标**：双端（Android + Windows）跑通导航、主题、i18n 骨架。

**任务**：
1. `flutter create` 项目，配置包名/应用名（占位「Todo」）。
2. 按 `20-tech-stack.md` §4 安装依赖并回填版本锁定表。
3. 建立 `lib/` 目录结构（`30-architecture.md` §2）。
4. 设计令牌 + 主题（`50-ui-ux.md` §2/§3），明/暗/跟随系统。
5. ARB 文件（zh/en）+ `flutter gen-l10n`，全部骨架文案走 ARB。
6. `go_router` 路由表 + 4 目的地空页面 + 自适应导航（<600dp NavigationBar / ≥600dp NavigationRail）。
7. 设置页骨架（主题/语言切换，持久化 settings 表）。

**DoD**：
- [ ] Android 与 Windows 均可运行，导航 4 tab 切换正常
- [ ] 主题三模式切换即时生效并持久化
- [ ] 语言切换即时生效并持久化（zh/en 各看一遍）
- [ ] 窄/宽屏布局均正常（模拟器旋转 / 窗口缩放）
- [ ] `flutter analyze` 0 error；`flutter test` 全绿

---

## M1 — 数据层（Drift）

**目标**：数据库 schema v1 + CRUD + 校验 + 派生状态，全部有单测。

**任务**：
1. Drift 表：projects / tasks / tags / task_tags / settings（`40-data-model.md` §2）。
2. DAO + Repository（`30-architecture.md` §2/§3），写操作统一更新 `updatedAt`。
3. 校验纯函数：`depthOf` / `subtreeDepthOf` / `isDescendantOf`（§5）+ 单测。
4. 派生状态纯函数：`derivedStatus` / `progress`（§6）+ 单测。
5. 级联删除（任务/项目/标签）+ 单测。
6. 迁移框架：schemaVersion=1 + 迁移测试基建。
7. 种子演示数据（可选，便于 M2 联调）。

**DoD**：
- [ ] 全部校验/派生/级联纯函数单测覆盖边界（含 3 级上限、防环、空子树）
- [ ] Repository CRUD 集成测试通过（内存 DB）
- [ ] 迁移测试基建就绪（M1 无实际迁移，仅框架）
- [ ] `flutter analyze` 0 error；`flutter test` 全绿

---

## M2 — 任务树核心 UI

**目标**：项目详情任务树（3 级）+ 任务编辑 + 拖拽排序/调级 + 派生状态展示。

**任务**：
1. 项目列表 + 项目详情页（任务树，展开/折叠）。
2. 任务编辑面板（标题/描述/备注/起止时间/状态/标签多选），校验（标题非空、endAt>=startAt）。
3. 新建子任务（深度校验，>3 级拒绝）。
4. 拖拽：同级排序 + 调级 + 回 1 级；非法目标回弹提示（`50-ui-ux.md` §6.1）。
5. 键盘兜底：行菜单上移/下移/缩进/缩出（同校验）。
6. 派生状态展示：有子任务任务显示派生徽标 + 进度条，状态控件禁用。
7. 删除（级联）+ 确认框。

**DoD**：
- [ ] Android + Windows 手工测试脚本通过（见下）
- [ ] 拖拽调级/排序与键盘兜底结果一致，且均执行深度/防环校验
- [ ] 3 级上限、防环、endAt>=startAt 均被拒绝并提示
- [ ] 子任务完成联动父状态/进度正确
- [ ] `flutter analyze` 0 error；`flutter test` 全绿

**M2 手工测试脚本**（双端各跑一遍）：
1. 建项目 → 建 3 级任务链 → 尝试建第 4 级被拒
2. 拖拽调级/排序 → 验证顺序与层级
3. 拖到自身后代 → 被拒回弹
4. 完成全部子任务 → 父任务自动完成
5. 键盘兜底按钮与拖拽结果一致

---

## M3 — 全局视图

**目标**：今日 / 日历 / 标签 / 搜索 / 筛选。

**任务**：
1. 今日视图（`10-requirements.md` §9.1 匹配规则 + 逾期标红）。
2. 日历视图：月视图 + 周视图（v1 允许简化实现：月网格 + 周列表），跨天任务区间显示（§9.2）。
3. 标签视图：标签列表 + 标签任务列表（状态筛选）。
4. 搜索：标题/描述/备注 LIKE，防抖 300ms。
5. 筛选组件：状态/标签/时间段，可叠加。

**DoD**：
- [x] 今日视图按 §9.1 精确匹配（含跨天区间、逾期）
- [x] 日历月/周视图正确显示任务（含跨天），点击日期格可新建/查看
- [x] 标签增删改 + 多对多关联正确；删除标签后任务保留
- [x] 搜索与筛选结果正确
- [x] `flutter analyze` 0 error；`flutter test` 全绿（含视图匹配规则单测）

> ✅ M3 已完成（2026-08）：`view_rules.dart` 纯函数 + 单测、今日/日历/标签/搜索四视图、
> 共享 `SimpleTaskTile`/`TaskFilterBar`、`/task/new` 支持日期预填。`flutter test` 226 全绿。

---

## M4 — 同步引擎

**目标**：WebDAV + S3 双实现、快照编解码、合并引擎、配置页、触发与错误处理。

**任务**：
1. `RemoteStore` 抽象 + WebDAV/S3 实现 + 工厂（`60-sync-design.md` §9）。
2. `snapshot_codec`（JSON + gzip，isolate 解析）。
3. `merge_engine`（LWW + tie-break + 墓碑 + reconcileTagIds，纯函数）。
4. `sync_engine`：串行队列、读改写、时钟偏差检测、错误处理/退避。
5. 同步配置页（凭据走 secure storage）+ 测试连接 + 立即同步 + 状态展示。
6. 触发：手动/启动/编辑防抖 2s/WiFi-only。
7. 上传优化：hash 跳过 + gzip。

**DoD**：
- [ ] `60-sync-design.md` §14 场景 1–10 全部单测/集成测试通过（FakeRemoteStore）
- [ ] 真实 WebDAV（如坚果云/NAS）手工跑通场景 1–6
- [ ] 真实 S3（如 R2/MinIO）手工跑通场景 1–6
- [ ] 凭据仅存 secure storage，日志无密钥
- [ ] 失败场景（断网/认证错/坏快照）不破坏本地库且可重试
- [ ] `flutter analyze` 0 error；`flutter test` 全绿

---

## M5 — 打磨与回归

**目标**：i18n 补全、主题细节、状态反馈、性能、平台细节、无障碍、全量回归。

**任务**：
1. 空态/加载态/错误态统一组件全页面覆盖。
2. 性能：列表分页/流式查询、快照 isolate 解析、深色模式细节。
3. 平台细节：Windows 窗口尺寸/DPI、Android PopScope 返回键/生命周期触发同步。
4. 无障碍：语义标签、对比度、字体缩放、键盘可达性。
5. 全量回归：`flutter test` + 双端手工回归脚本。

### UI 重构子任务（依据 `55-ui-redesign-proposal.md`，2026-08）

- **批 1 视觉层（已完成 2026-08）**：设计令牌（surfacePage/surfaceCard/圆形复选框/阴影/railWidth）、主题接入（Scaffold 基底、Card/Checkbox/NavigationRail）、SimpleTaskTile 与任务树行卡片化、今日/日历页面基底适配、inbox 行卡片化。`flutter analyze` 0 error；`flutter test` 227 全绿。
- **批 2-A 移动端侧边栏抽屉（已完成 2026-08）**：`10-requirements.md` FR-NAV-01 + `50-ui-ux.md` §4 已同步；AppShell 抽屉（系统组 + 项目组 + 新建项目）、窄屏底部 NavigationBar 精简为 3 入口、宽屏 Rail 5 目的地不变、AppBar 汉堡入口；`widget_test.dart` 同步新 IA（3 tab + 抽屉导航断言）。`flutter analyze` 0 error；`flutter test` 230 全绿。
- **统一任务页 TaskListPage（已完成 2026-08，`docs/56-task-scope-page.md`）**：今日/收件箱/项目三作用域统一渲染（AppShell 壳内，修复项目页无汉堡/底栏）；`initialLocation` 改 `/today`；项目编辑/删除入 AppBar、删除后跳 `/today`；FAB 统一走滴答式弹窗；`ProjectDetailPage`/`TodayPage`/`InboxPage` 废弃（逻辑并入）；`InboxTaskTile` 提升为共享组件；文档 FR-NAV/FR-VIEW/50-ui-ux §4/§5 同步。`flutter analyze` 0 error；`flutter test` 257 全绿。
- **精简窄屏底栏（已完成 2026-08，`docs/57-task-page-polish.md` 批 1）**：底栏 3 → 2 项（今日/日历，标签移入抽屉）；自绘 `CompactBottomBar`（高 56dp，明显矮于标准 NavigationBar 80dp；`selectedIndex = -1` 天然无选中；列表渲染可扩展）；令牌 `bottomBarHeight`/`bottomBarIconSize`/`bottomBarLabelSize`；FR-NAV-01 + 50-ui-ux §4 同步；`widget_test` 更新（2-tab 切换、紧凑高度断言）。`flutter analyze` 0 error；`flutter test` 257 全绿。
- **批 2 交互层（待做）**：FAB + 新建底部弹窗（自动保存 + 清单切换 + 日期/优先级/标签）；进度环（有子任务任务）；同步状态图标（依赖 M4）。
- **项目任务卡片化（待做，`docs/57-task-page-polish.md` 批 2）**：一级任务卡片 + 内部子任务紧凑行（拖拽/菜单/校验保留）。

**DoD**：
- [ ] NFR-01~09 全部满足（`10-requirements.md` §11）
- [ ] 双端全量回归通过（M2 脚本 + M3 视图 + M4 同步场景 1–10）
- [ ] 批 2 交互层验收：新建弹窗全流程、进度环正确（抽屉已随批 2-A 验收）
- [ ] `flutter analyze` 0 error；`flutter test` 全绿；`dart format` 通过
- [ ] 文档与实现一致（改代码必改文档）

---

## 里程碑依赖图

```
M0 ──> M1 ──> M2 ──> M3 ──> M4 ──> M5
骨架    数据层   任务树   视图    同步    打磨
```

- M1 依赖 M0（目录/依赖就绪）。
- M2 依赖 M1（数据层）。
- M3 依赖 M2（任务树组件复用）。
- M4 依赖 M1（Repository）+ M2（写操作触发防抖）；可与 M3 并行开发（不同 feature），但验收顺序 M3 先。
- M5 依赖全部。

## 交付物清单（全部里程碑完成后）

```
AGENTS.md
docs/00-project-brief.md
docs/10-requirements.md
docs/20-tech-stack.md
docs/30-architecture.md
docs/40-data-model.md
docs/50-ui-ux.md
docs/60-sync-design.md
docs/70-milestones.md
lib/  （按 30-architecture.md §2）
test/ （镜像 lib/ 结构）
```