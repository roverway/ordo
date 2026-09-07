import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';

/// 左滑露出的单个快捷操作按钮描述（图标 + 色 + 回调），视觉由 [SwipeActions] 统一渲染。
class SwipeActionSpec {
  const SwipeActionSpec({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  /// 无障碍/长按提示文案（走 ARB）。
  final String tooltip;
  final VoidCallback onTap;
}

/// 任务行滑动操作包装组件。
///
/// - **左滑**（手指/光标左移）：内容跟随左移，右侧露出 [startActions] 快捷按钮；
///   按钮随滑动距离平滑渐显、缩放并微平移；松手过半吸附展开，点击按钮后收起并触发回调。
/// - **右滑**（手指/光标右移）：左侧露出 [endSwipeColor] 完成区，位移超过
///   [AppTokens.swipeCompleteThreshold] 时进入「已蓄力」态（触觉反馈 + 强化
///   视觉），松手即触发 [onEndSwipeTriggered] 并回弹归零（Mail 式直接触发，
///   不是露出按钮）。再次右滑可反向切换回未完成。
///
/// 桌面平台（windows/linux/macOS）原样返回 [child]，不注册任何手势层——
/// 任务树行的右键菜单等桌面交互不受影响。
class SwipeActions extends StatefulWidget {
  const SwipeActions({
    super.key,
    required this.child,
    this.startActions = const <SwipeActionSpec>[],
    this.onEndSwipeTriggered,
    this.endSwipeEnabled = false,
    this.endSwipeColor = AppTokens.colorDone,
    this.endSwipeIcon = Icons.check,
  });

  final Widget child;

  /// 左滑露出的快捷操作按钮（从右往左排列）。
  final List<SwipeActionSpec> startActions;

  /// 右滑超过阈值松手后的回调（完成状态切换）。
  final VoidCallback? onEndSwipeTriggered;

  /// 右滑是否可用（有子任务的任务状态由子任务派生，禁用右滑）。
  final bool endSwipeEnabled;

  /// 右滑完成区背景色（完成=绿）。
  final Color endSwipeColor;

  /// 右滑完成区图标（未完成→完成用勾，反向切换由调用方传 undo 类图标）。
  final IconData endSwipeIcon;

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions>
    with SingleTickerProviderStateMixin {
  /// 负值 = 左滑（露出快捷按钮），正值 = 右滑（完成蓄力）。
  double _dragOffset = 0;
  bool _endArmed = false;
  bool _isDesktopPlatform = false;

  late final AnimationController _controller;
  Animation<double>? _animation;

  double get _maxReveal =>
      widget.startActions.length * AppTokens.swipeActionWidth;

  double get _maxEndDrag =>
      AppTokens.swipeCompleteThreshold + AppTokens.swipeCompleteOverdrag;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.motionNormal,
    )..addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    if (_animation != null) {
      setState(() => _dragOffset = _animation!.value);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDesktopPlatform = _resolveDesktop(Theme.of(context).platform);
  }

  static bool _resolveDesktop(TargetPlatform platform) =>
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux ||
      platform == TargetPlatform.macOS;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta == 0) return;
    setState(() {
      var next = _dragOffset + delta;
      if (next > 0) {
        if (!widget.endSwipeEnabled) {
          // 禁用右滑（父任务派生状态）：零位移硬钳制，不给任何蓄力反馈。
          _dragOffset = 0;
          _endArmed = false;
          return;
        }
        if (next > _maxEndDrag) next = _maxEndDrag;
        final armed = next >= AppTokens.swipeCompleteThreshold;
        if (armed && !_endArmed) HapticFeedback.mediumImpact();
        _endArmed = armed;
      } else {
        _endArmed = false;
        if (next < -_maxReveal) next = -_maxReveal;
      }
      _dragOffset = next;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset < 0) {
      // 左滑：过半吸附展开，否则收起。
      _animateTo(_dragOffset < -_maxReveal / 2 ? -_maxReveal : 0);
      return;
    }
    final triggered = _endArmed;
    _endArmed = false;
    _animateTo(0);
    if (triggered) widget.onEndSwipeTriggered?.call();
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _controller, curve: AppTokens.motionSpring),
    );
    _controller
      ..reset()
      ..forward();
  }

  void _collapse() {
    if (_dragOffset != 0) _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktopPlatform) return widget.child;

    final hasStartActions = widget.startActions.isNotEmpty;
    final hasEndSwipe =
        widget.endSwipeEnabled && widget.onEndSwipeTriggered != null;
    if (!hasStartActions && !hasEndSwipe) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;
    final endProgress = (_dragOffset / AppTokens.swipeCompleteThreshold).clamp(
      0.0,
      1.0,
    );

    return ClipRect(
      child: Stack(
        children: [
          // 右滑完成区（内容右移后左侧露出的绿色反馈条，图标与背景渐进显现）
          if (_dragOffset > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _dragOffset,
              child: Container(
                color: widget.endSwipeColor.withValues(
                  alpha: _endArmed
                      ? 1.0
                      : AppTokens.swipeCompleteMinAlpha +
                            (1 - AppTokens.swipeCompleteMinAlpha) * endProgress,
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: (endProgress * 1.5).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * endProgress,
                    child: Icon(
                      widget.endSwipeIcon,
                      size: 20 + 4 * endProgress,
                      color: _endArmed
                          ? colorScheme.onPrimary
                          : widget.endSwipeColor,
                    ),
                  ),
                ),
              ),
            ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            // 不给 child 铺底色：任务行多为透明底叠在页面/卡片底色上，
            // 静止态保持原视觉，滑动时由左/右反馈层填补露出区。
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: widget.child,
            ),
          ),

          // 左滑露出的快捷按钮层（随滑动进度渐显、平移与缩放）
          if (_dragOffset < 0 && hasStartActions) _buildRevealedActions(),
        ],
      ),
    );
  }

  Widget _buildRevealedActions() {
    final rawProgress = (-_dragOffset / _maxReveal).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(rawProgress);

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: _maxReveal,
      child: Opacity(
        opacity: eased,
        child: Transform.translate(
          offset: Offset((1.0 - eased) * 16, 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceXs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var i = widget.startActions.length - 1; i >= 0; i--)
                  Transform.scale(
                    scale: 0.75 + 0.25 * eased,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppTokens.spaceXxs),
                      child: _SwipeActionButton(
                        spec: widget.startActions[i],
                        onTap: () {
                          _collapse();
                          widget.startActions[i].onTap();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 左滑快捷按钮（圆角方块 + 语义 tint 底 + 主题色图标，与全局按钮风格一致）。
class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({required this.spec, required this.onTap});

  final SwipeActionSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: spec.tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        child: Container(
          width: AppTokens.swipeActionButtonSize,
          height: AppTokens.swipeActionButtonSize,
          decoration: BoxDecoration(
            color: spec.backgroundColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
          alignment: Alignment.center,
          child: Icon(spec.icon, size: 20, color: spec.iconColor),
        ),
      ),
    );
  }
}
