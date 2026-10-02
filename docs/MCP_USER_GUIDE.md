# Ordo MCP 外部集成使用手册 (Model Context Protocol User Guide)

> **版本**：v1.1.0  
> **适用协议**：Model Context Protocol (MCP) JSON-RPC 2.0 (Stream / HTTP POST)  
> **适用端**：桌面端（Linux / Windows / macOS）与局域网本机集成

---

## 1. 概览与核心理念

Ordo（知序）内置了高性能、安全、本地优先的 **MCP (Model Context Protocol) Server**。  
通过 MCP，你可以让外部 AI 开发工具（如 **Cursor**、**Claude Desktop**、**Cline**、**Windsurf**、**Cherry Studio** 等）或自动化脚本直接连接本地 Ordo 应用，实现：
- 🔍 **多维智能检索**：毫秒级检索任务树、跨项目筛选、富文本与标签过滤；
- ⚡ **无感自动写入**：经过 API Key 鉴权后，外部 AI 可直接为你创建、拆解、排期并持久化任务；
- 🛡️ **安全审查闭环**：支持提案审核队列（Proposal Queue），由人机协同复核后再批量落库；
- 📊 **高效数据洞察**：原生 SQL 分组聚合统计，无需将海量任务全部 dump 给大模型，节约 95% 上下文消耗。

---

## 2. 快速上手：开启服务与获取凭据

### 2.1 服务开关与端点地址
1. 打开 Ordo 客户端，点击左侧导航栏底部的 **设置 (Settings)**；
2. 找到 **「MCP 外部集成 (Model Context Protocol)」** 卡片；
3. 打开主开关，系统将在本机回环地址（`127.0.0.1`）自动绑定空闲端口启动服务，例如：
   ```text
   http://127.0.0.1:41352/mcp
   ```
4. 点击地址栏右侧的复制按钮即可复制端点 URL。

> **安全须知**：Ordo MCP Server 仅监听 `127.0.0.1`（本地回环网络），任何外网机器均无法直接探测或连接；同时支持 CORS 校验，阻断恶意浏览器跨域探针。

### 2.2 API Key 鉴权管理
- **开启鉴权**：在卡片中开启 **「要求 API Key 鉴权」**（默认建议保持开启）。
- **查看与复制 Key**：服务已为你自动生成格式如 `ordo_sk_xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` 的私有密钥，点击眼睛图标可查看明文，点击复制图标复制到剪贴板。
- **重新生成**：若怀疑密钥泄露，可点击刷新图标重新生成密钥。重新生成后，之前配置该密钥的外部工具将立即失效（返回 HTTP 401）。

### 2.3 任务写入模式选择
卡片提供了两种写入模式切换：
- ⚡ **直接写入 (Direct Write)** *(推荐)*：
  外部 AI 客户端调用 `create_tasks` 或 `update_task` 时，**立即执行并持久化到本地 SQLite 数据库**。适合日常信任的 AI 伴侣工具（如 Cursor / Claude Desktop）。
- 📝 **提案审核 (Review Queue)**：
  外部 AI 客户端的所有写入请求会被安全暂存到 `task_proposals` 审核表中，不会直接修改正式任务。后续由用户在客户端或调用 `confirm_proposals` 批量确认生效。

---

## 3. 主流 AI 客户端接入配置指南

### 3.1 Claude Desktop 配置

在 Claude Desktop 的配置文件中添加 Ordo MCP 节点：
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
- **Linux**: `~/.config/Claude/claude_desktop_config.json`

使用通用的 `mcp-remote` / SSE 网关或标准 HTTP 桥接配置：

```json
{
  "mcpServers": {
    "ordo-tasks": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-proxy",
        "http://127.0.0.1:41352/mcp",
        "--header",
        "x-api-key: ordo_sk_your_actual_key_here"
      ]
    }
  }
}
```

> 注：请将端口号 `41352` 及 `ordo_sk_...` 替换为你在 Ordo 设置页面中看到的实际端口与密钥。

---

### 3.2 Cursor 配置

在 Cursor 中：
1. 打开 Cursor Settings -> **Features** -> **MCP**；
2. 点击 **+ Add New MCP Server**；
3. 选择 Type 为 `command`，配置示例如下：
   - **Name**: `ordo-tasks`
   - **Type**: `command`
   - **Command**:
     ```bash
     curl -s -X POST http://127.0.0.1:41352/mcp -H "Content-Type: application/json" -H "x-api-key: ordo_sk_your_actual_key_here" -d @-
     ```
   或者使用标准 node 反向代理接入。

