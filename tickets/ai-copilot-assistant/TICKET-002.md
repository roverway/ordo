# TICKET-002: 自然语言结构化解析与任务树原子落库服务

## Goal
实现一套将自然语言输入精确解析为结构化待办要素（标题、起止时间、四象限优先级、标签、可选子步骤）的大模型提示词流水线，并提供将解析数据安全、原子化写入本地 Drift 数据库的领域持久化服务。

---

## Scope
- **修改/新增文件**：
  - `lib/core/ai/prompts/task_parse_prompts.dart`：任务解析系统提示词与 Few-Shot 模板
  - `lib/core/ai/models/ai_task_parse_result.dart`：结构化任务数据模型与 JSON 反序列化器
  - `lib/core/ai/services/ai_task_parser.dart`：流式/非流式响应清洗与容错提取服务
  - `lib/core/ai/services/ai_task_persistence_service.dart`：对接 `TodoRepository` 的落库服务（处理主任务创建、子任务树 `parentId` 关联、标签自动创建）
- **Out of scope**：
  - 不涉及对话界面的 UI 渲染；
  - 不直接绑定 FAB。

---

## Depends on
[TICKET-001](TICKET-001.md)

---

## Steps
1. **设计结构化 Prompt 模板**：
   - 系统 Prompt 严格注入当前用户本地时间（UTC 毫秒、星期几、时区）；
   - 规定标准 JSON Schema；当用户无拆细意图时仅识别任务属性，包含拆解意图时生成 3~5 个子步骤。
2. **构建容错 JSON 提取器**：
   - 编写 `extractJsonPayload(String response)`，具备自动去除 Markdown ` ```json ` 标记与截取首尾 `{...}` 的鲁棒性。
3. **实现 `AiTaskParser` 服务**：
   - 结合 `AiClient` 发起对话解析，将模型回复反序列化为 `AiTaskParseResult` 实体，校验字段合法性（标题长度 1-200，四象限 0-3）。
4. **实现 `AiTaskPersistenceService` 原子落库**：
   - 调用 `TodoRepository.createTask` 创建主任务（默认落入 `inboxProjectId`）；
   - 若含子步骤，遍历创建 `parentId = 主任务.id` 的子任务；
   - 若含新标签，自动创建并插入 `task_tags` 关联。

---

## Acceptance
- [x] **AC-01 (单任务要素准确提取)**：
  - **Given** 输入“周五下午4点开周会 #工作”；
  - **When** 调用 `AiTaskParser.parse`；
  - **Then** 返回 `AiTaskParseResult`：标题为“开周会”，标签包含“工作”，截止时间正确对应周五 16:00，`substeps` 为空。
- [x] **AC-02 (带拆解意图的子步骤提取)**：
  - **Given** 输入“明天中午前写完项目周报，帮我拆细”；
  - **When** 调用 `AiTaskParser.parse`；
  - **Then** 返回结果中 `substeps` 包含 3~5 个条目（如“收集数据”、“起草内容”、“校对发送”）。
- [x] **AC-03 (原子落库完整性与树形结构)**：
  - **Given** 一个包含 3 个子步骤的 `AiTaskParseResult`；
  - **When** 调用 `AiTaskPersistenceService.persist`；
  - **Then** 本地 SQLite 数据库中生成 1 条父任务与 3 条子任务（`parentId` 指向父任务 `id`），标签关系正确写入。
- [x] **AC-04 (畸形输出优雅容错)**：
  - **Given** 模型返回包含额外解释性文本（如“好的，这是为您解析的任务：{...}祝您工作顺利！”）；
  - **When** 执行解析；
  - **Then** 自动清洗剥离外部文本并成功解析核心 JSON，不抛出格式异常。

---

## Test plan
- **单元测试**：
  - `test/core/ai/task_parse_prompts_test.dart`：验证时间注入与提示词完整性。
  - `test/core/ai/ai_task_parser_test.dart`：测试标准 JSON、带 Markdown 围栏 JSON、包含干扰文本 JSON 的提取鲁棒性。
  - `test/core/ai/ai_task_persistence_service_test.dart`：使用内存数据库验证单任务创建、父子级联任务创建与标签级联关联。

---

## Status
done
