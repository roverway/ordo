# SPEC-ai-copilot-assistant: 知序 (Ordo) AI 智能助理与效能诊断规格说明书

## Background / Goals / Non-goals

### Background
知序 (Ordo) 是一款注重优雅、有序、数据自持与离线优先的现代化待办与四象限时间管理工具。为了让全球用户更高效地完成任务录入、拆解规划以及周期复盘，应用需要引入基于大语言模型（LLM）的增强能力。通过由用户自主填写并存储 API Key（Bring Your Own Key, BYOK），不仅消除了中心化云端代理的隐私顾虑与运营成本，还赋能用户按需选择国内外不同的大模型服务商。

### Goals
1. **统一的 AI 配置中枢**：支持国内外主流大模型（DeepSeek、智谱 GLM 等国内服务商，以及 OpenAI、Anthropic Claude 等海外服务商）的配置存储与连通性验证。
2. **自然语言极速录入与智能拆解**：通过悬浮对话助手（Copilot），将用户零散的自然语言指令精确解析为结构化任务要素（标题、截止时间、开始时间、四象限优先级、标签），并在用户要求时智能拆解出可执行的子步骤列表。
3. **安全可控的 Human-in-the-loop 落库机制**：AI 识别出的任务和子步骤以可交互确认卡片形式呈现，经用户审核确认后，原子化写入本地 Drift 数据库并联动 UI 刷新。
4. **高质量的周期效能诊断与复盘**：基于用户近期的任务状态、四象限分布及完成/放弃趋势，生成图文结合的高信息密度效能诊断报告。
5. **严苛遵循设计令牌与 Linear 风格**：所有 AI 界面元素 100% 绑定知序现有的设计令牌（`AppTokens`），严禁任何魔法值；新增视觉组件全面采用极简科技感的 Linear 风格。

### Non-goals
1. **不做开放式闲聊与百科问答**：不实现通用的聊天机器人逻辑；对偏离待办与时间管理的问题进行礼貌重定向。
2. **第一期不做联网搜索与外部抓取**：不接入 Web 检索插件，所有推导基于模型自带推理能力与本地传入的待办数据。
3. **第一期不做重型本地向量库（Embedding / RAG）**：不引入端侧重型向量检索模型；复盘分析通过抽取结构化统计指标注入 Prompt 方式实现。
4. **第一期不对现有数据开放静默写/删权限**：AI 无法在未经用户点击确认的情况下静默新增、修改或批量删除数据库中的任务。

---

## Users & Scenarios (Top 3)

### Scenario 1: 自然语言单任务录入
- **用户**：忙碌的职场人 / 正在移动中记录想法的用户。
- **流程**：用户点击底部 AI FAB 打开助手抽屉，输入：“明天下午3点半前把Q3财务报表发给张总，紧急”。AI 解析并在对话流中生成包含预填属性（标题、截止时间、高优先级）的任务确认卡片。用户检查无误点击“添加到待办”，任务即刻写入收件箱并在四象限/清单中显示。

### Scenario 2: 复杂任务一键结构化拆解
- **用户**：面对大目标不知从何入手的学生或项目管理者。
- **流程**：用户输入：“周五下午4点前提交季度总结，帮我拆细”。AI 识别出主任务目标与时间，并向下拆分为 3~5 个具体子步骤（如：数据收集、草稿撰写、同行评审等）。用户可在卡片中勾选或微调子步骤，点击确认后，主子任务层级一次性落库。

### Scenario 3: 周期效能诊断与周报复盘
- **用户**：周日晚间进行一周复盘、希望改进时间管理习惯的深度用户。
- **流程**：用户在 AI 助手面板点击快捷指令「分析我这周的任务完成情况」。AI 读取本地近 7 天的任务完成率、四象限投入比例与放弃任务，输出包含核心指标卡片、象限分布简图（文字/进度条/轻量图表）及针对性管理建议的周度效能报告。

---

## Functional Requirements (P0 / P1 / P2)

### P0 (首期核心闭环)
- **FR-01 (AI 服务商配置与安全存储)**：
  - 在设置中提供独立「AI 助手设置」模块；
  - 支持配置国内模型（DeepSeek、GLM 等，基于兼容 OpenAI 规范的 Endpoint）、OpenAI（海外规范）与 Claude（Anthropic 规范）；
  - 支持字段：服务商类型、Base URL、API Key、模型名称（Model Name）；
  - API Key 必须使用 `flutter_secure_storage` 安全隔离持久化，非敏感项（服务商、模型名）保存于 settings 表；
  - 提供「测试连接」按钮，能发起最小 Ping 请求验证连通性并友好报错。
