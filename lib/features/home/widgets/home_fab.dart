import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../ai_copilot/views/ai_copilot_sheet.dart';

/// 主界面双 FAB 组合组件。
///
/// 包含原生快捷新建主 FAB 与 AI 智能助手次级 FAB。
/// 两者视觉层级与图标明确分离，点击事件互不干扰，严格遵循 100% 零魔法值设计规范。
class HomeDoubleFab extends StatelessWidget {
  const HomeDoubleFab({
    super.key,
    required this.onNativeAdd,
    this.onAiAssistant,
  });

  /// 原生新建任务回调
  final VoidCallback onNativeAdd;

  /// AI 助手点击回调（若为空则默认调用 [AiCopilotSheet.show]）
  final VoidCallback? onAiAssistant;

  /// 原生 FAB Key
  static const Key nativeFabKey = Key('home_native_add_fab');

  /// AI 助手 FAB Key
  static const Key aiFabKey = Key('home_ai_fab');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final aiBorderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AI 智能助手次级 FAB（品牌紫色 / 矩形圆角 radiusButton / 微光质感）
        Semantics(
          button: true,
          label: l10n.aiCopilotTooltip,
          child: Material(
            key: aiFabKey,
            color: AppTokens.colorInbox,
            elevation: AppTokens.elevationFab,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              side: BorderSide(color: aiBorderColor),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusButton),
              onTap: onAiAssistant ?? () => AiCopilotSheet.show(context),
              child: Tooltip(
                message: l10n.aiCopilotTooltip,
                child: const SizedBox(
                  width: AppTokens.touchTarget,
                  height: AppTokens.touchTarget,
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: AppTokens.expandArrowSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppTokens.spaceSm),

        // 原生快速新建主 FAB（主强调色 / 药丸圆角 radiusPill）
        FloatingActionButton(
          key: nativeFabKey,
          heroTag: 'home_native_add_fab_hero',
          tooltip: l10n.newTask,
          elevation: AppTokens.elevationFab,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          onPressed: onNativeAdd,
          child: const Icon(Icons.add, size: AppTokens.expandArrowSize),
        ),
      ],
    );
  }
}