---

### 3.3 VS Code (Cline / Roo Code) 配置

在扩展的 MCP Settings (`cline_mcp_settings.json`) 中：

```json
{
  "mcpServers": {
    "ordo-tasks": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-proxy",
        "http://127.0.0.1:41352/mcp"
      ],
      "env": {
        "MCP_HEADERS": "{\"x-api-key\": \"ordo_sk_your_actual_key_here\"}"
      }
    }
  }
}
```

---

### 3.4 脚本 / cURL / 命令行直接交互

你可以使用任何支持 HTTP POST 的工具直接向端点发送 JSON-RPC 2.0 请求：

```bash
# 1. 探针健康检查（GET）
curl http://127.0.0.1:41352/mcp

# 2. 列出可用工具（POST）
curl -X POST http://127.0.0.1:41352/mcp \
  -H "Content-Type: application/json" \
  -H "x-api-key: ordo_sk_your_actual_key_here" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }'

# 3. 创建一条任务（POST）
curl -X POST http://127.0.0.1:41352/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ordo_sk_your_actual_key_here" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "create_tasks",
      "arguments": {
        "title": "完成 2026 Q4 财报整理",
        "priority": 3,
        "tags": ["财务", "重点工作"]
      }
    }
  }'
```

---

## 4. 全量 11 大 MCP 工具参考手册