- **FR-02 (主界面双 FAB 交互与入口)**：
  - 将底部浮动操作按钮拆分为「原生快速新增」与「AI 助手」两个独立 FAB；
  - 两者采用不同的图标（如 `add` vs `auto_awesome`）与视觉层级（主副强调色），避免点击混淆；
  - 点击 AI FAB 平滑拉起半屏/全屏对话抽屉面板（移动端 BottomSheet，宽屏桌面端 Side Sheet）。
- **FR-03 (自然语言任务解析与卡片输出)**：
  - 提示词工程（Prompt Engineering）要求模型以结构化 JSON 返回任务要素：`title`, `dueAt`, `startAt`, `priority` (0-3), `tags`, `substeps`；
  - 用户输入纯任务时，只提取任务属性，不自动生成子步骤；用户明确包含“拆细/分解/拆解”意图时，一并生成推荐子步骤列表；
  - 在对话流中渲染交互式「待创建任务确认卡片」，支持预览所有识别出的字段。
- **FR-04 (结构化任务数据原子落库接口)**：
  - 提供数据持久化服务 `AiTaskPersistenceService`，将确认卡片中的任务与子步骤（`parentId` 树形关联）保存至 Drift 数据库（`TodoRepository.createTask`）；
  - 落库成功后向全局触发响应式刷新（四象限视图、主任务列表即时反映），并标记卡片为“已添加”防止二次点击。

### P1 (完善体验与复盘)
- **FR-05 (效能诊断与结构化周报)**：
  - 提供快捷 Prompt 按钮「分析我这周的任务完成情况」；
  - 本地统计引擎抓取近 7 天数据：已完成任务数、已放弃数、新建数、逾期数、各四象限耗时/数量占比；
  - AI 结合统计数据，输出结合指标排版、ASCII/视觉进度柱与文字分析的效能报告。
- **FR-06 (卡片级就地编辑)**：
  - 允许用户在点击“添加到待办”前，直接在卡片上微调标题、修改截止时间、增删或取消勾选某几个子步骤。
- **FR-07 (对话上下文与轻量历史)**：
  - 当前会话支持多轮指引调整（例如：“把第二步改成明天完成”）；
  - 关闭抽屉后保留最近一次会话内容，支持一键“清空对话”。

### P2 (后续进阶与原位沉淀)
- **FR-08 (原位功能沉淀 - In-place Actions)**：
  - 沉淀为现有任务创建栏的“智能解析”魔法棒图标，以及任务详情页内的“一键 AI 拆解”按钮。
- **FR-09 (历史周报归档与导出)**：
  - 支持将效能诊断周报以 Markdown 或图片形式导出分享。

---

## Non-functional Requirements

### 1. 设计令牌与视觉规范 (UI/UX Design Tokens & Linear Style)
- **NF-01 (零魔法值原则 - Zero Magic Values)**：
  - 所有新实现的 AI 界面（抽屉面板、气泡、卡片、输入框、按钮等）**严禁出现任何硬编码魔法值**（违反 `AGENTS.md §3-9` 将无法合入）；
  - 颜色一律取自 `Theme.of(context).colorScheme` 或 `AppTokens`（如 `AppTokens.surfaceCardDark`, `AppTokens.surfacePageDark`, `AppTokens.colorPriorityHigh` 等）；
  - 容器圆角统一使用 `AppTokens.radiusCard` (12dp)、`AppTokens.radiusSheet` (22dp)、`AppTokens.radiusButton` (12dp)、`AppTokens.radiusPill` (999dp)；
  - 半透明罩染与描边强度统一采用语义令牌（`AppTokens.alphaTintFaint`, `AppTokens.alphaBorderSubtle`, `AppTokens.alphaBorderEmphasis` 等）。
