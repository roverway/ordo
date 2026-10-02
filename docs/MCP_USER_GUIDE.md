# Ordo MCP 外部集成使用手册 (Model Context Protocol User Guide)

> **版本基准**：Ordo v1.0.0+ | **协议版本**：JSON-RPC 2.0 (MCP 2024-11-05 / 2025-03-26)  
> **更新日期**：2026-10-02  
> **适用人群**：希望通过 Claude Desktop、Cursor、Cline、Windsurf、OpenAI 兼容客户端或自定义脚本与 Ordo 进行双向任务交互的用户与开发者。

---

## 1. 概览与核心理念

Ordo 内置了高性能、低延迟的本地 **MCP (Model Context Protocol) Server**。通过该服务，外部任意支持 MCP 协议的 AI 助手均可安全、受控地查询你的待办任务、智能编排日程、创建与拆解复杂目标、批量管理标签及获取每日全局简报。

### 核心设计原则：
1. **单一事实数据源 (Single Source of Truth)**：MCP 服务直接对接 Ordo 统一底层数据库（SQLite / Drift），与应用 UI 共享统一的验证与业务逻辑，零数据同步延时与冲突。
2. **服务端权限天花板 (Server-Enforced Ceiling)**：应用端掌握绝对控制权。若客户端设置为「提案审核」模式，外部 AI 传入的任何直写尝试均会被服务端强制收敛为待审提案，绝不允许外部穿透。
3. **诚实与快速失败 (Fail-Fast & Zero-Data-Corruption)**：坚决杜绝静默吞错。非法入参、拼写错误或不存在的日历日期（如 2 月 30 日）立即向模型返回明确错误码与修正指引，杜绝静默回退造成数据隐性污染。
4. **Token 友好与上下文节约**：提供 `fields` 字段投影、原生 SQL 分组聚合 (`aggregate_tasks`) 与一站式晨报 (`daily_briefing`)，避免在大型待办库中一次性吞噬数万 Token。

---

## 2. 快速上手：开启服务与获取凭据

### 2.1 服务开关与端点地址
1. 打开 Ordo 应用，进入 **「设置」 -> 「AI 设置」 -> 「MCP 服务」**；
2. 开启 **「启用 MCP 本地服务」** 开关；
3. 查看面板上展示的 **服务端口 (Port)** 与 **服务端点 URL**，例如：
   ```text
   http://127.0.0.1:42185/mcp
   ```
   > [!NOTE]
   > 服务仅监听本地环回地址 (`127.0.0.1`)，严禁且不会暴露到公网或局域网，确保本地隐私数据绝对安全。

### 2.2 API Key 鉴权管理
- **要求 API Key 鉴权**：建议默认保持开启。开启后，外部客户端必须在 HTTP 请求头中提供密钥，否则拒绝访问。
- **获取 / 重新生成密钥**：在设置页点击「复制 API Key」或「重新生成」获取以 `ordo_sk_` 开头的安全密钥。

### 2.3 任务写入模式选择
在设置界面中，你可以设定 **「任务写入模式」**：
- **提案审核模式 (Review)**（默认推荐）：外部 AI 提出的任何创建、修改、删除操作均被收录入 Ordo 的「AI 提案队列」，手机/桌面端会弹出悬浮卡片供你一键确认或拒绝，杜绝 AI 误操作破坏数据。外部 AI 无论传递何种参数，都无法绕过此安全天花板。
- **直接写入模式 (Direct)**：经过你授权信任的 AI 可直接操作数据库，任务实时落库并即刻在界面呈现。适合配合 Cursor、Claude Desktop 进行高频高信任度的自动化辅助。

---

## 3. 主流 AI 客户端接入配置指南

由于 Ordo MCP Server 采用标准的 **Stream-based HTTP JSON-RPC 2.0** 架构，各客户端接入方式略有不同：

### 3.1 Claude Desktop 配置

Claude Desktop 目前原生支持通过 `command`（stdio 桥接）唤起 MCP 服务。推荐使用系统自带的 `curl` 或 `mcp-remote` 将 stdio 桥接到 Ordo 的 HTTP 端点。

#### 配置文件路径：
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

#### 配置示例（使用 npx 官方 mcp-proxy / curl）：
```json
{
  "mcpServers": {
    "ordo-tasks": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-proxy",
        "http://127.0.0.1:42185/mcp"
      ],
      "env": {
        "MCP_PROXY_HEADERS": "{\"x-api-key\": \"ordo_sk_your_key_here\"}"
      }
    }
  }
}
```

