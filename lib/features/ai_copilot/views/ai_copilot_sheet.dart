import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/app_tokens.dart';
import 'package:ordo/core/utils/app_breakpoints.dart';
import 'package:ordo/features/ai_copilot/models/ai_chat_message.dart';
import 'package:ordo/features/ai_copilot/providers/ai_copilot_controller.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_chat_input_box.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_efficiency_report_view.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_prompt_capsule.dart';
import 'package:ordo/features/ai_copilot/widgets/ai_task_proposal_card.dart';

/// Modal bottom sheet (narrow screens) or right side sheet (wide screens)
/// hosting the AI Copilot natural language dialogue interface.
class AiCopilotSheet extends ConsumerStatefulWidget {
  const AiCopilotSheet({super.key, this.isSideSheet = false});

  /// Key identifying the sheet root widget in widget tests.
  static const Key sheetKey = ValueKey('ai_copilot_sheet');

  /// Key identifying the top drag grabber.
  static const Key grabberKey = ValueKey('ai_copilot_sheet_grabber');

  /// Key identifying the close button.
  static const Key closeButtonKey = ValueKey('ai_copilot_sheet_close_button');

  /// Key identifying the clear conversation button.
  static const Key clearButtonKey = ValueKey('ai_copilot_sheet_clear_button');

  /// Whether this sheet is rendered as a right side panel (for wide screens / tablets).
  final bool isSideSheet;

  /// Shows the AI Copilot sheet as a modal bottom sheet.
  static Future<T?> show<T>(BuildContext context) {
    final isWide = AppBreakpoints.isWide(context);

    if (isWide) {
      return showGeneralDialog<T>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'AI Copilot',
        barrierColor: Colors.black54,
        transitionDuration: AppTokens.motionNormal,
        pageBuilder: (context, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: AppTokens.sideSheetWidth,
              height: double.infinity,
              child: const Material(
                color: Colors.transparent,
                child: AiCopilotSheet(isSideSheet: true),
              ),
            ),
          );
        },
      );
    }

    final mediaQuery = MediaQuery.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SizedBox(
          height: mediaQuery.size.height * 0.85,
          child: const AiCopilotSheet(isSideSheet: false),
        ),
      ),
    );
  }

  @override
  ConsumerState<AiCopilotSheet> createState() => _AiCopilotSheetState();
}