- **NF-02 (Linear 极简现代设计风格 - Linear Aesthetics)**：
  - **暗色质感**：深层黑曜石底色（`surfacePageDark`）搭配轻微抬升的卡片容器（`surfaceCardDark`），边缘采用 1px 的超轻微光描边（`borderSubtleDark`，Hover 时高亮至 `borderSubtleHoverDark`）；
  - **浅色质感**：冷调洁净底色（`surfacePageLight`）配合纯白卡片（`surfaceCard`）与低对比度描边（`borderSubtleLight`）；
  - **组件质感**：快捷 Prompt 采用胶囊形态（Capsule / Pill），确认卡片内各属性条目拥有微弱内凹/浮动层次感，字体层次分明，排版紧凑克制，杜绝高饱和度大面积色块。

### 2. 安全与合规 (Security & Licensing)
- **NF-03 (API Key 安全)**：API Key 严禁写入普通日志、明文 SharedPreferences 或随备份包导出（除非用户显式要求加密备份）。在内存中按需加载，静态存储于系统级安全沙箱（KeyStore / KeyChain / Libsecret）。
- **NF-04 (开源协议兼容)**：引入的任何外部 Dart 依赖必须采用宽松协议（MIT、Apache-2.0、BSD-3-Clause），严禁引入 GPL/AGPL 等具有传染性的开源库，保障与知序（Ordo）的“非商业开源与商业双重授权（Dual License）”绝对兼容。

### 3. 性能与响应 (Performance)
- **NF-05 (首字与流式渲染响应)**：AI 网络请求支持流式（Streaming/SSE）或打字机动效，流式响应下首字渲染延迟控制在 1.5 秒内（视模型服务商响应速度而定），杜绝整段等待导致的界面卡死感。
- **NF-06 (本地落库耗时)**：用户点击“添加到待办”到本地 SQLite 写入并通知 UI 刷新的耗时不超过 100ms。

### 4. 可靠性与容错 (Reliability)
- **NF-07 (网络异常隔离)**：模型超时、鉴权失败、欠费或断网时，给出人类可读的友好提示（如“网络连接超时，请检查 API Key 或代理设置”），保证主应用各待办功能稳定不受任何影响。
- **NF-08 (JSON 容错兜底)**：若大模型输出格式未严格遵循 JSON（例如附带前置或后置说明文本），解析层具备自动正则提取 `{...}` 块与 Markdown 代码块剥离的鲁棒性。

### 5. 多平台与多语言 (Compatibility & i18n)
- **NF-09 (多端布局适配)**：移动端（Android/iOS）使用 BottomSheet 抽屉；桌面端（Linux/Windows/macOS）使用右侧固定宽度的 Side Sheet，保证不破坏现有的桌面端双栏/三栏布局。
- **NF-10 (国际化)**：所有界面文案、系统 Prompt、快捷按钮均通过 `core/l10n`（`app_zh.arb` 与 `app_en.arb`）实现中英双语自适应。

---

## UX / API / Data

### 1. UX 交互流程与 Linear 风格组件
```
[主界面]
   ├── [原生 FAB (+)] ──> 原生任务快速创建框 (保留原有体验)
   └── [AI FAB (✨)]  ──> 呼出 AI 助手面板 (BottomSheet / Side Sheet)
                             │
                             ├── [Linear 快捷 Prompt 胶囊群] ("生成周报", "帮我规划今天")
                             ├── [聊天输入框] (Linear 微光边框 + 沉浸背景)
                             │
                             ▼ (AI 识别并回复)
                       [Linear 风格结构化确认卡片]
                         ├── 标题区：14-16sp 加粗文本 + 象限彩色微标 (AppTokens.colorPriority*)
                         ├── 时间/标签区：低透明度底色胶囊 (radiusChip / alphaTintSoft)
                         ├── (可选) 推荐子步骤勾选单：AppTokens.checkboxShape 极细边框
                         └── 底部操作区：[编辑] / [Linear 风格主操作按钮: 添加到待办]
                                      │ (点击确认)
                                      ▼
                             写入本地 Drift 数据库
                             -> 卡片状态平滑过渡为“已加入”
                             -> 全局任务流/四象限即时响应刷新
```

### 2. Data Contract (AI 结构化任务 JSON Schema)
```json
{
  "title": "string (1-200 字符，必填)",
  "description": "string (可选，任务备注说明)",
  "priority": 0, // 0: none, 1: low, 2: medium, 3: high (对应四象限)
  "startAt": 1727500800000, // UTC 毫秒时间戳，可选
  "dueAt": 1727533200000,   // UTC 毫秒时间戳，可选
  "tags": ["工作", "财务"],  // 标签名称数组，可选
  "substeps": [              // 子步骤列表，仅在用户要求拆解时包含
    {
      "title": "收集各部门报表数据",
      "sortOrder": 0
    },
    {
      "title": "核对收支流水与总账",
      "sortOrder": 1
    }
  ]
}
```

