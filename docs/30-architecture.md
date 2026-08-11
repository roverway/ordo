# 30 — 架构（Architecture）

> 定义分层、目录结构、路由、状态管理与自适应布局规则。所有代码必须遵循本文档。

## 1. 分层原则

```
┌─────────────────────────────────────────────┐
│ Presentation（UI）                           │
│   pages / widgets / 设计令牌                 │
├─────────────────────────────────────────────┤
│ Application（状态层）                        │
│   Riverpod providers（业务状态与用例编排）    │
├─────────────────────────────────────────────┤
│ Data（数据层）                               │
│   DAO / Repository（Drift 访问）             │
├─────────────────────────────────────────────┤
│ Infrastructure（基础设施）                   │
│   Drift 数据库 / 同步引擎 / 远端存储 / 安全存储│
└─────────────────────────────────────────────┘
```

- **依赖方向**：UI → providers → repositories → infrastructure。禁止反向依赖。
- **UI 层禁止**：直接拼 SQL、直接访问 Drift 表、直接调用远端存储。
- **Repository 层**：唯一的数据访问入口，封装 DAO 与同步写入（写后触发同步防抖）。
- **同步引擎**：只依赖 Repository 与 RemoteStore 抽象，不依赖 UI。

## 2. 目录结构（lib/）

```
lib/
├── main.dart                     # 入口：初始化 DB/同步/安全存储
├── app.dart                      # MaterialApp.router：主题 + l10n + 路由
├── router.dart                   # go_router 路由表（唯一）
├── core/
│   ├── db/
│   │   ├── database.dart         # Drift Database 定义 + schemaVersion + 迁移
│   │   ├── tables.dart           # 表定义（projects/tasks/tags/task_tags/settings）
│   │   └── daos/                 # 各表 DAO（按实体拆分）
│   ├── sync/
│   │   ├── remote_store.dart     # RemoteStore 抽象接口
│   │   ├── remote_store_webdav.dart
│   │   ├── remote_store_s3.dart
│   │   ├── snapshot_codec.dart   # 快照 <-> JSON/gzip 编解码
│   │   ├── merge_engine.dart     # LWW 合并纯函数
│   │   └── sync_engine.dart      # 同步编排（触发/串行队列/错误处理）
│   ├── theme/
│   │   ├── app_tokens.dart       # 设计令牌（唯一魔法值来源）
│   │   └── app_theme.dart        # 主题构建（M3 + Monet + 回退）
│   ├── l10n/                     # ARB 文件 + 生成物（app_zh.arb / app_en.arb）
│   ├── security/
│   │   └── secure_store.dart     # flutter_secure_storage 封装
│   └── utils/
│       ├── dates.dart            # UTC 毫秒 <-> 本地时区格式化
│       └── uuid.dart             # UUID v4 生成
├── features/
│   ├── today/                    # 今日视图
│   ├── calendar/                 # 日历视图（周/月）
│   ├── projects/                 # 项目列表 + 项目详情（任务树）
│   ├── tasks/                    # 任务编辑面板、任务树组件、拖拽逻辑
│   ├── tags/                     # 标签视图
│   ├── search/                   # 搜索
│   ├── settings/                 # 设置页（主题/语言）
│   └── sync_setup/               # 同步配置页
└── shared/
    ├── widgets/                  # 跨 feature 通用组件（空态/加载/错误态等）
    └── models/                   # 跨层共享的领域模型（Task/Project/Tag）
```

每个 feature 内部：`xxx_page.dart` / `xxx_widgets.dart` / `xxx_providers.dart`（如规模大可再拆）。

## 3. 状态管理（Riverpod）

- 使用 `flutter_riverpod`（无 codegen），Provider 类型：`Provider` / `FutureProvider` / `StreamProvider` / `NotifierProvider`。
- **数据流**：Drift 表变更 → `StreamProvider` 自动刷新 UI（Drift 的 `watch()`）。
- **写操作**：一律走 Repository 方法（内部 `into()` 事务 + 更新 `updatedAt` + 触发同步防抖）。
- **派生状态**：父任务状态/完成度在 Provider 层计算（纯函数，见 `40-data-model.md` §6），**不落库**。
- **同步状态**：`SyncState` Notifier 暴露 `idle/syncing/success/error` + `lastSyncedAt`。
- 禁止：`setState` 管理跨页面业务状态；禁止在 widget 内直接 new Repository。

