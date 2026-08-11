import 'package:go_router/go_router.dart';
import 'features/calendar/calendar_page.dart';
import 'features/inbox/inbox_page.dart';
import 'features/projects/project_detail_page.dart';
import 'features/projects/projects_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/tags/tags_page.dart';
import 'features/tasks/task_edit_page.dart';
import 'features/today/today_page.dart';

/// Global routing table — single source of truth (30-architecture.md §4).
///
/// 5 top-level destinations: Inbox, Today, Calendar, Projects, Tags.
/// Inbox is the launch home (initialLocation).
final GoRouter appRouter = GoRouter(
  initialLocation: '/inbox',
  routes: [
    GoRoute(path: '/inbox', builder: (context, state) => const InboxPage()),
    GoRoute(path: '/today', builder: (context, state) => const TodayPage()),
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
  ],
);