### 3. API 架构协议层
- **通用 OpenAI 兼容层 (`OpenAiCompatibleClient`)**：
  - 端点：`POST {baseUrl}/chat/completions`
  - 适配对象：DeepSeek, 智谱 GLM (OpenAI SDK 格式), Moonshot, OpenAI, Groq, 自建 Ollama 等。
  - 请求体：标准 `messages`, `temperature: 0.2`, `response_format: {"type": "json_object"}` (针对支持的模型启用)。
- **Claude 原生层 (`AnthropicClient`)**：
  - 端点：`POST https://api.anthropic.com/v1/messages`
  - 请求头：`x-api-key`, `anthropic-version: 2023-06-01`。
- **协议隔离层 (`AiServiceProvider`)**：
  - 向上暴露统一的 `Future<AiTaskParseResult> parseTask(String input)` 与 `Stream<String> generateReviewStream(EfficiencyStats stats)` 接口。

---

## Edge Cases

1. **用户输入模糊或与待办完全无关**：
   - *示例*：“给我讲个笑话” 或 “今天天气真好”。
   - *处理*：AI 识别到无有效任务意图，卡片不生成，输出友好引导：“我是您的待办助手，请告诉我您想规划什么任务或复盘近期的执行情况～”。
2. **时间推断上下文（相对时间 vs 绝对时间）**：
   - *示例*：“周五下午4点开会”。
   - *处理*：系统 Prompt 中动态注入当前的本地时间戳、星期几以及用户时区偏移量，确保模型正确将“周五”换算为准确的绝对 UTC 毫秒时间戳。
3. **标签与项目不存在**：
   - *处理*：若解析出的标签在本地 `tags` 表中不存在，创建任务时一并新增对应标签并建立关联；项目若未指定，严格遵循产品规则落入内置收件箱 `inboxProjectId`。
4. **模型偶发性输出畸形 JSON**：
   - *处理*：解析层采用“清洗器 -> 正则提取 -> JsonDecoder -> 校验器”流水线；若完全解析失败，回退为将用户输入的原文直接作为任务标题生成纯文本卡片，并标记“AI 无法精确解析，请手动检查”。
5. **用户离线或断网**：
   - *处理*：直接在聊天气泡提示“无法连接至 AI 服务，请检查网络连接”，并提供“重试”按钮，不出现未捕获异常。

---

## Acceptance Criteria (Given-When-Then)

### 场景 1：AI 配置与测试连通
- [ ] **AC-01 (配置持久化)**：
  - **Given** 用户进入「设置 -> AI 助手设置」；
  - **When** 用户填入 DeepSeek API Key、Base URL，并选择保存；
  - **Then** API Key 被安全存储至 `flutter_secure_storage`，再次进入该页面可回显脱敏 Key（如 `sk-****abcd`）。
- [ ] **AC-02 (连通性测试通过与失败)**：
  - **Given** 用户在配置页面点击「测试连接」；
  - **When** 填入有效 Key 时，**Then** 显示绿色“连接成功”提示；
  - **When** 填入无效 Key 或断网时，**Then** 弹窗或 SnackBar 显示具体错误原因（如 HTTP 401 鉴权失败或网络不可达），应用不崩溃。

### 场景 2：双 FAB 与入口呼出
- [ ] **AC-03 (双 FAB 正常渲染与独立响应)**：
  - **Given** 用户处于主界面（清单、四象限等）；
  - **When** 查看右下角；
  - **Then** 呈现平行的两个 FAB（原生新增 FAB 与 AI 助手 FAB），视觉区隔明显；
  - **When** 点击原生 FAB，唤起原有创建输入框；点击 AI FAB，平滑拉起 AI 对话面板。

### 场景 3：自然语言智能识别（仅录入）
- [ ] **AC-04 (识别要素并出卡片，不拆细)**：
  - **Given** 打开 AI 对话面板；
  - **When** 用户输入“周五下午4点前提交季度总结”；
  - **Then** 对话框渲染任务卡片：标题为“提交季度总结”，截止时间正确匹配本周五 16:00，无子步骤列表。
