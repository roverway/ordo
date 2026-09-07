import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';

import '../../core/theme/app_tokens.dart';

/// 筛选栏下方内联平滑展开的搜索输入框。
///
/// 见于 `home.html` / `tasklist.html`。
class InlineSearchBar extends StatefulWidget {
  const InlineSearchBar({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hintText,
    this.matchCount,
  });

  final bool isOpen;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String? hintText;
  final int? matchCount;

  @override
  State<InlineSearchBar> createState() => _InlineSearchBarState();
}

class _InlineSearchBarState extends State<InlineSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return AnimatedSize(
      duration: AppTokens.motionNormal,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: widget.isOpen
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: AppTokens.motionFast,
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _isFocused
                          ? colorScheme.surface
                          : (isDark
                                ? colorScheme.onSurface.withValues(alpha: 0.08)
                                : colorScheme.onSurface.withValues(
                                    alpha: 0.06,
                                  )),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isFocused
                            ? colorScheme.onSurface.withValues(
                                alpha: isDark ? 0.38 : 0.32,
                              )
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            onChanged: widget.onChanged,
                            style: TextStyle(
                              fontSize: 14.5,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.hintText ?? l10n.searchTasks,
                              hintStyle: TextStyle(
                                fontSize: 14.5,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (widget.controller.text.isNotEmpty)
                          InkWell(
                            onTap: () {
                              widget.controller.clear();
                              widget.onClear();
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.matchCount != null &&
                      widget.controller.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        l10n.searchMatchCount(widget.matchCount!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
