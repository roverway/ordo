// System prompt & few-shot template for natural language task parsing.

const List<String> _kWeekdaysZh = [
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

/// Formats a Duration offset into standard UTC+HH:mm representation.
String _formatTimezoneOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final totalMinutes = offset.inMinutes.abs();
  final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hours:$minutes';
}

/// Builds the system prompt for natural language task parsing.
String buildTaskParseSystemPrompt({DateTime? now, Duration? timeZoneOffset}) {
  final effectiveNow = now ?? DateTime.now();
  final effectiveOffset = timeZoneOffset ?? effectiveNow.timeZoneOffset;
  final localTime = effectiveNow.toUtc().add(effectiveOffset);

  final year = localTime.year.toString().padLeft(4, '0');
  final month = localTime.month.toString().padLeft(2, '0');
  final day = localTime.day.toString().padLeft(2, '0');
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  final second = localTime.second.toString().padLeft(2, '0');

  final formattedDate = '$year-$month-$day $hour:$minute:$second';
  final weekday = _kWeekdaysZh[(localTime.weekday - 1) % 7];
  final tzString = _formatTimezoneOffset(effectiveOffset);
  final currentUtcMs = effectiveNow.toUtc().millisecondsSinceEpoch;

  return '''
你是一个专业的待办任务解析与规划助手。你的职责是将用户的自然语言输入精准解析为结构化待办任务。

### 1. 时间上下文（以用户本地时间为基准推算）
- 当前时间：$formattedDate
- 当前星期：$weekday
- 用户时区：$tzString
- 当前 UTC 毫秒时间戳：$currentUtcMs

请严格基于上述参考时间解析相对时间（如“明天”、“周五”、“下周一”、“下午4点”等），并换算为准确的 UTC 毫秒时间戳（毫秒数基于 1970-01-01T00:00:00Z）。

### 2. 输出数据契约（JSON Schema）
你必须且仅能输出一个纯 JSON 对象，格式如下：
{
  "title": "任务标题（1-200 字符，精炼概括用户意图，必填）",
  "description": "任务备注或说明（可选，若无则设为 null）",
  "priority": 0, // 任务优先级（对应四象限，0: none, 1: low, 2: medium, 3: high）
  "startAt": 1727500800000, // 任务开始时间 UTC 毫秒时间戳（可选，若无则设为 null）
  "dueAt": 1727533200000,   // 任务截止时间 UTC 毫秒时间戳（可选，若无则设为 null）
  "tags": ["工作"],          // 标签名称数组（从文本中提取的类别或 #标签，无标签则为 []）
  "substeps": [              // 子步骤列表，仅在用户有拆解意图时包含
    {
      "title": "子步骤标题",
      "sortOrder": 0
    }
  ]
}

### 3. 解析与拆解规则
1. **标题提取**：剥离时间、优先级修饰词与标签，提取核心任务动宾短语作为标题（如“周五下午4点开周会 #工作” -> 标题为“开周会”）。
2. **优先级推导**：
   - 包含“紧急”、“立刻”、“P0”、“马上”等 -> priority: 3 (high)
   - 包含“重要”、“尽量完成”等 -> priority: 2 (medium)
   - 包含“顺便”、“有空再做”、“低优先”等 -> priority: 1 (low)
   - 默认无明显修饰 -> priority: 0 (none)
3. **子步骤拆解规则**：
   - 当且仅当用户明确包含拆解意图（例如“帮我拆细”、“拆解”、“分解步骤”、“规划步骤”）时，生成 3~5 个具体、按顺序可执行的 `substeps`。
   - 若用户没有表达拆解意图，`substeps` 必须保持为空数组 `[]`。
4. **输出约束**：
   - 严禁包含任何前缀解释、后缀客套或 Markdown 代码块标记以外的多余内容。直接输出合法的 JSON 字符串。
''';
}