- [ ] **AC-05 (落库与全局刷新)**：
  - **Given** 呈现上一条任务卡片；
  - **When** 用户点击卡片上的“添加到待办”按钮；
  - **Then** 任务成功写入本地数据库，卡片按钮置灰变为“已添加”，返回主界面或四象限视图可立即看到新任务。

### 场景 4：智能识别与多步骤拆解
- [ ] **AC-06 (识别并拆分子步骤)**：
  - **Given** 打开 AI 对话面板；
  - **When** 用户输入“周五下午4点前提交季度总结，帮我拆细”；
  - **Then** 任务卡片中不仅包含主任务属性，还展示 3~5 个子步骤勾选项（如“1. 收集数据”、“2. 编写草稿”等）。
- [ ] **AC-07 (子任务关联落库)**：
  - **Given** 呈现包含子步骤的卡片；
  - **When** 用户取消勾选其中 1 项，点击“添加到待办”；
  - **Then** 本地数据库生成主任务，并为保留的子项生成 `parentId = 主任务.id` 的子任务，四象限与任务详情中层级关系正确呈现。

### 场景 5：周期效能诊断与复盘
- [ ] **AC-08 (提取本地近 7 天数据并生成图文周报)**：
  - **Given** 打开 AI 对话面板；
  - **When** 用户点击快捷指令「分析我这周的任务完成情况」；
  - **Then** 系统在后台汇算近 7 天统计指标（完成数、放弃数、象限比）注入提示词；
  - **Then** AI 输出排版精美、包含指标摘要与象限占比的文字与可视化图表报告，并给出改进建议。

### 场景 6：设计令牌一致性与无魔法值约束 (Linear 风格)
- [ ] **AC-09 (设计令牌与零魔法值检查)**：
  - **Given** 开发者完成 AI 助手相关所有 UI 代码（双 FAB、对话抽屉、气泡、卡片、设置页）；
  - **When** 执行代码审查与静态搜索；
  - **Then** 确认没有任何写死的 `Color(0x...)`、裸数字圆角 `BorderRadius.circular(12)` 或未收敛的 padding 魔法值，所有视觉样式均严格引用 `AppTokens` 或 `Theme.of(context).colorScheme`；
  - **Then** 在深色与浅色主题下分别验证，卡片微光边框、暗色背景提升层级以及胶囊圆角均符合 Linear 极简审美。

---

## Open Questions

- `[假设]` **OpenAI 兼容协议作为国内模型通用底座**：DeepSeek、智谱 GLM、通义千问等主流服务商均提供完全兼容 OpenAI `v1/chat/completions` 的 API 端点。因此底座通用客户端以 OpenAI 规范为主，可覆盖 95% 以上使用场景。
- `[假设]` **海外模型测试账户**：目前环境具备国内模型（如 DeepSeek/GLM）测试凭证进行连调，海外 OpenAI 和 Claude 提供标准接口集成并在界面提供配置项，预留 Mock/Fake 单元测试以备后续用户填入真实 Key 测试。
- `[假设]` **开源依赖协议**：选用轻量官方或社区纯 Dart 库（需核查 License 为 MIT/Apache-2.0/BSD），或直接使用 Dart 原生 `http` 结合 JSON Codec 实现无第三方依赖的高内聚客户端。

---

## References

- **需求纪要**：本次对话中的 `grill-me` 对齐纪要
- **架构与设计规范**：
  - `docs/20-tech-stack.md`: 技术栈标准
  - `docs/30-architecture.md`: 架构分层
  - `docs/40-data-model.md §2.2`: `tasks` 表模型规范（`id`, `parentId`, `priority`, `startAt`, `endAt`）
  - `docs/40-data-model.md §2.5`: `settings` 表与安全隔离规范（敏感凭证严禁存 settings，走 `flutter_secure_storage`）
  - `lib/core/theme/app_tokens.dart`: 知序设计令牌（`AppTokens`）
  - `docs/66-ui-visual-polish-proposal.md`: 视觉与设计令牌收敛规范
  - `AGENTS.md §3-9`: “所有 UI 代码必须引用 AppTokens，禁止魔法值”
  - `lib/core/db/repositories/todo_repository.dart`: 任务创建与事务入口
  - `lib/core/security/secure_store.dart`: 本地凭证安全存储封装
  - `LICENSE`: 知序软件授权许可协议（非商业开源与商业双重授权）
