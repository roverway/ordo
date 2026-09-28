import '../models/efficiency_stats.dart';

/// Prompt engineering templates for weekly efficiency review and diagnostic.
class EfficiencyReviewPrompts {
  const EfficiencyReviewPrompts._();

  /// System prompt instructing the model on its role, analytical framework and output structure.
  static String buildSystemPrompt({String locale = 'zh'}) {
    final isZh = locale.toLowerCase().startsWith('zh');
    if (isZh) {
      return '''你是一位专业的时间管理与个人效能专家，基于《高效能人士的七个习惯》及艾森豪威尔四象限法则，为用户提供客观、深度、具备启发性与行动力的周度效能诊断。

请严格根据用户提供的本周任务真实数据，按照以下三个章节结构进行诊断分析，使用清晰美观的 Markdown 格式输出：

### 1. 核心战绩总览
- 提炼本周执行力亮点与高光成果（如完成率、攻坚的大任务）。
- 客观指出存在的问题（如逾期、放弃数等）。

### 2. 四象限投入合理性分析
- 深度剖析时间与精力在四象限上的分布结构：
  - Q1 (重要且紧急 / 危机救火): 是否深陷突发危机与被动应对？
  - Q2 (重要不紧急 / 长期价值): 是否在预防、规划与核心成长上投入了足够精力？（高效能人士的核心基石）
  - Q3 (不重要紧急 / 琐事干扰): 是否被他人打扰或表面紧急实则无价值的琐事绑架？
  - Q4 (不重要不紧急 / 逃避内耗): 是否存在拖延逃避与无意义耗时？
- 点出当前四象限分配的失衡点与潜在隐患。

### 3. 下周行动优化建议 (Top 3)
- 给出 3 条直击痛点、可落地执行的具体优化建议（每条包含针对的问题与具体改进动作）。

风格要求：温和专业、直击本质、精炼有力，避免空洞寒暄。''';
    } else {
      return '''You are an expert in personal effectiveness and time management based on the Eisenhower Matrix.
Analyze the user's weekly task statistics objectively and provide an inspiring, actionable diagnosis.

Output format:
### 1. Weekly Highlights & Overview
- Highlight accomplishments and key completion metrics.
- Point out any issues like overdue or cancelled tasks.

### 2. Quadrant Distribution Analysis
- Deep-dive into time allocation across Q1 (Crisis), Q2 (Long-term Value), Q3 (Distractions), and Q4 (Waste).
- Identify imbalance and bottlenecks.

### 3. Actionable Recommendations for Next Week (Top 3)
- 3 clear, practical, and high-leverage action items to optimize weekly productivity.

Style: Concise, professional, and actionable.''';
    }
  }

  /// Builds the user prompt containing formatted statistics.
  static String buildUserPrompt(EfficiencyStats stats, {String locale = 'zh'}) {
    final isZh = locale.toLowerCase().startsWith('zh');
    final completionPct = (stats.completionRate * 100).toStringAsFixed(1);
    final q1Pct = (stats.q1Ratio * 100).toStringAsFixed(1);
    final q2Pct = (stats.q2Ratio * 100).toStringAsFixed(1);
    final q3Pct = (stats.q3Ratio * 100).toStringAsFixed(1);
    final q4Pct = (stats.q4Ratio * 100).toStringAsFixed(1);

    if (isZh) {
      return '''以下是我过去 7 天的个人任务执行与四象限统计数据，请为我生成周度效能诊断分析报告：

【核心指标】
- 统计周期：${stats.startDate.year}-${stats.startDate.month.toString().padLeft(2, '0')}-${stats.startDate.day.toString().padLeft(2, '0')} 至 ${stats.endDate.year}-${stats.endDate.month.toString().padLeft(2, '0')}-${stats.endDate.day.toString().padLeft(2, '0')}
- 任务总数：${stats.totalCount}
- 已完成任务数：${stats.completedCount} (完成率：$completionPct%)
- 已放弃任务数：${stats.cancelledCount}
- 进行中任务数：${stats.inProgressCount}
- 逾期未完成任务数：${stats.overdueCount}

【四象限分布】
- Q1 (重要且紧急): ${stats.q1Count} 个 ($q1Pct%)
- Q2 (重要不紧急): ${stats.q2Count} 个 ($q2Pct%)
- Q3 (不重要紧急): ${stats.q3Count} 个 ($q3Pct%)
- Q4 (不重要不紧急): ${stats.q4Count} 个 ($q4Pct%)''';
    } else {
      return '''Here are my personal task statistics for the past 7 days. Please provide a weekly efficiency diagnosis:

[Key Metrics]
- Period: ${stats.startDate.toIso8601String().substring(0, 10)} to ${stats.endDate.toIso8601String().substring(0, 10)}
- Total Tasks: ${stats.totalCount}
- Completed: ${stats.completedCount} (Completion Rate: $completionPct%)
- Cancelled / Discarded: ${stats.cancelledCount}
- In Progress: ${stats.inProgressCount}
- Overdue: ${stats.overdueCount}

[Quadrant Distribution]
- Q1 (Urgent & Important): ${stats.q1Count} ($q1Pct%)
- Q2 (Not Urgent & Important): ${stats.q2Count} ($q2Pct%)
- Q3 (Urgent & Unimportant): ${stats.q3Count} ($q3Pct%)
- Q4 (Not Urgent & Unimportant): ${stats.q4Count} ($q4Pct%)''';
    }
  }