class _AiCopilotSheetState extends ConsumerState<AiCopilotSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppTokens.motionNormal,
          curve: AppTokens.motionSpring,
        );
      }
    });
  }

  void _handlePromptCapsuleTap(String promptText) {
    final l10n = AppLocalizations.of(context);
    if (promptText == l10n.aiCapsuleWeeklyReport) {
      _handleSendMessage(promptText);
    } else {
      _inputController.text = promptText;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: promptText.length),
      );
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final locale = Localizations.localeOf(context).languageCode;
    _scrollToBottom();
    await ref
        .read(aiCopilotControllerProvider.notifier)
        .sendMessage(text, locale: locale);
    _scrollToBottom();
  }

  void _clearChat() {
    ref.read(aiCopilotControllerProvider.notifier).clearChat();
  }

  @override
  Widget build(BuildContext context) {
    final copilotState = ref.watch(aiCopilotControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppTokens.surfacePageDark
        : AppTokens.surfacePageLight;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    final content = Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: widget.isSideSheet,
        bottom: false,
        child: Column(
          children: [
            // Narrow screen grabber
            if (!widget.isSideSheet) _buildGrabber(context),

            // Header bar
            _buildHeader(
              context,
              isDark,
              borderColor,
              hasMessages: copilotState.messages.isNotEmpty,
            ),

            // Message stream or welcome empty state
            Expanded(
              child: copilotState.messages.isEmpty && !copilotState.isLoading
                  ? _buildWelcomeState(context, isDark)
                  : _buildMessageList(context, isDark, copilotState),
            ),

            // Bottom action bar
            _buildBottomBar(
              context,
              isDark,
              borderColor,
              isLoading: copilotState.isLoading,
            ),
          ],
        ),
      ),
    );

    if (widget.isSideSheet) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(left: BorderSide(color: borderColor)),
        ),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
        border: Border(
          top: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
        child: content,
      ),
    );
  }

  Widget _buildGrabber(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: AiCopilotSheet.grabberKey,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(
        top: AppTokens.spaceMd,
        bottom: AppTokens.spaceSm,
      ),
      child: Container(
        width: AppTokens.sheetGrabberWidth,
        height: AppTokens.sheetGrabberHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(
            alpha: AppTokens.alphaTintStrong,
          ),
          borderRadius: BorderRadius.circular(AppTokens.sheetGrabberRadius),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    Color borderColor, {
    required bool hasMessages,
  }) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome,
            size: AppTokens.menuItemIconSize,
            color: AppTokens.colorInbox,
          ),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              l10n.aiCopilot,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (hasMessages)
            IconButton(
              key: AiCopilotSheet.clearButtonKey,
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: AppTokens.menuItemIconSize,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: l10n.aiClearChat,
              onPressed: _clearChat,
            ),
          IconButton(
            key: AiCopilotSheet.closeButtonKey,
            icon: Icon(
              Icons.close,
              size: AppTokens.menuItemIconSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: l10n.aiClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.surfaceSubtleLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppTokens.borderSubtleDark
                      : AppTokens.borderSubtleLight,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: AppTokens.emptyBackdropIconSize,
                color: AppTokens.colorInbox,
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              l10n.aiCopilot,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              l10n.aiWelcomeTip,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    bool isDark,
    AiCopilotState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final messages = state.messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceMd,
      ),
      itemCount: messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && state.isLoading) {
          // Thinking indicator
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTokens.colorInbox,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Text(
                  l10n.aiThinking,
                  style: TextStyle(
                    fontSize: AppTokens.textFootnoteSize,
                    color: isDark
                        ? AppTokens.textMutedDark
                        : AppTokens.textMutedLight,
                  ),
                ),
              ],
            ),
          );
        }

        final msg = messages[index];

        if (msg.type == AiChatMessageType.efficiencyReport &&
            msg.efficiencyStats != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
            child: AiEfficiencyReportView(
              stats: msg.efficiencyStats!,
              analysisMarkdown: msg.content.isNotEmpty ? msg.content : null,
              isLoading: msg.isLoading,
            ),
          );
        }

        if (msg.type == AiChatMessageType.taskProposal &&
            msg.proposal != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
            child: AiTaskProposalCard(
              proposal: msg.proposal!,
              selectedSubstepIndices: msg.selectedSubstepIndices,
              isPersisted: msg.isPersisted,
              isPersisting: msg.isPersisting,
              isDiscarded: msg.isDiscarded,
              onSubstepsChanged: (newIndices) {
                ref
                    .read(aiCopilotControllerProvider.notifier)
                    .updateSubstepIndices(msg.id, newIndices);
              },
              onConfirm: () async {
                final result = await ref
                    .read(aiCopilotControllerProvider.notifier)
                    .confirmTaskProposal(msg.id);
                if (result != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.aiTaskAddedSuccess),
                      duration: AppTokens.motionSlow,
                    ),
                  );
                }
              },
              onDiscard: () {
                ref
                    .read(aiCopilotControllerProvider.notifier)
                    .discardProposal(msg.id);
              },
            ),
          );
        }

        final isUser = msg.type == AiChatMessageType.user;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceSm,
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primary
                  : (isDark
                        ? AppTokens.surfaceCardDark
                        : AppTokens.surfaceCardLight),
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              border: isUser
                  ? null
                  : Border.all(
                      color: isDark
                          ? AppTokens.borderSubtleDark
                          : AppTokens.borderSubtleLight,
                    ),
            ),
            child: Text(
              msg.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    bool isDark,
    Color borderColor, {
    required bool isLoading,
  }) {
    final l10n = AppLocalizations.of(context);

    final List<({String label, IconData icon})> capsules = [
      (label: l10n.aiCapsuleWeeklyReport, icon: Icons.summarize_outlined),
      (label: l10n.aiCapsulePlanToday, icon: Icons.today_outlined),
      (label: l10n.aiCapsuleBreakdownTask, icon: Icons.account_tree_outlined),
    ];

    return Container(
      padding: const EdgeInsets.only(
        top: AppTokens.spaceSm,
        bottom: AppTokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfacePageDark : AppTokens.surfacePageLight,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt capsules
          SizedBox(
            height: AppTokens.touchTarget,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceLg,
                vertical: AppTokens.spaceXs,
              ),
              itemCount: capsules.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTokens.spaceSm),
              itemBuilder: (context, index) {
                final item = capsules[index];
                return AiPromptCapsule(
                  label: item.label,
                  icon: item.icon,
                  onTap: () => _handlePromptCapsuleTap(item.label),
                );
              },
            ),
          ),

          const SizedBox(height: AppTokens.spaceXs),

          // Input box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceLg),
            child: AiChatInputBox(
              controller: _inputController,
              focusNode: _inputFocusNode,
              hintText: l10n.aiInputHint,
              enabled: !isLoading,
              onSend: _handleSendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
