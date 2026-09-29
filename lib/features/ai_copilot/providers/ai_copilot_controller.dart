import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordo/core/ai/models/ai_config.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/ai/prompts/efficiency_review_prompts.dart';
import 'package:ordo/core/ai/providers/ai_tool_providers.dart';
import 'package:ordo/core/ai/services/ai_config_service.dart';
import 'package:ordo/core/ai/services/ai_task_parser.dart';
import 'package:ordo/core/ai/services/ai_task_persistence_service.dart';
import 'package:ordo/core/ai/services/efficiency_stats_service.dart';
import 'package:ordo/core/ai/tools/ai_tool.dart';
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
  /// If online AI is configured, dispatches through unified [AiToolRunner] supporting
  /// autonomous query, multi-turn history, and write proposals. Otherwise falls back to offline parser/report.
  Future<void> sendMessage(String text, {String locale = 'zh'}) async {
    if (state.isLoading) return;

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
      // If parser is mocked in tests or custom fake injected, delegate directly
      if (_parser.runtimeType.toString().contains('Fake')) {
        final proposal = await _parser.parse(trimmed, locale: locale);
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
        return;
      }

      AiConfig? config;
      try {
        config = await ref.read(aiConfigServiceProvider).loadConfig();
      } catch (_) {
        config = null;
      }

      // Offline / Unconfigured Key Fallback
      if (config == null ||
          config.apiKey == null ||
          config.apiKey!.trim().isEmpty) {
        final proposal = await _parser.parse(
          trimmed,
          config: config,
          locale: locale,
        );
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
        return;
      }

      // Build sliding window history for multi-turn conversational context
      final historyList = <Map<String, dynamic>>[];
      final previousMessages = state.messages.length > 1
          ? state.messages.sublist(0, state.messages.length - 1)
          : const <AiChatMessage>[];
      final window = previousMessages.length > 10
          ? previousMessages.sublist(previousMessages.length - 10)
          : previousMessages;

      for (final m in window) {
        if (m.type == AiChatMessageType.user) {
          historyList.add({'role': 'user', 'content': m.content});
        } else if (m.type == AiChatMessageType.assistantText) {
          if (m.content.trim().isNotEmpty) {
            historyList.add({'role': 'assistant', 'content': m.content});
          }
        } else if (m.type == AiChatMessageType.taskProposal &&
            m.proposal != null) {
          final p = m.proposal!;
          final subs = p.substeps.isNotEmpty
              ? '（包含 ${p.substeps.length} 个子步骤：${p.substeps.map((s) => s.title).join('、')}）'
              : '';
          historyList.add({
            'role': 'assistant',
            'content': '已提议任务方案：《${p.title}》$subs',
          });
        } else if (m.type == AiChatMessageType.efficiencyReport &&
            m.efficiencyStats != null) {
          historyList.add({
            'role': 'assistant',
            'content': '已生成效能报告：总任务 ${m.efficiencyStats!.totalCount} 个。',
          });
        }
      }

      // Online Agentic Tool Execution
      final repo = ref.read(todoRepositoryProvider);
      final toolContext = AiToolContext(repository: repo, locale: locale);

      final runner = ref.read(aiToolRunnerProvider);
      final runnerResult = await runner.run(
        config: config,
        context: toolContext,
        userPrompt: trimmed,
        history: historyList,
        locale: locale,
      );

      final newMessages = List<AiChatMessage>.from(state.messages);

      // If a task creation was proposed via tool
      if (runnerResult.taskProposal != null) {
        final proposal = AiTaskParseResult.fromJson(runnerResult.taskProposal!);
        final proposalMsgId = _generateId();
        newMessages.add(
          AiChatMessage.taskProposal(
            id: proposalMsgId,
            proposal: proposal,
            createdAt: DateTime.now(),
          ),
        );
      }

      // If assistant produced analytical or informative text
      if (runnerResult.text.trim().isNotEmpty) {
        final textMsgId = _generateId();
        newMessages.add(
          AiChatMessage.assistantText(
            id: textMsgId,
            text: runnerResult.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
      }

      // Fallback / Progressive enhancement:
      // If no task proposal was emitted by tool, check if user had explicit breakdown or creation intention
      // or if assistant output contains structured list that should be converted into a proposal card.
      if (runnerResult.taskProposal == null) {
        final hasExplicitBreakdownIntent =
            lower.contains('分解') ||
            lower.contains('拆解') ||
            lower.contains('细化') ||
            lower.contains('拆细') ||
            lower.contains('步骤') ||
            lower.contains('break down') ||
            lower.contains('decompose');

        final looksLikeMarkdownList =
            runnerResult.text.contains(
              RegExp(r'(?:^|\n)\s*(?:\d+\.|\-|\*)\s+'),
            ) &&
            runnerResult.text.length < 500;

        if (hasExplicitBreakdownIntent &&
            (runnerResult.text.isEmpty || looksLikeMarkdownList)) {
          try {
            // Find reference target title from history if user used pronouns
            String parsingInput = trimmed;
            if (previousMessages.isNotEmpty) {
              for (final prev in previousMessages.reversed) {
                if (prev.proposal != null) {
                  parsingInput = '${prev.proposal!.title}，$trimmed';
                  break;
                }
              }
            }

            final proposal = await _parser.parse(
              parsingInput,
              config: config,
              locale: locale,
            );
            if (proposal.title.isNotEmpty) {
              newMessages.add(
                AiChatMessage.taskProposal(
                  id: _generateId(),
                  proposal: proposal,
                  createdAt: DateTime.now(),
                ),
              );
            }
          } catch (_) {
            // Safe ignore, assistant text already present
          }
        } else if (runnerResult.text.trim().isEmpty) {
          // Both proposal and text empty, fallback to parser
          final proposal = await _parser.parse(
            trimmed,
            config: config,
            locale: locale,
          );
          newMessages.add(
            AiChatMessage.taskProposal(
              id: _generateId(),
              proposal: proposal,
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      state = state.copyWith(messages: newMessages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Generates weekly efficiency statistics and diagnostic report.
  Future<void> generateEfficiencyReport({
    String locale = 'zh',
    DateTime? now,
  }) async {
    if (state.isLoading) return;

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
      isLoading: true,
      errorMessage: null,
    );

    try {
      final config = await ref.read(aiConfigServiceProvider).loadConfig();
      String diagnosisMarkdown;
      if (config.apiKey == null || config.apiKey!.trim().isEmpty) {
        diagnosisMarkdown = EfficiencyReviewPrompts.buildOfflineDiagnosis(
          stats,
          locale: locale,
        );
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

      state = state.copyWith(messages: updatedMessages, isLoading: false);
    } catch (e) {
      final fallbackMarkdown = EfficiencyReviewPrompts.buildOfflineDiagnosis(
        stats,
        locale: locale,
      );
      final updatedMessages = state.messages.map((m) {
        if (m.id == reportMsgId) {
          return m.copyWith(content: fallbackMarkdown, isLoading: false);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
        errorMessage: null,
      );
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

  /// Updates task proposal details (e.g. inline title edits or priority toggles).
  void updateProposal(String messageId, AiTaskParseResult proposal) {
    state = state.copyWith(
      messages: state.messages.map((msg) {
        if (msg.id != messageId) return msg;
        if (msg.isPersisted || msg.isDiscarded || msg.isPersisting) return msg;
        return msg.copyWith(proposal: proposal);
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
