import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'core/utils/motion.dart';
import 'features/calendar/calendar_page.dart';
import 'features/custom_views/presentation/custom_view_editor_page.dart';
import 'features/custom_views/presentation/custom_view_page.dart';
import 'features/projects/projects_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/sync_setup/sync_setup_page.dart';
import 'features/tags/tags_page.dart';
import 'features/tags/tags_detail_page.dart';
import 'features/tasks/task_edit_page.dart';
import 'features/tasks/task_list_page.dart';

/// 滑动式页面转场（docs/63-motion-polish.md §5 D）。
///
/// push（进入详情/编辑/设置等下级页）：右→左滑入 + 淡入；pop 反向滑出。
/// - 时长：`motionNormal`（250ms 令牌；reduced motion → 瞬时）；
/// - 曲线：`motionCurve`（easeOutCubic 令牌；reduced motion → easeOut）。
///
/// 仅用于「下级页」路由（/projects/:id、/task/:id、/settings 等 push 目标）；
/// 一级目的地（今日/日历/项目/标签等 tab 级切换）保持 `builder:` 轻量直切，
/// 避免频繁切换动画过重。
Page<void> _slideFadePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: motionNormal(context),
    reverseTransitionDuration: motionNormal(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: animation, curve: motionCurve(context)),
          );
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
    child: child,
  );
}

/// Global routing table — single source of truth (30-architecture.md §4).
///
/// 任务类入口（今日/收件箱/项目）统一渲染 `TaskListPage`（作用域驱动，
/// 56-task-scope-page.md §3.1）；今日为启动默认页（D3）。
final GoRouter appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    GoRoute(
      path: '/inbox',
      builder: (context, state) => const TaskListPage(scope: InboxTaskScope()),
    ),
    GoRoute(
      path: '/today',
      builder: (context, state) => const TaskListPage(scope: TodayTaskScope()),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarPage(),
    ),
    GoRoute(
      path: '/projects',
      builder: (context, state) => const ProjectsPage(),
    ),
    GoRoute(
      path: '/projects/:id',
      // 下级页（抽屉/项目入口 push）：滑动式转场（63-motion-polish §5 D）。
      pageBuilder: (context, state) => _slideFadePage(
        context,
        state,
        TaskListPage(scope: ProjectTaskScope(state.pathParameters['id']!)),
      ),
    ),
    GoRoute(path: '/tags', builder: (context, state) => const TagsPage()),
    GoRoute(
      path: '/tags/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _slideFadePage(context, state, TagsDetailPage(tagId: id));
      },
    ),
    GoRoute(
      path: '/task/new',
      pageBuilder: (context, state) {
        final projectId = state.uri.queryParameters['projectId'];
        final parentId = state.uri.queryParameters['parentId'];
        // 日历「点日期新建」等场景可预填起止时间（UTC 毫秒，M3）。
        final startAt = int.tryParse(
          state.uri.queryParameters['startAt'] ?? '',
        );
        final endAt = int.tryParse(state.uri.queryParameters['endAt'] ?? '');
        return _slideFadePage(
          context,
          state,
          TaskEditPage(
            projectId: projectId,
            parentId: parentId,
            initialStartAt: startAt,
            initialEndAt: endAt,
          ),
        );
      },
    ),
    GoRoute(
      path: '/task/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _slideFadePage(context, state, TaskEditPage(taskId: id));
      },
    ),
    GoRoute(
      path: '/custom_view/new',
      pageBuilder: (context, state) =>
          _slideFadePage(context, state, const CustomViewEditorPage()),
    ),
    GoRoute(
      path: '/custom_view/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _slideFadePage(context, state, CustomViewPage(viewId: id));
      },
    ),
    GoRoute(
      path: '/custom_view/:id/edit',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id']!;
        return _slideFadePage(context, state, CustomViewEditorPage(viewId: id));
      },
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) =>
          _slideFadePage(context, state, const SearchPage()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _slideFadePage(context, state, const SettingsPage()),
      routes: [
        // 同步配置页是设置页的**子路由**（绝对路径仍为 /settings/sync）。
        // 从设置页 `push('/settings/sync')` 时导航栈为 任务页→settings→sync，
        // 返回箭头一路可用：sync 回 settings、settings 回任务页。
        // 注意：不能用 `go('/settings/sync')` —— go 会把整个导航栈替换为
        // [settings, sync]，丢弃进入设置前的任务页，设置页将无路可返
        //（go_router 17 `NavigatingType.go` 直接 `return newMatchList`，
        //  用户实测 bug：同步配置页能回设置页但设置页回不了任务页）。
        GoRoute(
          path: 'sync',
          pageBuilder: (context, state) =>
              _slideFadePage(context, state, const SyncSetupPage()),
        ),
      ],
    ),
  ],
);
