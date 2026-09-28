# TICKET-001: AI 服务商配置中枢与安全连通测试

## Goal
用户可以在设置页面中配置大语言模型服务商（国内外主流：DeepSeek、智谱 GLM、OpenAI、Claude 等）的 Base URL、API Key 与 Model Name，凭证安全持久化，并能一键点击“测试连接”验证网络连通性与鉴权状态。

---

## Scope
- **修改/新增文件**：
  - `lib/core/ai/models/ai_config.dart`：AI 配置实体与提供商枚举定义
  - `lib/core/ai/services/ai_client.dart`：轻量协议请求抽象层（OpenAI 兼容协议 + Claude 消息协议）
  - `lib/core/ai/services/ai_config_service.dart`：配置存取服务（API Key 走 `flutter_secure_storage`，非敏感项走 Drift settings 表）
  - `lib/features/settings/views/ai_settings_page.dart`：设置子页面（Linear 风格，严格引用 `AppTokens`，零魔法值）
  - `lib/core/l10n/app_zh.arb` & `app_en.arb`：中英文配置与错误提示文案
- **Out of scope**：
  - 不涉及对话界面的展示；
  - 不涉及任务的实际解析与落库。

---

## Depends on
none

---

## Steps
1. **定义 AI 配置模型与枚举**：创建 `AiProviderType`（`deepseek`, `glm`, `openai`, `claude`, `custom`），包含各提供商的默认 Base URL 和预设模型名。
2. **凭证持久化隔离**：实现 `AiConfigService`，将 API Key 写入 `FlutterSecureStorage`，其余非敏感字段（provider, baseUrl, model）持久化在 `Settings` 表。
3. **轻量请求与 Ping 连通层**：编写基于标准 HTTP 协议的最小 Ping 请求（如向 `/chat/completions` 发送仅 1 token 的测试请求），捕获 401（鉴权失败）、404、网络不可达并返回结构化诊断结果。
4. **构建 Linear 风格设置页面**：
   - 使用 `AppTokens.surfaceCardDark` / `surfaceCard` 构建配置分组卡片；
   - 包含服务商下拉/切换器、Base URL、Model Name、API Key 密码输入框与“测试连接”操作按钮；
   - 严格消除所有魔法值，全部引用 `AppTokens`。
5. **挂载路由与多语言**：在设置页新增“AI 助手设置”入口项，配置 GoRouter 路由与中英文 ARB 本地化。

---

## Acceptance
- [x] **AC-01 (配置安全持久化与回显)**：
  - **Given** 用户在「设置 -> AI 助手设置」输入有效 API Key 与模型名称并保存；
  - **When** 退出该页面并重新进入；
  - **Then** 配置正确回显，API Key 处于脱敏展示状态（如 `sk-****`）。
- [x] **AC-02 (真实连通测试成功)**：
  - **Given** 配置正确的 DeepSeek / GLM 或兼容服务商 API Key；
  - **When** 点击「测试连接」按钮；
  - **Then** 按钮呈现加载态，随后展示绿色“连接成功”提示并显示响应耗时。
- [x] **AC-03 (连通测试异常隔离与提示)**：
  - **Given** 填写错误的 API Key 或无网络环境；
  - **When** 点击「测试连接」；
  - **Then** 明确提示“身份鉴权失败 (401)”或“网络连接超时”，应用不发生未捕获异常。
- [x] **AC-04 (零魔法值代码合规)**：
  - **Given** 审查 `ai_settings_page.dart` 及相关组件代码；
  - **When** 检查颜色、边距和圆角；
  - **Then** 100% 引用 `AppTokens`，无任何硬编码数字。

---

## Test plan
- **单元测试**：
  - `test/core/ai/ai_config_service_test.dart`：验证配置保存、安全读取、脱敏逻辑及 Mock 存储。
  - `test/core/ai/ai_client_test.dart`：使用 Mock HTTP Client 验证 Ping 请求在 200、401、500 及网络超时下的解析行为。
- **手工验证**：
  - 在 Linux/Android 平台进入设置页，输入实际 DeepSeek API Key 点击“测试连接”，验证真实连通。

---

## Status
done


---

## Verification & Implementation Notes
- **TDD Unit Tests**:
  - `test/core/ai/ai_config_service_test.dart` (6 passed): 验证凭证安全隔离存储、脱敏脱密逻辑、默认服务商配置。
  - `test/core/ai/ai_client_test.dart` (7 passed): 验证 OpenAI 与 Claude 协议 Ping、URL 规整、401/404/超时/网络异常结构化错误诊断。
- **Widget Integration Tests**:
  - `test/features/settings/ai_settings_page_test.dart` (5 passed): 验证默认值渲染、脱敏回显与保存持久化、测连成功耗时徽章、测连失败 401 诊断提示、服务商切换。
- **Lint & Static Analysis**:
  - `flutter analyze`: 0 errors, 0 warnings.
- **Design Tokens Compliance**:
  - 100% 遵循 `AppTokens` 设计系统，严格零裸数值与零魔法颜色。
