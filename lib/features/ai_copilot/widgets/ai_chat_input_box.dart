import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Linear 风格微光对话输入框。
///
/// 具备沉浸式深灰/浅灰凹陷底色（[AppTokens.surfaceSunkenDark]）、
/// 获得焦点时的微光轮廓线（[AppTokens.borderSubtleHoverDark]）与轻量发送按钮。
class AiChatInputBox extends StatefulWidget {
  const AiChatInputBox({
    super.key,
    ValueChanged<String>? onSend,
    ValueChanged<String>? onSubmitted,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.hintText,
  }) : onSend = onSend ?? onSubmitted ?? _defaultOnSend;

  static void _defaultOnSend(String _) {}

  /// 发送回调
  final ValueChanged<String> onSend;

  /// 外部传入的文本控制器（可选）
  final TextEditingController? controller;

  /// 外部传入的焦点（可选）
  final FocusNode? focusNode;

  /// 是否可用
  final bool enabled;

  /// 自定义提示文案（可选）
  final String? hintText;

  /// 发送按钮 Key
  static const Key sendButtonKey = Key('ai_chat_input_send_button');

  @override
  State<AiChatInputBox> createState() => _AiChatInputBoxState();
}

class _AiChatInputBoxState extends State<AiChatInputBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isSelfController = false;
  bool _isSelfFocusNode = false;
  bool _isFocused = false;
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _isSelfController = true;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isSelfFocusNode = true;
    }

    _canSend = _controller.text.trim().isNotEmpty;
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleTextChanged() {
    final canSend = _controller.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (_isSelfController) {
      _controller.dispose();
    }
    if (_isSelfFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;

    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? AppTokens.surfaceSunkenDark
        : AppTokens.surfaceSunkenLight;

    // Linear 质感：聚焦时产生微光高亮边缘，未聚焦时采用极弱细边框
    final borderColor = _isFocused
        ? (isDark ? AppTokens.borderSubtleHoverDark : theme.colorScheme.primary)
        : (isDark ? AppTokens.borderSubtleDark : AppTokens.borderSubtleLight);

    return AnimatedContainer(
      duration: AppTokens.motionFast,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? l10n.aiInputHint,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: AppTokens.alphaContentMuted,
                  ),
                  fontSize: AppTokens.textSecondarySize,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              right: AppTokens.spaceXs,
              bottom: AppTokens.spaceXs,
            ),
            child: IconButton(
              key: AiChatInputBox.sendButtonKey,
              onPressed: (_canSend && widget.enabled) ? _submit : null,
              icon: Icon(
                Icons.arrow_upward,
                size: AppTokens.menuItemIconSize,
                color: (_canSend && widget.enabled)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentDisabled,
                      ),
              ),
              tooltip: l10n.aiSend,
            ),
          ),
        ],
      ),
    );
  }
}
