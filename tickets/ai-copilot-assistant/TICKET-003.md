# TICKET-003: 主界面双 FAB 改造与 Linear 风格抽屉容器

## Goal
将主界面右下角的单个新增操作拆分为平行的双 FAB（原生新增 + AI 助手），色调与图标清晰区分；点击 AI FAB 能平滑拉起符合 Linear 极简审美的抽屉容器（移动端 BottomSheet / 宽屏桌面端 Side Sheet），内含对话输入框与快捷 Prompt 胶囊，全流程严格遵循设计令牌（零魔法值）。

---

## Scope
- **修改/新增文件**：
  - `lib/features/home/widgets/home_fab.dart` 或现有主界面 FAB 宿主文件：改造为双 FAB 并列布局
  - `lib/features/ai_copilot/views/ai_copilot_sheet.dart`：移动端底部抽屉与桌面端侧边抽屉容器
  - `lib/features/ai_copilot/widgets/ai_prompt_capsule.dart`：Linear 风格胶囊组件（`AppTokens.radiusPill`）
  - `lib/features/ai_copilot/widgets/ai_chat_input_box.dart`：Linear 风格输入框（微光边框与发送交互）
  - `lib/core/l10n/app_zh.arb` & `app_en.arb`：多语言支持
- **Out of scope**：
  - 任务确认卡片的内部复杂业务交互（留给 TICKET-004）；
  - 效能周报的图表视图（留给 TICKET-005）。

---

## Depends on
none

---

## Steps
1. **重构底部 FAB 组件**：
   - 保留原有的主操作 FAB（`Icons.add`，主强调色），在其旁新增次级 AI FAB（`Icons.auto_awesome`，微光暗色/品牌紫色，`AppTokens.radiusButton`）；
   - 点击原生 FAB 保持既有行为；点击 AI FAB 触发拉起抽屉控制器。
2. **构建 Linear 极简抽屉面板框架**：
   - 响应式适配：屏幕宽度 < 600dp 时以 `showModalBottomSheet` 展现，顶部带标准抓手（`AppTokens.sheetGrabber*`）；宽屏桌面端使用侧边滑出面板；
   - 容器背景采用 `AppTokens.surfacePageDark` / `surfacePageLight`，顶部标题栏带有清空对话与关闭按钮。
3. **实现 Linear 快捷 Prompt 胶囊组件**：
   - 横向滚动展示快捷指令胶囊（“生成周报”、“帮我规划今天”、“帮我拆解任务”）；
   - 样式：`AppTokens.radiusPill`，暗色下微光边框 `AppTokens.borderSubtleDark`，点击有轻柔按压动效。
4. **实现沉浸式输入框组件**：
   - 支持回车或点击发送箭头；输入框获得焦点时呈现柔和的高亮轮廓线（`borderSubtleHoverDark`）；
   - 禁用态与空输入校验。
5. **设计令牌静态审查**：
   - 逐行校验组件代码，杜绝硬编码颜色与数字圆角，确保 100% 绑定 `AppTokens`。

---

## Acceptance
- [x] **AC-01 (双 FAB 布局与独立点击)**：
  - **Given** 用户进入任务列表或四象限主界面；
  - **When** 观察底部悬浮操作区；
  - **Then** 呈现两个独立 FAB，原生新增与 AI 助手图标明确分离；
  - **When** 点击原生 FAB，唤起原有新增对话框；点击 AI FAB，平滑拉起抽屉。
- [x] **AC-02 (移动端与桌面端自适应容器)**：
  - **Given** 窄屏环境（如手机）；
  - **When** 点击 AI FAB；
  - **Then** 底部弹起具有圆角（`AppTokens.radiusSheet`）的半屏/全屏 BottomSheet；
  - **Given** 宽屏桌面端环境；
  - **When** 点击 AI FAB；
  - **Then** 右侧平滑滑出固定宽度（如 380dp）的 Side Sheet 且不遮挡主内容。
- [x] **AC-03 (快捷 Prompt 胶囊可点击填充)**：
  - **Given** 展开 AI 抽屉；
  - **When** 点击“帮我规划今天”胶囊；
  - **Then** 该文本自动填充入输入框或直接作为指令触发。
- [x] **AC-04 (零魔法值与 Linear 风格质感)**：
  - **Given** 在暗色和浅色主题之间切换；
  - **When** 查看抽屉边框、胶囊阴影与文字对比度；
  - **Then** 呈现纯正 Linear 极简科技质感，静态检查无裸硬编码数值。

---

## Test plan
- **Widget 测试**：
  - `test/features/home/home_double_fab_test.dart`：验证双 FAB 正确渲染且两个点击回调互不干扰。
  - `test/features/ai_copilot/ai_copilot_sheet_test.dart`：测试抽屉的弹出、输入框交互及快捷胶囊点击事件。
- **视觉验证**：
  - 在亮色与暗色模式下核对视觉一致性，确保边框与对比度符合设计规范。

---

## Status
done
