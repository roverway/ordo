import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
              imeHeightPx.value = event.toDouble();
            }
          }, onError: (_) {});
    }
  }

  static final KeyboardInsetBridge instance = KeyboardInsetBridge._();

  /// 原生物理像素高度；需要在使用处除以 devicePixelRatio 转成逻辑像素。
  final ValueNotifier<double> imeHeightPx = ValueNotifier<double>(0.0);

  StreamSubscription<dynamic>? _sub;

  void dispose() => _sub?.cancel();
}
