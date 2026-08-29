package com.example.todo

import android.os.Build
import android.os.Bundle
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import androidx.annotation.RequiresApi
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.todo/keyboard_inset"
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // 必须在 super.onCreate 之前启用 edge-to-edge，
        // 否则系统不会把逐帧 WindowInsetsAnimation 回调分发下来。
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            attachImeAnimationCallback()
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun attachImeAnimationCallback() {
        window.decorView.setWindowInsetsAnimationCallback(
            object : WindowInsetsAnimation.Callback(DISPATCH_MODE_CONTINUE_ON_SUBTREE) {
                override fun onProgress(
                    insets: WindowInsets,
                    runningAnimations: MutableList<WindowInsetsAnimation>
                ): WindowInsets {
                    // 每一帧都会回调，跟真实键盘视觉进度完全同步。
                    val imeBottom = insets.getInsets(WindowInsets.Type.ime()).bottom
                    eventSink?.success(imeBottom.toDouble())
                    return insets
                }

                override fun onEnd(animation: WindowInsetsAnimation) {
                    super.onEnd(animation)
                    val imeBottom = window.decorView.rootWindowInsets?.getInsets(WindowInsets.Type.ime())?.bottom ?: 0
                    eventSink?.success(imeBottom.toDouble())
                }
            }
        )
    }
}

