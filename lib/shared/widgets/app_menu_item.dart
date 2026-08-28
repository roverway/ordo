import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 统一弹出菜单项（50-ui-ux §2.6 菜单规格，共享组件）。
///
/// 各处 [PopupMenuButton] 的菜单项一律使用本组件（带勾选态的
/// [CheckedPopupMenuItem] 等特殊交互除外），统一紧凑行高、内边距与
/// 「图标 + 文字」排版，避免图标 16/18/20、间距 8/16 等散落魔法值漂移。
///
/// - 行高 [AppTokens.menuItemHeight]（40，M3 默认 48 的紧凑化）、水平内边距
///   [AppTokens.spaceSm]（容器上下内边距由全局 popupMenuTheme.menuPadding 统一）；
/// - 图标 [AppTokens.menuItemIconSize]（18）+ [AppTokens.spaceXs] 间距；
/// - [destructive] 删除类条目用 `colorScheme.error`（与既有删除项配色一致）。
class AppMenuItem<T> extends PopupMenuItem<T> {
  AppMenuItem({
    super.key,
    super.value,
    required String label,
    IconData? icon,
    bool destructive = false,
  }) : super(
         height: AppTokens.menuItemHeight,
         padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
         child: _AppMenuItemContent(
           label: label,
           icon: icon,
           destructive: destructive,
         ),
       );
}

class _AppMenuItemContent extends StatelessWidget {
  const _AppMenuItemContent({
    required this.label,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final contentColor = destructive ? colorScheme.error : null;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppTokens.menuItemIconSize, color: contentColor),
          const SizedBox(width: AppTokens.spaceXs),
        ],
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: destructive ? TextStyle(color: contentColor) : null,
          ),
        ),
      ],
    );
  }
}
