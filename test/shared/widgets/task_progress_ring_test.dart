// 任务进度环动效测试（docs/63-motion-polish.md §5 F）。
//
// 覆盖：
// - 常规：value 变化时圆环平滑扫过（motionNormal + easeOutCubic），
//   最终停在目标值；
// - reduced motion（NFR-06）：`MediaQuery.disableAnimations` 时瞬时到位，
//   无中间帧（时长零降级路径）。
//
// reduced motion 经 `tester.platformDispatcher.accessibilityFeaturesTestValue`
// 注入（63-motion-polish.md §8）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/shared/widgets/task_progress_ring.dart';

Future<void> _pumpRing(WidgetTester tester, double value) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: TaskProgressRing(value: value)),
      ),
    ),
  );
}

void main() {
  testWidgets('value 变化时圆环平滑扫过（motionNormal + easeOut）', (tester) async {
    await _pumpRing(tester, 0.3);
    CircularProgressIndicator ring() =>
        tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

    // 首帧即停在初始值（TweenAnimationBuilder 首次 build 不播放入场动画）。
    expect(ring().value, 0.3);

    // 值变化 → 动画进行中：圆环值严格介于新旧之间（非瞬时跳变）。
    await _pumpRing(tester, 0.8);
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // motionNormal 250ms 中段
    final mid = ring().value;
    expect(mid, greaterThan(0.3));
    expect(mid, lessThan(0.8));

    // 动画结束 → 停在目标值；百分比数字同步（无「数字先跳」割裂）。
    await tester.pumpAndSettle();
    expect(ring().value, 0.8);
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('reduced motion：value 变化瞬时到位（无中间帧）', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpRing(tester, 0.3);
    await _pumpRing(tester, 0.8);
    // 降级路径时长为零：仅 pump 一帧即完成，圆环直接停在目标值。
    await tester.pump();
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.8);
  });

  testWidgets('Semantics 无障碍结构保持：label 取最终值，子级排除', (tester) async {
    await _pumpRing(tester, 0.8);

    // 读屏播报最终完成度（0.8 → 80%）。
    final semantics = tester.getSemantics(find.byType(TaskProgressRing));
    expect(semantics.label, contains('80%'));
    // 圆环 + 数字在 ExcludeSemantics 内，不重复播报。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