## 4. 路由（go_router）

路由表集中在 `lib/router.dart`，`MaterialApp.router` 使用。路由清单：

| 路径 | 页面 | 参数 |
|---|---|---|
| `/` | 今日（默认目的地） | — |
| `/calendar` | 日历 | `?date=`（可选，定位到某日） |
| `/projects` | 项目列表 | — |
| `/projects/:id` | 项目详情（任务树） | `id` |
| `/tags` | 标签列表 | — |
| `/tags/:id` | 标签任务列表 | `id` |
| `/search` | 搜索 | — |
| `/task/:id` | 任务编辑/详情 | `id`（新建用 `?projectId=&parentId=`） |
| `/settings` | 设置 | — |
| `/settings/sync` | 同步配置 | — |

- 宽屏（≥600dp）master-detail：列表路由与详情路由在**同一页面**内用 `LayoutBuilder` 分栏渲染，不额外压栈。
- 窄屏：详情以 push 方式进入新页面。
- 导航高亮：由当前路由推导当前目的地（今日/日历/项目/标签）。

## 5. 自适应布局规则

| 断点 | 布局 |
|---|---|
| `<600dp` | 底部 `NavigationBar`（4 tab：今日/日历/项目/标签）；搜索/设置放 AppBar |
| `600–1024dp` | `NavigationRail` + 两栏 master-detail |
| `>1024dp` | `NavigationRail` + 两栏（列表栏可更宽） |

- 断点判定用 `LayoutBuilder` 或 `MediaQuery.sizeOf`，封装为 `AppBreakpoints` 工具（`core/utils/`）。
- 所有页面必须同时适配三种断点；禁止写死宽度。

## 6. 关键流程

### 6.1 任务写入（含拖拽移动）

```
UI 操作 → Repository.moveTask(taskId, newParentId, newIndex)
  → 校验（防环 + 子树深度 ≤3，见 40-data-model.md §5）
  → 事务内更新 parentId / sortOrder / updatedAt
  → 触发同步防抖（2s）
```

### 6.2 同步流程

```
触发（手动/启动/防抖）
  → SyncEngine.run()
  → 串行队列（防重入）
  → RemoteStore.exists() → download()
  → 时钟偏差检测（>5min 警告）
  → MergeEngine.merge(local, remote)   # 纯函数
  → 应用到本地 DB（事务）
  → 重新导出快照 → gzip → upload()
  → 更新 lastSyncedAt / SyncState
```

详见 `60-sync-design.md`。

## 7. 错误处理约定

- 所有 Repository 方法返回 `Result<T>`（成功/失败 + 用户可读消息），或抛领域异常由 Provider 捕获。
- UI 层统一使用 `shared/widgets/error_view.dart` 展示错误 + 重试按钮。
- 同步失败：不破坏本地库；`SyncState.error` 展示错误；下次触发自动重试（指数退避，最多 5 次）。
- 禁止吞异常；禁止把堆栈直接展示给用户。

## 8. 测试策略

| 层 | 测试 | 说明 |
|---|---|---|
| 纯函数 | `merge_engine` / 派生状态 / 深度校验 | 单元测试，覆盖边界 |
| Repository | CRUD + 校验 + 级联删除 | 用内存数据库（`NativeDatabase.memory()`） |
| 迁移 | 每个 schemaVersion 升级 | 从旧版本数据升级后断言数据完整 |
| 同步集成 | `FakeRemoteStore` + 真实 MergeEngine | 覆盖首次同步/双向改/删除/墓碑场景 |
| Widget | 关键页面（任务树、拖拽、设置） | `flutter_test` widget 测试 |

测试文件与源码同目录 `test/` 镜像结构。