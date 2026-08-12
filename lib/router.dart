import 'package:go_router/go_router.dart';
import 'features/calendar/calendar_page.dart';
import 'features/projects/projects_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/sync_setup/sync_setup_page.dart';
import 'features/tags/tags_page.dart';
import 'features/tags/tags_detail_page.dart';
import 'features/tasks/task_edit_page.dart';
import 'features/tasks/task_list_page.dart';

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
      builder: (context, state) =>
          TaskListPage(scope: ProjectTaskScope(state.pathParameters['id']!)),
    ),
    GoRoute(path: '/tags', builder: (context, state) => const TagsPage()),
    GoRoute(
      path: '/tags/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TagsDetailPage(tagId: id);
      },
    ),
    GoRoute(
      path: '/task/new',
      builder: (context, state) {
        final projectId = state.uri.queryParameters['projectId'];
        final parentId = state.uri.queryParameters['parentId'];
        // 日历「点日期新建」等场景可预填起止时间（UTC 毫秒，M3）。
        final startAt = int.tryParse(
          state.uri.queryParameters['startAt'] ?? '',
        );
        final endAt = int.tryParse(state.uri.queryParameters['endAt'] ?? '');
        return TaskEditPage(
          projectId: projectId,
          parentId: parentId,
          initialStartAt: startAt,
          initialEndAt: endAt,
        );
      },
    ),
    GoRoute(
      path: '/task/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TaskEditPage(taskId: id);
      },
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
      routes: [
        // 同步配置页是设置页的**子路由**（绝对路径仍为 /settings/sync）。
        // 从设置页 `go('/settings/sync')` 时导航栈为 root→settings→sync，
        // sync 页 AppBar 自动出现返回箭头回设置页（go 会重建祖先链，
        // 平级顶层路由时 /settings 会被丢弃导致无法返回 —— 用户实测 bug）。
        GoRoute(
          path: 'sync',
          builder: (context, state) => const SyncSetupPage(),
        ),
      ],
    ),
  ],
);
