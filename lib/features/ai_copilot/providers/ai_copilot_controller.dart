import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/ai/models/efficiency_stats.dart';
import 'package:ordo/core/ai/prompts/efficiency_review_prompts.dart';
import 'package:ordo/core/ai/services/ai_config_service.dart';
import 'package:ordo/core/ai/services/ai_task_parser.dart';
import 'package:ordo/core/ai/services/ai_task_persistence_service.dart';
import 'package:ordo/core/ai/services/efficiency_stats_service.dart';
import 'package:ordo/features/ai_copilot/models/ai_chat_message.dart';
import 'package:ordo/features/projects/project_providers.dart';

/// Provider for [AiTaskParser].
final aiTaskParserProvider = Provider<AiTaskParser>((ref) {
  final client = ref.watch(aiClientProvider);
  final configService = ref.watch(aiConfigServiceProvider);
  return AiTaskParser(aiClient: client, configService: configService);
});

/// Provider for [AiTaskPersistenceService].
final aiTaskPersistenceServiceProvider = Provider<AiTaskPersistenceService>((
  ref,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return AiTaskPersistenceService(repository: repo);
});

/// Provider for [EfficiencyStatsService].
final efficiencyStatsServiceProvider = Provider<EfficiencyStatsService>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return EfficiencyStatsService(repository: repo);
});

/// State for the AI Copilot conversation.
@immutable
class AiCopilotState {
  const AiCopilotState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// In-memory chat history including user inputs, task proposal cards, and efficiency reports.
  final List<AiChatMessage> messages;

  /// Whether AI is thinking or LLM request is currently running.
  final bool isLoading;

  /// Transient error message if any error occurred.
  final String? errorMessage;

  AiCopilotState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AiCopilotState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiCopilotState &&
          runtimeType == other.runtimeType &&
          listEquals(messages, other.messages) &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(messages), isLoading, errorMessage);
}

/// Controller managing AI Copilot messages, task parsing, task persistence, and efficiency reports.
class AiCopilotController extends Notifier<AiCopilotState> {
  int _idCounter = 0;

  AiTaskParser get _parser => ref.read(aiTaskParserProvider);
  AiTaskPersistenceService get _persistenceService =>
      ref.read(aiTaskPersistenceServiceProvider);
  EfficiencyStatsService get _statsService =>
      ref.read(efficiencyStatsServiceProvider);

  @override
  AiCopilotState build() => const AiCopilotState();

