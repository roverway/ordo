import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 从原生 WindowInsetsAnimation 逐帧回调拿到的真实键盘高度（px，物理像素）。
/// 仅 Android API 30+ 有数据；其余平台/版本回退到 0，由调用方 fallback 到 MediaQuery。
class KeyboardInsetBridge {
  KeyboardInsetBridge._() {
    if (!kIsWeb && Platform.isAndroid) {
      _sub = const EventChannel('app.todo/keyboard_inset')
          .receiveBroadcastStream()
          .listen((event) {
            if (event is num) {
              hasReceivedEvents = true;
              imeHeightPx.value = event.toDouble();
            }
          }, onError: (_) {});
    }
  }

  static final KeyboardInsetBridge instance = KeyboardInsetBridge._();

  /// 是否已收到来自原生 WindowInsetsAnimation 的逐帧事件
  bool hasReceivedEvents = false;

  /// 原生物理像素高度；需要在使用处除以 devicePixelRatio 转成逻辑像素。
  final ValueNotifier<double> imeHeightPx = ValueNotifier<double>(0.0);

  StreamSubscription<dynamic>? _sub;

  void dispose() => _sub?.cancel();
}

/// 独立钉底、跟随软键盘平滑升降的工具栏容器。
///
/// 核心特性：
/// 1. 内部独立监听 [KeyboardInsetBridge]，不引发父页面或兄弟内容区的 Rebuild；
/// 2. 采用 [Transform.translate] 配合 [RepaintBoundary]，位移仅更新 GPU 图层矩阵，
///    完全规避父级 Stack / 任务编辑正文列表在键盘动画期间的 Relayout 与文本重排。
class KeyboardAttachedToolbar extends StatelessWidget {
  const KeyboardAttachedToolbar({
    super.key,
    required this.child,
    this.backgroundColor,
    this.elevation,
  });

  final Widget child;
  final Color? backgroundColor;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    final mediaQueryInset = MediaQuery.viewInsetsOf(context).bottom;
    final isAndroid = !kIsWeb && Platform.isAndroid;
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: KeyboardInsetBridge.instance.imeHeightPx,
        builder: (context, imeHeightPx, _) {
          final nativeInset = imeHeightPx / devicePixelRatio;
          final effectiveInset = isAndroid
              ? (KeyboardInsetBridge.instance.hasReceivedEvents
                    ? nativeInset
                    : mediaQueryInset)
              : mediaQueryInset;
          final bottomGap = (viewPaddingBottom - effectiveInset).clamp(
            0.0,
            double.infinity,
          );

          return Transform.translate(
            offset: Offset(0, -effectiveInset),
            child: Material(
              color: backgroundColor ?? colorScheme.surface,
              elevation: elevation ?? 0.0,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomGap),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 监听键盘高度并在变化时重新构建的通用构建器组件。
///
/// 封装了 devicePixelRatio 物理像素转换、Android 原生逐帧动画与 MediaQuery.viewInsets 自动兜底、
/// 以及底部手势条/安全区差值留白计算（bottomGap），有效降低页面端耦合度与重复编码。
class KeyboardInsetBuilder extends StatelessWidget {
  const KeyboardInsetBuilder({super.key, required this.builder, this.child});

  /// 构建回调：
  /// - [context]：当前的 BuildContext；
  /// - [effectiveInset]：当前真实逻辑像素键盘高度（优先原生逐帧，兜底 MediaQuery）；
  /// - [bottomGap]：手势条与键盘差值预留留白（max(0, viewPadding.bottom - effectiveInset)）；
  /// - [child]：预缓存的不变子组件。
  final Widget Function(
    BuildContext context,
    double effectiveInset,
    double bottomGap,
    Widget? child,
  )
  builder;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    final mediaQueryInset = MediaQuery.viewInsetsOf(context).bottom;
    final isAndroid = !kIsWeb && Platform.isAndroid;

    return ValueListenableBuilder<double>(
      valueListenable: KeyboardInsetBridge.instance.imeHeightPx,
      child: child,
      builder: (context, imeHeightPx, child) {
        final nativeInset = imeHeightPx / devicePixelRatio;
        // 在 Android 上原生通道激活时完全信赖 nativeInset，避免退场时与滞后的 mediaQueryInset 混用产生跳帧；
        // 若尚未收到原生事件（或非 Android 平台），则回退到 mediaQueryInset。
        final effectiveInset = isAndroid
            ? (KeyboardInsetBridge.instance.hasReceivedEvents
                  ? nativeInset
                  : mediaQueryInset)
            : mediaQueryInset;
        final bottomGap = (viewPaddingBottom - effectiveInset).clamp(
          0.0,
          double.infinity,
        );
        return builder(context, effectiveInset, bottomGap, child);
      },
    );
  }
}
