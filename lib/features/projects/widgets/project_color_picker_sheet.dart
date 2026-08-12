// 底部颜色选择器（58-project-form-redesign.md §4 D3）。
//
// - 触发：项目表单「颜色」选项行整行点击。
// - 形态：showModalBottomSheet，顶部圆角 radiusDialog，标题复用 projectColor 文案。
// - 交互：kProjectColors 圆点网格，选中态 = 边框 + 对勾（沿用旧表单样式）；
//   点击圆点立即返回所选颜色（Navigator.pop(context, color)）。

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Preset color palette for projects（AppTokens.presetColors 的项目用别名）。
///
/// 定义在本文件（而非表单文件），避免表单 ↔ 选择器循环依赖；
/// project_form_dialog.dart 通过 `export ... show kProjectColors` 保持兼容。
const List<Color> kProjectColors = AppTokens.presetColors;

/// 打开底部颜色选择器。
///
/// 返回所选 [Color]；关闭（顶部 X / 遮罩点击 / 返回键）返回 null。
Future<Color?> showProjectColorPicker({
  required BuildContext context,
  required Color current,
}) {
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => _ProjectColorPickerSheet(current: current),
  );
}

class _ProjectColorPickerSheet extends StatelessWidget {
  const _ProjectColorPickerSheet({required this.current});

  /// 当前选中的颜色（选中态高亮）。
  final Color current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          AppTokens.spaceXs,
          AppTokens.spaceMd,
          AppTokens.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶栏：关闭 + 标题（对齐 TaskCreateSheet 内嵌选择器顶栏样式）。
            Row(
              children: [
                IconButton(
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.projectColor,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            // 色点网格：48dp 触控目标包 40dp 色点，整点可点。
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXxs,
              ),
              child: Wrap(
                spacing: AppTokens.spaceLg,
                runSpacing: AppTokens.spaceLg,
                children: [
                  for (final color in kProjectColors)
                    _ColorDot(
                      color: color,
                      selected: color.toARGB32() == current.toARGB32(),
                      onTap: () => Navigator.of(context).pop(color),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个色点：选中态 = onSurface 3dp 边框 + 白色对勾（沿用旧表单 94-122 行样式）。
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppTokens.touchTarget,
          height: AppTokens.touchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: AppTokens.motionFast,
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(
                        color: theme.colorScheme.onSurface,
                        width: _selectedBorderWidth,
                      )
                    : null,
              ),
              child: selected
                  ? const Icon(
                      Icons.check,
                      color: AppTokens.colorOnCheck,
                      size: _checkSize,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 色点直径。
const double _dotSize = 40;

/// 选中态边框宽度。
const double _selectedBorderWidth = 3;

/// 选中态对勾尺寸。
const double _checkSize = 20;
