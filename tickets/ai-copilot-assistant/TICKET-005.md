# TICKET-005: 近 7 天周期效能诊断与高信息密度图文周报

## Goal
用户点击快捷指令「分析我这周的任务完成情况」时，系统自动汇算本地过去 7 天任务数据（完成数、放弃数、四象限投入比、逾期趋势），由大模型生成高信息密度的效能诊断与图文周报，结合 Linear 风格的指标进度条与排版卡片呈现直观反馈与行动建议。

---

## Scope
- **修改/新增文件**：
  - `lib/core/ai/services/efficiency_stats_service.dart`：从本地 Drift 数据库提取近 7 天聚合统计
  - `lib/core/ai/prompts/efficiency_review_prompts.dart`：效能诊断提示词工程
  - `lib/features/ai_copilot/widgets/ai_efficiency_report_view.dart`：Linear 风格图文周报渲染组件（指标大数字、象限水平进度条、洞察建议卡片）
  - `lib/features/ai_copilot/providers/ai_copilot_controller.dart`：增加周报指令触发逻辑
- **Out of scope**：
  - 外部日历导入与同步联动；
  - 周报 PDF 导出（留待后续版本）。

---

## Depends on
[TICKET-004](TICKET-004.md)

---

## Steps
1. **构建近 7 天统计提取服务 (`EfficiencyStatsService`)**：
   - 查询过去 7 天内创建、处于完成态（`completedAt != null`）或放弃态的任务数量；
   - 统计四象限优先级分布（Q1: 重要且紧急，Q2: 重要不紧急，Q3: 不重要紧急，Q4: 不重要不紧急）；
   - 统计逾期未完成任务数。
2. **编写效能诊断 Prompt 模板**：
   - 将上述结构化统计数据格式化注入 System Prompt；
   - 引导模型按固定逻辑输出：
     1. 核心战绩总览（高光成果）；
     2. 四象限时间投入合理性分析（如是否在 Q2 长期规划投入不足，或被 Q3 琐事过多牵扯）；
     3. 下周行动优化建议 Top 3。
3. **设计 Linear 风格图文报告小部件 (`AiEfficiencyReportView`)**：
   - 头部 KPI 胶囊横排：完成率 %、完成总数、放弃总数；
   - 象限分布占比进度条：采用 `AppTokens.colorPriority*` 对应颜色组成的细条进度叠加图；
   - 洞察文本区：结构化 Markdown 富文本渲染，字体与排版严格遵循设计令牌。
4. **集成到 Copilot 会话状态机**：
   - 点击快捷 Prompt「分析我这周的任务完成情况」时，自动抓取统计并发送请求；
   - 支持流式输出，打字机式平滑展现诊断结论。
5. **设计令牌与无魔法值核查**：
   - 严格审查进度条高度、卡片边距、文字颜色，确保 100% 绑定 `AppTokens`。

---

## Acceptance
- [x] **AC-01 (统计数据提取准确无误)**：
  - **Given** 本地数据库在近 7 天内存在 5 个已完成任务和 2 个进行中任务；
  - **When** 调用 `EfficiencyStatsService.getPastWeekStats`；
  - **Then** 返回的统计实体数值与数据库记录完全吻合。
- [x] **AC-02 (快捷指令唤起与图文周报渲染)**：
  - **Given** 打开 AI 抽屉；
  - **When** 点击「分析我这周的任务完成情况」快捷胶囊；
  - **Then** AI 生成包含指标卡片、四象限分布进度与分析建议的完整效能报告。
- [x] **AC-03 (高信息密度与 Linear 视觉美感)**：
  - **Given** 处于暗色主题下查看生成的周报；
  - **When** 观察整体排版；
  - **Then** 指标清晰、微光边框柔和、象限色彩与应用全局风格一致，无杂乱色块。
- [x] **AC-04 (零魔法值合规)**：
  - **Given** 审查 `ai_efficiency_report_view.dart` 源码；
  - **When** 检查布局样式；
  - **Then** 零魔法值，全部引用 `AppTokens`。

---

## Test plan
- **单元测试**：
  - `test/core/ai/efficiency_stats_service_test.dart`：在内存 SQLite 数据库中插入不同时间段、不同象限的任务，验证近 7 天统计计算逻辑的准确性。
- **Widget 测试**：
  - `test/features/ai_copilot/ai_efficiency_report_view_test.dart`：给定一份 Mock 统计与分析文本，测试指标卡片和进度条正确渲染。

---

## Status
done
