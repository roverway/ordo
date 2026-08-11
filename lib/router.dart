import 'package:go_router/go_router.dart';
import 'features/calendar/calendar_page.dart';
import 'features/projects/project_detail_page.dart';
import 'features/projects/projects_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/tags/tags_page.dart';
import 'features/tasks/task_edit_page.dart';
import 'features/today/today_page.dart';

/// 全局路由表（唯一）—— 30-architecture.md §4。
///
/// M0：4 个一级目的地 + 搜索 + 设置。
/// M2：新增 /projects/:id、/task/:id、/task/new。
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const TodayPage()),
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
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ProjectDetailPage(projectId: id);
      },
    ),
    GoRoute(path: '/tags', builder: (context, state) => const TagsPage()),
    GoRoute(
      path: '/task/new',
      builder: (context, state) {
        final projectId = state.uri.queryParameters['projectId'];
        final parentId = state.uri.queryParameters['parentId'];
        return TaskEditPage(projectId: projectId, parentId: parentId);
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
    ),
    // TODO(M4): /settings/sync 同步配置
  ],
);