### 3.2 Cursor 配置

Cursor 支持直接添加 HTTP / SSE 类型的 MCP 服务：

1. 进入 Cursor **Settings -> Features -> MCP**；
2. 点击 **+ Add New MCP Server**；
3. 填写配置项：
   - **Name**: `ordo-tasks`
   - **Type**: `command` 或 `sse/http`（视当前 Cursor 版本能力）
   - **Command / URL**: 如果支持 HTTP，直接填写 `http://127.0.0.1:42185/mcp`，并在 Custom Headers 中添加 `x-api-key: ordo_sk_...`；如果为 stdio 模式，使用上述 proxy 命令；
4. 保存后，Cursor 会自动刷新并亮起绿色指示灯，列出所有 13 个可用工具。

### 3.3 VS Code (Cline / Roo Code) 配置

在 VS Code 中使用 Cline 插件：
1. 打开 Cline 设置，选择 **MCP Servers**；
2. 点击右上角编辑 `cline_mcp_settings.json`：
```json
{
  "mcpServers": {
    "ordo-tasks": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-proxy",
        "http://127.0.0.1:42185/mcp"
      ],
      "env": {
        "MCP_HEADERS": "{\"x-api-key\": \"ordo_sk_your_key_here\"}"
      }
    }
  }
}
```

### 3.4 脚本 / cURL / 命令行直接交互

你可以通过任意脚本语言直接调用 Ordo 的 JSON-RPC 接口：

#### 探测健康状态与可用工具：
```bash
# 获取工具列表
curl -X POST http://127.0.0.1:42185/mcp \
  -H "Content-Type: application/json" \
  -H "x-api-key: ordo_sk_your_key_here" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list",
    "params": {}
  }'
```

#### 调用工具（以 query_tasks 为例）：
```bash
curl -X POST http://127.0.0.1:42185/mcp \
  -H "Content-Type: application/json" \
  -H "x-api-key: ordo_sk_your_key_here" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "query_tasks",
      "arguments": {
        "dateScope": "today",
        "fields": ["id", "title", "priority", "dueDate"]
      }
    }
  }'
```

---

## 4. 全量 13 大 MCP 工具参考手册

系统内置了 13 个标准 MCP 工具，涵盖环境感知、多维检索、单任务树查看、增删改、提案管理、数据洞察、全局晨报与标签运维：

