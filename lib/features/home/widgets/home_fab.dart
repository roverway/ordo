import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../ai_copilot/views/ai_copilot_sheet.dart';

/// 主界面单体多态 FAB 组件（Unified Polymorphic FAB）。
///
/// 遵循 Apple 与 Linear 极简设计美学，取缔相互割裂的双 FAB 排布，
/// 将「原生快速新建」与「AI 智能助理」凝聚为一体化悬浮操作胶囊：
/// 1. 单体容器：统一微光外边框、统一背景反光表面与浮动阴影；
/// 2. 多态触控：左侧 AI 星芒触发助理，右侧原生加号直达快速新建，长按全域唤醒智能；
/// 3. 触感反馈：集成 iOS 风格的轻量触感震动 (HapticFeedback)。
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

  void _triggerAi(BuildContext context) {
    HapticFeedback.lightImpact();
    if (onAiAssistant != null) {
      onAiAssistant!();
    } else {
      AiCopilotSheet.show(context);
    }
  }

  void _triggerNative() {
    HapticFeedback.mediumImpact();
    onNativeAdd();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final capsuleBg =
        isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCardLight;
    final borderColor =
        isDark ? AppTokens.borderSubtleDark : AppTokens.borderSubtleLight;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: AppTokens.alphaTintFaint)
        : Colors.black.withValues(alpha: AppTokens.alphaTintFaint);

    return Material(
      color: Colors.transparent,
      elevation: AppTokens.elevationFab,
      shadowColor: Colors.black.withValues(alpha: AppTokens.alphaCheckboxFrostedSurfaceDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: capsuleBg,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          onLongPress: () => _triggerAi(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI 智能助理多态入口（带微光渐变与专属 Key）
              Semantics(
                button: true,
                label: l10n.aiCopilotTooltip,
                child: Material(
                  key: aiFabKey,
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                    onTap: () => _triggerAi(context),
                    child: Tooltip(
                      message: l10n.aiCopilotTooltip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceSm + 2,
                          vertical: AppTokens.spaceXs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  AppTokens.colorInbox,
                                  Colors.cyanAccent,
                                ],
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.auto_awesome,
                                size: AppTokens.expandArrowSize,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 胶囊中段超细微光分割线
              Container(
                width: 1.0,
                height: 20.0,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: dividerColor,
              ),

              // 原生快速新建入口（符合 FloatingActionButton 规范，一体化嵌入胶囊右侧）
              FloatingActionButton.small(
                key: nativeFabKey,
                heroTag: 'home_native_add_fab_hero',
                tooltip: l10n.newTask,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                onPressed: _triggerNative,
                child: const Icon(
                  Icons.add,
                  size: AppTokens.expandArrowSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
