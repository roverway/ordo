import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import 'scope_nav_content.dart';

/// 呼出任务清单组上下文切换弹层（今日、收件箱、各项目清单与文件夹）。
Future<void> showTaskScopeSheet(BuildContext context, {String? currentRoute}) {
  return showScopeSwitcherSheet(
    context,
    currentRoute: currentRoute,
    filter: ScopeNavFilter.tasksOnly,
  );
}

/// 呼出特殊视图组上下文切换弹层（四象限、日历、概览、自定义视图）。
Future<void> showViewScopeSheet(BuildContext context, {String? currentRoute}) {
  return showScopeSwitcherSheet(
    context,
    currentRoute: currentRoute,
    filter: ScopeNavFilter.viewsOnly,
  );
}

/// 呼出清单/作用域切换底部弹层。
Future<void> showScopeSwitcherSheet(
  BuildContext context, {
  String? currentRoute,
  ScopeNavFilter filter = ScopeNavFilter.all,
}) {
  final route = currentRoute ?? resolveCurrentRoute(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ScopeSwitcherSheet(currentRoute: route, filter: filter),
  );
}

/// 现代极简风格的清单/视图切换底部弹层。
class ScopeSwitcherSheet extends ConsumerWidget {
  const ScopeSwitcherSheet({
    super.key,
    this.currentRoute,
    this.filter = ScopeNavFilter.all,
  });

  final String? currentRoute;
  final ScopeNavFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTokens.sheetTopBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTokens.alphaTintStrong),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部抓手 (Grabber)
            Container(
              width: AppTokens.sheetGrabberWidth,
              height: AppTokens.sheetGrabberHeight,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(
                  alpha: AppTokens.alphaTintStrong,
                ),
                borderRadius: BorderRadius.circular(
                  AppTokens.sheetGrabberRadius,
                ),
              ),
            ),

            // 核心导航树与清单列表
            Flexible(
              child: ScopeNavContent(
                currentRoute: currentRoute,
                isModal: true,
                showHeader: false,
                filter: filter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