| 工具名称 | 功能定位 | MCP 官方注解 | 主要入参 | 返回重点 |
|---|---|---|---|---|
| [`get_metadata`](#41-get_metadata) | 环境、时区与分类元数据 | `readOnlyHint` | 无 | 当前绝对时间、时区偏差、所有项目（含所属文件夹）、所有标签、自定义视图 |
| [`query_tasks`](#42-query_tasks) | 任务多维严检查询 | `readOnlyHint` | `searchQuery`, `statuses`, `priorities`, `projectId`, `dateScope`, `fields`, `limit` | 默认智能过滤待办任务，返回任务集、总命中数与分页状态 |
| [`get_task`](#43-get_task) | 任务深度递归树查看 | `readOnlyHint` | `taskId` (必填) | 任务全量属性、递归子任务树（最多 5 层）、计算完成状态、标签列表 |
| [`create_tasks`](#44-create_tasks) | 单任务创建（含拆解） | `idempotentHint` | `title` (必填), `projectId`, `priority`, `dueDate`, `tags`, `substeps`, `dryRun`, `idempotencyKey` | 状态（`created`/`pending`）、生效 `writeMode`、`taskId` 或 `proposalId` |
| [`create_tasks_bulk`](#45-create_tasks_bulk) | 批量创建（至多100条） | `idempotentHint` | `tasks` (必填数组), `dryRun` (可选布尔), `idempotencyKey` | 批量结果统计、深层日历校验结果、成功 ID 或失败索引清单 |
| [`update_task`](#46-update_task) | 任务修改与 Diff 感知 | `idempotentHint` | `taskId` (必填), `title`, `status`, `priority`, `dueDate`, `projectId`, `tags`, `dryRun` | 变更差异报告（`updatedFields`、`previousValues`、`currentValues`） |
| [`delete_tasks`](#47-delete_tasks) | 批量删除任务 | `destructiveHint` | `taskIds` (必填数组), `dryRun` | 被删除任务详情、成功数、不存在的无效 ID 列表 |
| [`daily_briefing`](#48-daily_briefing) | 一站式每日全景简报 | `readOnlyHint` | `horizonDays` (可选) | 一键聚合已逾期、今日到期、进行中、近期完成统计及四象限高优先级分布 |
| [`manage_tags`](#49-manage_tags) | 标签全生命周期管理 | - | `action` (`list`/`create`/`delete`/`rename`), `name`, `color`, `tagId` | 标签列表（附带任务使用数统计）、创建成功对象或修改确认 |
| [`list_proposals`](#410-list_proposals) | 查询提案审核队列 | `readOnlyHint` | `status` (pending/confirmed/rejected), `limit` | 暂存提案清单、原始荷载、创建时间与过期时间 |
| [`confirm_proposals`](#411-confirm_proposals) | 批量确认应用提案 | `idempotentHint` | `proposalIds` (必填数组) | 成功落库数、每项对应的正式 `taskId` |
| [`reject_proposals`](#412-reject_proposals) | 批量废弃驳回提案 | `idempotentHint` | `proposalIds` (必填数组), `reason` | 驳回状态与废弃数量 |
| [`aggregate_tasks`](#413-aggregate_tasks) | SQL 原生快速分组统计 | `readOnlyHint` | `groupBy` (status/priority/project/tag), `completedScope` | 分组统计桶 (buckets)、各类任务总数 |

---

### 4.1 get_metadata
- **用途**：外部 AI 会话开始时首选调用的基础工具。获取当前准确的绝对时间与时区偏差（解决模型时空偏移），并获取项目层级分类树与标签。
- **示例入参**：`{}`
- **示例返回**：
  ```json
  {
    "now": {
      "iso": "2026-10-02T10:30:00.000Z",
      "date": "2026-10-02",
      "weekday": "Friday"
    },
    "timezone": "Asia/Shanghai",
    "utcOffsetMinutes": 480,
    "projects": [
      { "id": "inbox", "name": "收件箱", "color": "#6C5CE7", "folderName": null },
      { "id": "proj-arch", "name": "系统架构优化", "color": "#3B82F6", "folderName": "工作" }
    ],
    "folders": [
      { "id": "f-1", "name": "工作" },
      { "id": "f-2", "name": "生活" }
    ],
    "tags": [
      { "id": "tag-1", "name": "重要", "color": "#EF4444" }
    ],
    "customViews": []
  }
  ```

---

### 4.2 query_tasks
- **用途**：基于任务查询引擎进行多条件严谨检索。
- **严格契约说明**：
  - **白名单参数校验**：若传入未定义参数（如拼错的 `isOverdue`），服务立即报错 `INVALID_ARGUMENT` 并提示可用参数，杜绝静默吞错。
  - **智能默认待办过滤**：未指定状态或进行日期日程检索时，默认仅检索 `[todo, in_progress]` 待办任务，不会将已完成的历史归档混入。若需查询所有历史，须显式传入 `statuses: ["all"]`。
- **入参说明**：
  - `searchQuery` *(string)*: 文本模糊搜索（匹配标题、富文本描述、子任务；支持别名 `keyword`）
  - `statuses` *(array of string)*: 过滤状态：`todo`, `in_progress`, `done`, `archived` 或 `all`（支持别名 `status`）
  - `priorities` *(array of int)*: 0 (无), 1 (低), 2 (中), 3 (高)
  - `projectId` *(string)*: 过滤指定项目 ID
  - `tagIds` *(array of string)*: 过滤标签 ID 列表
  - `dateScope` *(string)*: `today`, `tomorrow`, `overdue`, `upcoming`, `nodate`, `all`, `customRange`（支持别名 `dueScope`）
  - `dueBefore` / `dueAfter` *(string/int)*: 自定义时间范围
  - `fields` *(array of string)*: **字段投影**，仅返回需要的列（例如 `["id", "title", "dueDate", "status"]`），大幅降低 Token 消耗
  - `limit` *(int)*: 每页数量（默认 20，最大 100）
- **示例返回**：
  ```json
  {
    "totalMatched": 1,
    "returnedCount": 1,
    "hasMore": false,
    "tasks": [
      {
        "id": "task-uuid-1",
        "title": "编写架构规范",
        "status": "todo",
        "priority": 3,
        "priorityLevel": "high",
        "dueDate": "2026-10-05 18:00",
        "dueAt": 1791223200000,
        "isCompleted": false,
        "subtaskCount": 2,
        "completedSubtaskCount": 0
      }
    ]
  }
  ```

---

### 4.3 get_task
- **用途**：深度查看单个任务及其**全层级递归子任务树**（最多支持 5 层深度的父子关联）与标签详情。
- **入参说明**：
  - `taskId` *(string, 必填)*: 目标任务 ID
- **示例返回**：
  ```json
  {
    "task": {
      "id": "task-uuid-1",
      "title": "搭建自动化 CI 门禁",
      "description": "包含代码格式守卫、令牌纪律守卫与测试套件",
      "status": "in_progress",
      "priority": 3,
      "projectId": "inbox",
      "projectName": "收件箱",
      "tags": ["DevOps", "CI/CD"],
      "subtasks": [
        {
          "id": "sub-1",
          "title": "编写 pre-commit 脚本",
          "status": "done",
          "isCompleted": true,
          "subtasks": []
        },
        {
          "id": "sub-2",
          "title": "接入流水线校验",
          "status": "todo",
          "isCompleted": false,
          "subtasks": []
        }
      ]
    }
  }
  ```

---

### 4.4 create_tasks
- **用途**：创建新任务，支持自然语言拆解子步骤与标签绑定。
- **防护与执行规则**：
  - **服务端天花板**：若服务端设置为 `review`，客户端传 `mode: "direct"` 会被强制收敛为审查模式，返回 `status: "pending"` 与 `proposalId`。
  - **严格日历校验**：支持 `today`、`tomorrow`、`3天后`、`eod` 等相对日期；但传入非法日历日期（如 `2026-02-30`）会明确报错 `UNPARSEABLE_DATE`。
  - **幂等防重放**：支持传入 `idempotencyKey`，相同请求不会重复建任务，安全回放并标记 `idempotentReplay: true`。
  - **安全预检**：支持 `dryRun: true` 进行参数合法性试运行。
- **入参说明**：
  - `title` *(string, 必填)*: 任务标题
  - `projectId` *(string)*: 归属项目 ID（缺省归入 `inbox`）
  - `description` *(string)*: 补充描述或 Markdown 备注
  - `priority` *(int/string)*: 0~3，或 `"low"`, `"medium"`, `"high"`
  - `startDate` / `dueDate` *(string/int)*: 支持相对日期词或标准日期串
  - `tags` *(array of string)*: 标签名称列表（不存在会自动补建）
  - `substeps` *(array of string)*: 子任务步骤列表
  - `dryRun` *(boolean)*: 是否仅预检不写库
  - `idempotencyKey` *(string)*: 幂等防重 Token
- **示例返回（直写成功）**：
  ```json
  {
    "ok": true,
    "status": "created",
    "writeMode": "direct",
    "taskId": "7d9b9c02-...",
    "task": {
      "id": "7d9b9c02-...",
      "title": "设计架构规范",
      "dueDate": "2026-10-02 18:00"
    },
    "requiresConfirmation": false,
    "message": "Task \"设计架构规范\" created successfully."
  }
  ```

---

### 4.5 create_tasks_bulk
- **用途**：单次批量创建至多 100 项任务。
- **入参说明**：
  - `tasks` *(array of object, 必填)*: 待创建任务清单
  - `dryRun` *(boolean)*: 若设为 `true`，**执行全字段深度校验与推演（包括日期真实性、项目存在性）**，不落库。
  - `idempotencyKey` *(string)*: 批处理幂等 Token
- **示例返回 (dryRun 模式)**：
  ```json
  {
    "ok": true,
    "dryRun": true,
    "summary": { "total": 2, "valid": 2, "invalid": 0 },
    "validations": [
      { "index": 0, "title": "任务一", "valid": true },
      { "index": 1, "title": "任务二", "valid": true }
    ]
  }
  ```

---

### 4.6 update_task
- **用途**：修改现有任务属性。提供完整的前后状态 **Diff 变更集**。
- **入参说明**：
  - `taskId` *(string, 必填)*: 目标任务 ID
  - `title` *(string)*: 新标题
  - `description` *(string)*: 新描述
  - `status` *(string)*: `todo`, `in_progress`, `done`, `archived`
  - `priority` *(int)*: 0~3
  - `dueDate` *(string/int)*: 修改截止时间
  - `clearDueDate` *(boolean)*: 为 true 时清空截止日期
  - `projectId` *(string)*: 移动至新项目
  - `tags` *(array of string)*: 覆盖更新标签
  - `dryRun` *(boolean)*: 预演校验
- **示例返回**：
  ```json
  {
    "ok": true,
    "status": "updated",
    "taskId": "7d9b9c02-...",
    "updatedFields": ["priority", "status"],
    "previousValues": { "priority": 1, "status": "todo" },
    "currentValues": { "priority": 3, "status": "in_progress" }
  }
  ```

---

### 4.7 delete_tasks
- **用途**：批量删除任务（MCP 注解为 `destructiveHint: true`）。级联清理子任务与标签映射。
- **入参说明**：
  - `taskIds` *(array of string, 必填)*: 待删除的任务 ID 数组
  - `dryRun` *(boolean)*: 是否仅预检
- **示例返回**：
  ```json
  {
    "ok": true,
    "summary": { "requested": 2, "succeeded": 2, "failed": 0 },
    "deletedIds": ["id-1", "id-2"],
    "deletedTasks": [
      { "id": "id-1", "title": "已过期任务A" },
      { "id": "id-2", "title": "废弃任务B" }
    ],
    "notFoundIds": []
  }
  ```

---

### 4.8 daily_briefing
- **用途**：**高杠杆一站式晨报 / 晚报工具**（MCP 注解 `readOnlyHint: true`）。一次调用聚合全景信息，取代以往需要多次调用 `query_tasks` 和 `aggregate_tasks` 的繁琐过程。
- **入参说明**：
  - `horizonDays` *(int, 可选)*: 近期完成统计回溯天数（默认 7 天）
- **返回重点**：
  - `summary`: 包含 `overdueCount`、`dueTodayCount`、`inProgressCount`、`completedTodayCount`、`highPriorityPendingCount`
  - `overdue`: 逾期任务列表
  - `dueToday`: 今日必须完成的任务列表
  - `inProgress`: 正在进行中的任务
  - `highPriorityPending`: 紧急/高优先级待办
  - `projects`: 各项目当前未完成任务数统计
- **示例返回**：
  ```json
  {
    "ok": true,
    "briefingDate": "2026-10-02",
    "summary": {
      "overdueCount": 1,
      "dueTodayCount": 2,
      "inProgressCount": 1,
      "completedTodayCount": 3,
      "highPriorityPendingCount": 2
    },
    "overdue": [
      { "id": "t-1", "title": "补充 API 鉴权用例", "priority": 3, "dueDate": "2026-10-01 18:00" }
    ],
    "dueToday": [
      { "id": "t-2", "title": "更新 MCP 使用手册", "priority": 2, "dueDate": "2026-10-02 18:00" }
    ]
  }
  ```

---

### 4.9 manage_tags
- **用途**：标签全生命周期管理，支持查看标签在当前任务库中的引用计数，以及原子创建、重命名与安全删除。
- **入参说明**：
  - `action` *(string, 必填)*: `list`, `create`, `delete`, `rename`
  - `name` *(string)*: 标签名称（create / rename 必填）
  - `color` *(string/int)*: 颜色 Hex 码（如 `"#FF5500"` 或整数色值）
  - `tagId` 或 `id` *(string)*: 标签 ID（delete / rename 必填）
- **示例（创建标签）**：
  ```json
  // 入参
  { "action": "create", "name": "Sprint-42", "color": "#10B981" }
  // 返回
  {
    "ok": true,
    "action": "create",
    "status": "created",
    "tag": { "id": "tag-42", "name": "Sprint-42", "color": 4279302529 }
  }
  ```

---

### 4.10 提案管理工具 (list_proposals / confirm_proposals / reject_proposals)
当 Ordo 处于「提案审核」模式，或调用写入工具返回 `writeMode: "review"` 时：
1. **`list_proposals`**：入参 `status: "pending"`，返回待处理的提案列表与原始内容；
2. **`confirm_proposals`**：入参 `proposalIds: ["prop-id-1"]`，应用修改并返回正式 `taskId`；
3. **`reject_proposals`**：入参 `proposalIds: ["prop-id-2"]`，驳回并废除提案。
> 提示：Ordo 客户端主界面会自动实时弹出悬浮确认卡片，无需外部 AI 额外手动轮询。

---

### 4.11 aggregate_tasks
- **用途**：以 SQLite 原生聚合能力高效洞察任务全局，避免拉取成百上千条记录撑爆模型窗口。
- **入参说明**：
  - `groupBy` *(string, 必填)*: 聚合维度：`priority`, `status`, `project`, `tag`
  - `completedScope` *(string)*: `all`（全部）、`active`（仅进行中/未完成）或 `completed`（仅已完成）
- **示例返回**：
  ```json
  {
    "ok": true,
    "total": 42,
    "groupBy": "priority",
    "buckets": [
      { "key": "none", "count": 10 },
      { "key": "low", "count": 12 },
      { "key": "medium", "count": 15 },
      { "key": "high", "count": 5 }
    ]
  }
  ```

---

## 5. 典型应用场景与 Prompt 实践

你可以把以下 System Prompt 部署给你的 AI 编程助手（如 Cursor Rules、Claude Projects、Windsurf 等）：

```markdown
你已接入我的本地个人任务管理系统 Ordo (ordo-tasks MCP)。
在规划、查询与跟踪任务时，请务必遵守以下工程原则：

1. [开始上下文感知] 每次会话开始时，调用 get_metadata 掌握准确时间、时区偏差与有效项目列表；
2. [日程规划总览] 在我询问“今天要做什么”或进行每日复盘时，优先调用 daily_briefing 一站式获取全局指标与逾期待办；
3. [复杂目标拆解] 当我提出目标或新需求时，调用 create_tasks 并在 substeps 中给出 3~5 个顺序清晰的拆解步骤，设置合理优先级与截止时间；
4. [节约 Token] 查询任务时，使用 query_tasks 的 fields 字段投影（如仅获取 id, title, dueDate, status），且未指定时会自动过滤未完成待办；
5. [宏观统计] 需要分析任务分布时，调用 aggregate_tasks，严禁全量 dump 数据；
6. [严格遵循契约] 遇到日期时使用自然相对词汇（如 today, tomorrow）或 YYYY-MM-DD 真实日历，避免输入非法参数名。
```

---

## 6. 常见问题与排查 (Troubleshooting)

### Q1: 外部 AI 报错 `Unauthorized (-32001)`？
- **原因**：应用开启了“要求 API Key 鉴权”，但外部客户端请求头未携带或携带了错误的密钥。
- **解决**：在请求头添加 `x-api-key: ordo_sk_...` 或 `Authorization: Bearer ordo_sk_...`；或者在 Ordo 设置中暂时关闭鉴权开关。

### Q2: 报错 `INVALID_ARGUMENT: Unknown parameter '...'`？
- **原因**：Ordo 开启了参数白名单严格校验，请求中包含了未支持或拼错的参数名（如 `isOverdue`）。
- **解决**：参考本手册第 4 节调整为正确的入参名称（例如使用 `dateScope: "overdue"`）。

### Q3: 报错 `UNPARSEABLE_DATE`？
- **原因**：传入了非法日期格式，或传入了不存在的日历日期（如 `2026-02-30`）。
- **解决**：传入合法的日历日期或相对词汇（`today`, `tomorrow`, `2026-10-05 18:00`）。

### Q4: 提示 `PROJECT_NOT_FOUND` 错误？
- **原因**：传入的 `projectId` 在系统中不存在。
- **解决**：先调用 `get_metadata` 获取当前合法项目列表；若不需要指定项目，缺省不传即可自动存入 `inbox` 收件箱。

### Q5: 为什么传入了 `mode: "direct"`，返回值仍是 `pending` 且生成了 `proposalId`？
- **原因**：你在 Ordo 设置中启用了 **「提案审核」** 模式。
- **机制**：出于数据安全考虑，服务端的审核设置拥有最高优先权（服务端权限天花板），客户端无法强制穿透。你只需在 Ordo 客户端弹出的浮窗中点击确认即可落库；如需免确认直写，请在设置中将模式切换为 **「直接写入」**。

### Q6: 客户端重启后端口变了怎么办？
- Ordo MCP Server 默认绑定动态空闲端口以防止端口冲突。建议在系统托盘常驻 Ordo。若重启了应用，查看设置页最新端口并更新外部配置即可。