| 工具名称 | 功能定位 | 主要入参 | 返回重点 |
|---|---|---|---|
| [`get_metadata`](#41-get_metadata) | 环境与分类元数据 | 无 | 当前时间、周几、时区、所有可用项目及颜色、所有标签及颜色 |
| [`query_tasks`](#42-query_tasks) | 任务多维高级查询 | `searchQuery`, `status`, `priority`, `projectId`, `fields`, `limit` | 匹配任务列表、总数、是否有更多（分页） |
| [`get_task`](#43-get_task) | 单任务深度查看 | `taskId` (必填) | 任务完整属性、项目名、递归子任务列表（层级树）、标签名 |
| [`create_tasks`](#44-create_tasks) | 创建任务 | `title` (必填), `projectId`, `priority`, `dueDate`, `tags`, `substeps`, `mode` | `status` (created/pending), `taskId` 或 `proposalId` |
| [`create_tasks_bulk`](#45-create_tasks_bulk) | 批量创建 (至多100条) | `tasks` (必填数组), `dryRun` (可选布尔) | 批量结果统计、每项成功 taskId 或校验失败错误清单 |
| [`update_task`](#46-update_task) | 更新任务属性 | `taskId` (必填), `title`, `status`, `priority`, `dueDate`, `projectId`, `tags` | 更新后状态、受影响属性清单 |
| [`delete_tasks`](#47-delete_tasks) | 批量删除任务 | `taskIds` (必填数组), `mode` | 删除成功数、失败原因 |
| [`list_proposals`](#48-list_proposals) | 查询提案审核队列 | `status` (pending/confirmed/rejected), `limit` | 暂存提案清单、原始荷载、创建时间与过期时间 |
| [`confirm_proposals`](#49-confirm_proposals) | 批量确认应用提案 | `proposalIds` (必填数组) | 成功落库数、每项对应的正式 `taskId` |
| [`reject_proposals`](#410-reject_proposals) | 批量废弃驳回提案 | `proposalIds` (必填数组), `reason` | 驳回状态与数量 |
| [`aggregate_tasks`](#411-aggregate_tasks) | SQL 原生快速统计 | `groupBy` (status/priority/project/tag), `completedScope` | 分组统计桶 (buckets)、各类任务总数 |

---

### 4.1 get_metadata
- **用途**：外部 AI 在对话开始时必须首先调用的基础工具。获取当前准确的绝对时间（解决 LLM 时间感知偏移），并获取应用当前定义的所有项目列表与标签列表。
- **示例入参**：`{}`
- **示例返回**：
  ```json
  {
    "now": {
      "iso": "2026-10-02T08:45:00.000Z",
      "date": "2026-10-02",
      "weekday": "Friday"
    },
    "projects": [
      { "id": "inbox", "name": "收件箱", "color": "#6C5CE7" },
      { "id": "proj-arch", "name": "系统架构优化", "color": "#3B82F6" }
    ],
    "tags": [
      { "id": "tag-1", "name": "重要", "color": "#EF4444" }
    ]
  }
  ```

---

### 4.2 query_tasks
- **用途**：基于任务查询引擎进行灵活的多条件组合查询。
- **入参说明**：
  - `searchQuery` *(string)*: 文本模糊搜索（匹配标题、富文本描述、子任务）
  - `status` *(string)*: `todo`, `in_progress`, `done`, `archived` 或复合取值 `all`, `active`, `completed`
  - `priority` *(int)*: 0 (无), 1 (低), 2 (中), 3 (高)
  - `projectId` *(string)*: 指定项目 ID
  - `tagIds` *(array of string)*: 过滤拥有指定标签的任务
  - `dueScope` *(string)*: `today`, `overdue`, `upcoming`, `nodate`
  - `fields` *(array of string)*: **字段投影**，仅返回需要的列（例如 `["id", "title", "status"]`），大幅降低 Token 消耗
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
        "priority": "high",
        "dueDate": "2026-10-05 18:00"
      }
    ]
  }
  ```

---

### 4.3 get_task
- **用途**：查看单个任务的完整细节，包含父子关联、子任务树、完整描述和关联标签。
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
        { "id": "sub-1", "title": "编写 pre-commit 脚本", "isCompleted": true },
        { "id": "sub-2", "title": "接入 GitHub Actions", "isCompleted": false }
      ]
    }
  }
  ```

---

### 4.4 create_tasks
- **用途**：创建新任务。支持自动拆解子任务并分配标签。
- **入参说明**：
  - `title` *(string, 必填)*: 任务标题（建议 200 字以内）
  - `projectId` *(string)*: 归属项目 ID（若不传默认归入 `inbox` 收件箱）
  - `description` *(string)*: 补充描述或 Markdown 备忘
  - `priority` *(int)*: 0 (无), 1 (低), 2 (中), 3 (高)
  - `dueDate` *(string/int)*: 截止时间（支持 `2026-10-05 18:00`、ISO8601 或时间戳毫秒）
  - `tags` *(array of string)*: 标签名称列表（若系统尚无该标签将自动创建）
  - `substeps` *(array of string)*: 子任务步骤列表（系统将自动创建层级关联）
  - `mode` *(string)*: 可显式指定 `'direct'`（直写）或 `'proposal'`（暂存）
  - `idempotencyKey` *(string)*: 客户端防重幂等键
- **示例返回**：
  ```json
  {
    "ok": true,
    "status": "created",
    "taskId": "7d9b9c02-...",
    "requiresConfirmation": false,
    "message": "Task created successfully."
  }
  ```

---

### 4.5 create_tasks_bulk
- **用途**：单次批量创建至多 100 项任务。
- **入参说明**：
  - `tasks` *(array of object, 必填)*: 任务列表，每个元素与 `create_tasks` 的属性一致
  - `dryRun` *(boolean, 可选)*: 若设为 `true`，**仅执行校验与推演，不执行落库**。用于外部 AI 在批量写入前向用户展示预览并确认有效性。
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
- **用途**：修改现有任务属性。
- **入参说明**：
  - `taskId` *(string, 必填)*: 目标任务 ID
  - `title` *(string)*: 新标题
  - `description` *(string)*: 新描述
  - `status` *(string)*: `todo`, `in_progress`, `done`, `archived`
  - `priority` *(int)*: 0, 1, 2, 3
  - `dueDate` *(string/int)*: 修改截止时间
  - `clearDueDate` *(boolean)*: 若为 true，清除截止日期
  - `projectId` *(string)*: 将任务移动到新项目
  - `tags` *(array of string)*: 全量覆盖标签
- **示例返回**：
  ```json
  {
    "ok": true,
    "taskId": "7d9b9c02-...",
    "updatedFields": ["status", "priority"],
    "requiresConfirmation": false
  }
  ```

---

### 4.7 delete_tasks
- **用途**：批量删除任务（级联清理子任务与标签映射）。
- **入参说明**：
  - `taskIds` *(array of string, 必填)*: 待删除的任务 ID 数组
- **示例返回**：
  ```json
  {
    "ok": true,
    "summary": { "requested": 2, "succeeded": 2, "failed": 0 },
    "deletedIds": ["id-1", "id-2"]
  }
  ```

---

### 4.8 提案管理工具 (list_proposals / confirm_proposals / reject_proposals)
- 当 Ordo 设置为「提案审核」模式，或调用写入工具时传入 `mode: "proposal"` 时：
  1. `list_proposals`：入参 `status: "pending"`，返回待处理的提案列表与内容；
  2. `confirm_proposals`：入参 `proposalIds: ["prop-id-1"]`，应用修改并返回正式 `taskId`；
  3. `reject_proposals`：入参 `proposalIds: ["prop-id-2"]`，驳回并废除提案。

---

### 4.9 aggregate_tasks
- **用途**：以 SQL 聚合高效洞察任务全局，避免拉取几百条任务导致上下文超限。
- **入参说明**：
  - `groupBy` *(string, 必填)*: 聚合维度，可选：
    - `priority` (按优先级统计)
    - `status` (按完成状态统计)
    - `project` (按归属项目统计)
    - `tag` (按标签统计)
  - `completedScope` *(string)*: 可选 `all`（全部任务）、`active`（仅进行中/未完成）或 `completed`（仅已完成）
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

你可以把以下 System Prompt 添加给你的 AI 助手，让它成为极致贴心的任务管家：

```markdown
你已接入我的本地个人任务管理系统 Ordo (ordo-tasks MCP)。
在处理我的任务和日常安排时，请遵守以下原则：
1. 始终在开始前调用 get_metadata 获取当前的绝对时间和我的项目列表；
2. 如果我要做大任务，请主动帮我调用 create_tasks，并自动拆解 3~5 个清晰可执行的 substeps，同时标注合理的 priority 和截止时间；
3. 如果我要查询任务，尽量使用 query_tasks 的 fields 字段投影（例如只请求 id, title, status, dueDate），节约 Token；
4. 如果我要全盘了解工作量或分类概况，优先调用 aggregate_tasks 汇总，不要把所有任务全拉出来；
5. 如果出现项目不存在的错误，请检查 get_metadata 里的可用 projectId 重新调整。
```

### 场景演示：
- **Prompt**: *“帮我制定今天下午的工作安排：写完接口文档，进行单元测试，并部署到测试服。紧急程度较高。”*
- **AI 动作**：
  1. 调用 `get_metadata` 确认今天是周五下午；
  2. 调用 `create_tasks`，参数为：
     - `title`: “完成接口文档与测试服部署”
     - `priority`: 3 (高优先级)
     - `dueDate`: “今天 18:00”
     - `tags`: [“开发”, “部署”]
     - `substeps`: [“编写接口文档”, “运行单元测试门禁”, “构建镜像并发布测试服”]
  3. 客户端直接持久化落库，手机/桌面端即刻展示！

---

## 6. 常见问题与排查 (Troubleshooting)

### Q1: 外部 AI 报错 `Unauthorized (-32001)`？
- **原因**：应用开启了“要求 API Key 鉴权”，但外部客户端请求头未携带或携带了错误的密钥。
- **解决**：在请求头添加 `x-api-key: ordo_sk_...` 或 `Authorization: Bearer ordo_sk_...`；或者在应用设置中暂时关闭鉴权开关。

### Q2: 提示 `PROJECT_NOT_FOUND` 错误？
- **原因**：传入的 `projectId` 在系统中不存在。
- **解决**：先调用 `get_metadata` 获取所有合法的项目 ID（如内置的 `inbox`，或项目专属的 UUID）；如果不确定，不传 `projectId` 即可自动放入“收件箱”。

### Q3: 为什么外部 AI 写入后我在列表里没看到任务？
- **排查 1**：检查应用设置中的 **「任务写入模式」** 是否被设置成了 **「提案审核」**。如果是审核模式，写入会暂存到提案队列，需要调用 `confirm_proposals` 确认后才会真正创建；直接切换为 **「直接写入」** 即可立即可见。
- **排查 2**：检查外部 AI 传入的 `mode` 参数是否为 `"proposal"`。

### Q4: 客户端重启后端口变了怎么办？
- Ordo MCP Server 默认绑定动态空闲端口以防止端口冲突。建议在系统托盘常驻 Ordo。若重启了应用，查看设置页最新端口更新外部客户端配置即可。
