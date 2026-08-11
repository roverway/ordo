import 'package:go_router/go_router.dart';

import 'features/calendar/calendar_page.dart';
import 'features/projects/projects_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/tags/tags_page.dart';
import 'features/today/today_page.dart';

/// 全局路由表（唯一）—— 30-architecture.md §4。
///
/// M0 阶段包含 4 个一级目的地 + 搜索 + 设置；
/// M1+ 将追加 `/projects/:id`、`/tags/:id`、`/task/:id` 等详情路由。
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
    GoRoute(path: '/tags', builder: (context, state) => const TagsPage()),
    // TODO(M1): /projects/:id 项目详情（任务树）、/tags/:id 标签任务列表、
    //           /task/:id 任务编辑/详情
    GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    // TODO(M4): /settings/sync 同步配置
  ],
);