  String _generateId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  /// Sends a natural language message from user.
  /// If the prompt is about weekly review or efficiency, routes to [generateEfficiencyReport].
  Future<void> sendMessage(String text, {String locale = 'zh'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final lower = trimmed.toLowerCase();
    if (lower.contains('周报') ||
        lower.contains('效能') ||
        lower.contains('weekly report') ||
        lower.contains('efficiency')) {
      final userMsgId = _generateId();
      final userMessage = AiChatMessage.user(
        id: userMsgId,
        text: trimmed,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, userMessage]);
      await generateEfficiencyReport(locale: locale);
      return;
    }

    final userMsgId = _generateId();
    final userMessage = AiChatMessage.user(
      id: userMsgId,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    // Append user message and enter loading state
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      errorMessage: null,
    );

    try {
      final proposal = await _parser.parse(trimmed);
      final proposalMsgId = _generateId();
      final proposalMessage = AiChatMessage.taskProposal(
        id: proposalMsgId,
        proposal: proposal,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, proposalMessage],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Generates weekly efficiency statistics and diagnostic report.
  Future<void> generateEfficiencyReport({
    String locale = 'zh',
    DateTime? now,
  }) async {
    final stats = await _statsService.getPastWeekStats(now: now);
    final reportMsgId = _generateId();
    final reportMessage = AiChatMessage.efficiencyReport(
      id: reportMsgId,
      stats: stats,
      isLoading: true,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, reportMessage],
      errorMessage: null,
    );

    try {
      final config = await ref.read(aiConfigServiceProvider).loadConfig();
      String diagnosisMarkdown;
      if (config.apiKey == null || config.apiKey!.trim().isEmpty) {
        diagnosisMarkdown = _generateOfflineDiagnosis(stats, locale: locale);
      } else {
        final systemPrompt = EfficiencyReviewPrompts.buildSystemPrompt(
          locale: locale,
        );
        final userPrompt = EfficiencyReviewPrompts.buildUserPrompt(
          stats,
          locale: locale,
        );
        final messages = [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ];
        diagnosisMarkdown = await ref
            .read(aiClientProvider)
            .chat(config, messages);
      }

      final updatedMessages = state.messages.map((m) {
        if (m.id == reportMsgId) {
          return m.copyWith(content: diagnosisMarkdown, isLoading: false);
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      final fallbackMarkdown = _generateOfflineDiagnosis(stats, locale: locale);
      final updatedMessages = state.messages.map((m) {
        if (m.id == reportMsgId) {
          return m.copyWith(content: fallbackMarkdown, isLoading: false);
        }
        return m;
      }).toList();

      state = state.copyWith(messages: updatedMessages, errorMessage: null);
    }
  }

  String _generateOfflineDiagnosis(
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

  /// Toggles selection of a specific substep on a task proposal card.
  void toggleSubstep(String messageId, int substepIndex) {
    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id != messageId) return msg;
        if (msg.isPersisted || msg.isDiscarded || msg.isPersisting) return msg;

        final newSet = Set<int>.from(msg.selectedSubstepIndices);
        if (newSet.contains(substepIndex)) {
          newSet.remove(substepIndex);
        } else {
          newSet.add(substepIndex);
        }
        return msg.copyWith(selectedSubstepIndices: newSet);
      }).toList(),
    );
  }

  /// Updates selection set of substeps for a proposal card.
  void updateSubstepIndices(String messageId, Set<int> indices) {
    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id != messageId) return msg;
        if (msg.isPersisted || msg.isDiscarded || msg.isPersisting) return msg;
        return msg.copyWith(selectedSubstepIndices: Set<int>.from(indices));
      }).toList(),
    );
  }

  /// Confirms and persists the task proposal card into the database.
  ///
  /// Defends against double submission (idempotent guard).
  /// Only persists the substeps currently selected by user.
  Future<AiTaskPersistenceResult?> confirmTaskProposal(
    String messageId, {
    String? projectId,
  }) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return null;

    final targetMsg = state.messages[index];
    if (targetMsg.proposal == null) return null;
    if (targetMsg.isPersisted ||
        targetMsg.isPersisting ||
        targetMsg.isDiscarded) {
      return null;
    }

    // Mark as persisting
    final updatedList = List<AiChatMessage>.from(state.messages);
    updatedList[index] = targetMsg.copyWith(isPersisting: true);
    state = state.copyWith(messages: updatedList, errorMessage: null);

    try {
      final original = targetMsg.proposal!;
      final filteredSubsteps = <AiSubstep>[];
      for (int i = 0; i < original.substeps.length; i++) {
        if (targetMsg.selectedSubstepIndices.contains(i)) {
          filteredSubsteps.add(original.substeps[i]);
        }
      }

      final filteredProposal = original.copyWith(substeps: filteredSubsteps);
      final result = await _persistenceService.persist(
        filteredProposal,
        projectId: projectId,
      );

      final successList = List<AiChatMessage>.from(state.messages);
      final targetIdx = successList.indexWhere((m) => m.id == messageId);
      if (targetIdx != -1) {
        successList[targetIdx] = successList[targetIdx].copyWith(
          isPersisted: true,
          isPersisting: false,
        );
        state = state.copyWith(messages: successList);
      }

      return result;
    } catch (e) {
      final revertList = List<AiChatMessage>.from(state.messages);
      final targetIdx = revertList.indexWhere((m) => m.id == messageId);
      if (targetIdx != -1) {
        revertList[targetIdx] = revertList[targetIdx].copyWith(
          isPersisting: false,
        );
        state = state.copyWith(
          messages: revertList,
          errorMessage: e.toString(),
        );
      }
      return null;
    }
  }

  /// Marks a task proposal as discarded.
  void discardProposal(String messageId) {
    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id != messageId) return msg;
        if (msg.isPersisted || msg.isPersisting) return msg;
        return msg.copyWith(isDiscarded: true);
      }).toList(),
    );
  }

  /// Clears the entire chat history.
  void clearChat() {
    state = const AiCopilotState();
  }
}

/// Provider for [AiCopilotController].
final aiCopilotControllerProvider =
    NotifierProvider<AiCopilotController, AiCopilotState>(
      AiCopilotController.new,
    );
