import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 窄屏紧凑底栏（57-task-page-polish.md §4.1，D5）。
///
/// 自绘轻量实现（非标准 NavigationBar）：
/// - **紧凑**：高 [AppTokens.bottomBarHeight]（56dp），明显矮于标准
///   NavigationBar（80dp）；图标 + 极小标签，无 indicator 药丸。
/// - **无选中天然支持**：`selectedIndex` 传 `-1` 即视觉全未选中
///   （无 NavigationBar 的合法索引断言限制）。
/// - **可扩展**：目的地列表渲染——将来新增功能按钮，
///   向 [destinations] 加一项即可（AppShell 同步扩展 `_barPaths`）。
///
/// 颜色/尺寸/间距一律走 [AppTokens]/colorScheme，无魔法值。
class CompactBottomBar extends StatelessWidget {
  const CompactBottomBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// 底栏目的地（label + 图标对）。`-1` 表示无选中（视觉全未选中）。
  final List<({String label, IconData icon, IconData selectedIcon})>
  destinations;

  final int selectedIndex;

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: AppTokens.bottomBarHeight,
        child: ColoredBox(
          color: colorScheme.surface,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _CompactBarItem(
                    label: destinations[i].label,
                    icon: i == selectedIndex
                        ? destinations[i].selectedIcon
                        : destinations[i].icon,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个底栏目的地：图标 + 极小标签（选中 = 主色 + filled 图标）。
class _CompactBarItem extends StatelessWidget {
  const _CompactBarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Semantics(
      // 无障碍（NFR-06）：标记为按钮 + 选中态；label 由内部 Text 自动合并。
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppTokens.bottomBarIconSize, color: color),
            const SizedBox(height: AppTokens.spaceXxs),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontSize: AppTokens.bottomBarLabelSize,
                fontWeight: selected
                    ? AppTokens.textTitleWeight
                    : AppTokens.textBodyWeight,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
