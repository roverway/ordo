# TICKET-004: 智能任务录入与多步骤拆解卡片端到端闭环

## Goal
打通自然语言智能建任务与子步骤拆解的端到端交互闭环：用户在 AI 抽屉中输入任务指令，AI 返回 Linear 风格的结构化任务确认卡片（含任务属性预览及子步骤复选列表）；用户确认无误后点击“添加到待办”，数据安全落库，卡片状态流转，四象限与清单视图即时响应刷新。

---

## Scope
- **修改/新增文件**：
  - `lib/features/ai_copilot/models/ai_chat_message.dart`：消息实体（支持文本消息与任务提案卡片实体）
  - `lib/features/ai_copilot/providers/ai_copilot_controller.dart`：Riverpod 会话状态机控制器
  - `lib/features/ai_copilot/widgets/ai_task_proposal_card.dart`：Linear 风格结构化确认卡片组件
  - `lib/features/ai_copilot/views/ai_copilot_sheet.dart`：对话消息流渲染列表与卡片装配集成
- **Out of scope**：
  - 效能周报和聚合统计视图（留给 TICKET-005）。

---

## Depends on
[TICKET-002](TICKET-002.md), [TICKET-003](TICKET-003.md)

---

## Steps
1. **定义对话状态机与控制器**：
   - 使用 Riverpod 创建 `AiCopilotNotifier`，维护当前消息流列表、加载/思考中状态以及错误提示；
   - 整合 `AiTaskParser` 发起分析。
2. **构建 Linear 风格任务确认卡片 (`AiTaskProposalCard`)**：
   - 容器：`AppTokens.surfaceCardDark` / `surfaceCard`，带 `AppTokens.radiusCard` 与微光边框；
   - 顶部区域：任务标题（加粗，支持点击行内修改），四象限彩色微标（`AppTokens.colorPriority*`）；
   - 元数据行：截止时间胶囊、预判标签胶囊；
   - 子步骤列表：带现代复选框（`AppTokens.checkboxShape`），支持勾选/取消某项或新增子项；
   - 操作按钮：“添加到待办”（强调按钮，带轻微发光质感）与“放弃”。
3. **实现落库联动与状态流转**：
   - 用户点击“添加到待办”时，调用 `AiTaskPersistenceService.persist` 写入本地数据库；
   - 写入成功后卡片按钮平滑转为“已添加”置灰态，防止重复提交；
   - 触发全局任务列表与四象限视图的响应式刷新。
4. **异常与边缘场景处理**：
   - 若用户输入与待办无关或无法解析，卡片不展示，助手输出友好引导气泡；
   - 断网或 Key 错误时展示带重试动作的气泡。
5. **设计令牌与无魔法值审查**：
   - 确保卡片内的各子元素（复选框、标签微标、圆角、分割线）100% 引用 `AppTokens`。

---

## Acceptance
- [x] **AC-01 (普通录入任务卡片生成与落库)**：
  - **Given** 用户在 AI 抽屉输入“周五下午4点前提交季度总结”；
  - **When** AI 返回响应；
  - **Then** 渲染结构化确认卡片，标题为“提交季度总结”，截止时间正确标识为本周五 16:00，无子步骤列表；
  - **When** 点击“添加到待办”；
  - **Then** 本地 SQLite 写入该任务，卡片变为“已添加”，四象限和主清单即时显示该任务。
- [x] **AC-02 (带拆细指令的任务卡片与子步骤勾选)**：
  - **Given** 用户输入“周五下午4点前提交季度总结，帮我拆细”；
  - **When** AI 返回响应；
  - **Then** 任务卡片内展示 3~5 个推荐子步骤；
  - **When** 用户取消勾选第 2 个子步骤，点击“添加到待办”；
  - **Then** 数据库成功创建父任务以及剩余勾选的子任务（`parentId` 关联正确），层级关系即刻在任务树中反映。
- [x] **AC-03 (防止重复落库机制)**：
  - **Given** 任务卡片已被点击添加到待办；
  - **When** 再次点击；
  - **Then** 按钮保持禁用，不会向数据库重复插入两次相同数据。
- [x] **AC-04 (视觉与设计令牌合规)**：
  - **Given** 检查 `AiTaskProposalCard` 源码；
  - **When** 检查间距、边框、字体与颜色；
  - **Then** 零魔法值，在深色模式下具有纯正的 Linear 极简质感。

---

## Test plan
- **Widget 测试**：
  - `test/features/ai_copilot/ai_task_proposal_card_test.dart`：测试卡片各元素渲染、子步骤勾选切换及点击落库回调。
- **集成测试 / Controller 测试**：
  - `test/features/ai_copilot/ai_copilot_controller_test.dart`：Mock 解析器，测试用户发送文本 -> 生成提案卡片 -> 点击落库 -> 数据库与状态流协同全流程。

---

## Status
done
