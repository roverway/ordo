import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 筛选栏下方内联平滑展开的搜索输入框。
///
/// 见于 `home.html` / `tasklist.html`。
class InlineSearchBar extends StatelessWidget {
  const InlineSearchBar({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText = '搜索任务',
  });

  final bool isOpen;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedSize(
      duration: AppTokens.motionNormal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: isOpen
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        )
                      : colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: onChanged,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(
                            fontSize: 14.5,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (controller.text.isNotEmpty)
                      InkWell(
                        onTap: () {
                          controller.clear();
                          onClear();
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