  /// Generates rule-based offline efficiency diagnosis when offline or no API Key configured.
  static String buildOfflineDiagnosis(
    EfficiencyStats stats, {
    String locale = 'zh',
  }) {
    final isZh = locale.toLowerCase().startsWith('zh');
    if (isZh) {
      final pct = stats.completionPercentage;
      return '''### 核心战绩总览
本周共处理任务 ${stats.totalCount} 项，完成 ${stats.completedCount} 项，完成率达到 $pct%。${stats.overdueCount > 0 ? '目前仍有 ${stats.overdueCount} 项任务已逾期，需及时关注。' : '全部到期任务均按时推进，执行力良好。'}

### 四象限投入合理性分析
- **Q1 (重要且紧急)**: 占比 ${(stats.q1Ratio * 100).toStringAsFixed(0)}%，${stats.q1Ratio > 0.4 ? '应急任务较多，容易导致被动救火与身心疲惫。' : '救火压力可控，保持平稳。'}
- **Q2 (重要不紧急)**: 占比 ${(stats.q2Ratio * 100).toStringAsFixed(0)}%，${stats.q2Ratio < 0.3 ? '在长期规划与深度成长投入不足，建议提高权重。' : '长期高价值任务投入充足，效能基础稳健。'}
- **Q3 (不重要紧急)**: 占比 ${(stats.q3Ratio * 100).toStringAsFixed(0)}%，${stats.q3Ratio > 0.25 ? '受琐事干扰偏多，建议尝试批量处理或委派。' : '琐事控制合理。'}
- **Q4 (不重要不紧急)**: 占比 ${(stats.q4Ratio * 100).toStringAsFixed(0)}%，建议持续保持精简。

### 下周行动优化建议
1. **优先保障 Q2 黄金时间**：每天预留 1-2 小时专注文档、规划或深度学习。
2. **清理逾期与挂起任务**：针对当前 ${stats.overdueCount} 项逾期任务进行清理或重新规划排期。
3. **减少琐事打断**：合并碎片化沟通，设立固定免打扰专注时段。''';
    } else {
      return '''### Weekly Highlights & Overview
Handled ${stats.totalCount} tasks with ${stats.completedCount} completed (${stats.completionPercentage}% completion rate).

### Quadrant Distribution Analysis
- Q1 (Crisis): ${(stats.q1Ratio * 100).toStringAsFixed(0)}%
- Q2 (Long-term Value): ${(stats.q2Ratio * 100).toStringAsFixed(0)}%
- Q3 (Distractions): ${(stats.q3Ratio * 100).toStringAsFixed(0)}%
- Q4 (Waste): ${(stats.q4Ratio * 100).toStringAsFixed(0)}%

### Recommendations for Next Week
1. Protect dedicated deep work blocks for Q2 priority tasks.
2. Review and reschedule pending or overdue tasks.
3. Minimize non-essential context switching.''';
    }
  }
}
