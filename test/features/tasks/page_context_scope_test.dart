import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/features/calendar/calendar_providers.dart';
import 'package:ordo/features/projects/project_providers.dart';
import 'package:ordo/features/settings/settings_providers.dart';
import 'package:ordo/features/tags/tag_providers.dart';
import 'package:ordo/features/tasks/page_context_provider.dart';
import 'package:ordo/features/tasks/widgets/quick_capture_bar.dart';
import 'package:ordo/shared/widgets/floating_minimal_dock.dart';
import '../../helpers/db_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageContextScope Domain Model Tests', () {
    test('fromTaskScope(TodayTaskScope) creates today context', () {
      final scope = PageContextScope.fromTaskScope(
        const TodayTaskScope(),
        route: '/today',
      );
      expect(scope.projectId, isNull);
      expect(scope.focusedDate, isNotNull);
      final now = DateTime.now();
      expect(scope.focusedDate!.year, equals(now.year));
      expect(scope.focusedDate!.month, equals(now.month));
      expect(scope.focusedDate!.day, equals(now.day));
      expect(scope.route, equals('/today'));
      expect(scope.taskScope, isA<TodayTaskScope>());
    });

    test('fromTaskScope(InboxTaskScope) creates inbox context', () {
      final scope = PageContextScope.fromTaskScope(
        const InboxTaskScope(),
        route: '/inbox',
      );
      expect(scope.projectId, equals(inboxProjectId));
      expect(scope.focusedDate, isNull);
      expect(scope.route, equals('/inbox'));
      expect(scope.taskScope, isA<InboxTaskScope>());
    });

    test('fromTaskScope(ProjectTaskScope) creates project context', () {
      const pid = 'proj-finance-2026';
      final scope = PageContextScope.fromTaskScope(
        const ProjectTaskScope(pid),
        route: '/projects/$pid',
      );
      expect(scope.projectId, equals(pid));
      expect(scope.focusedDate, isNull);
      expect(scope.route, equals('/projects/$pid'));
      expect(scope.taskScope, equals(const ProjectTaskScope(pid)));
    });

    test('fromCalendarDate creates calendar date context', () {
      final date = DateTime(2026, 10, 15, 9, 30);
      final scope = PageContextScope.fromCalendarDate(date);
      expect(scope.projectId, isNull);
      expect(scope.focusedDate, equals(date));
      expect(scope.route, equals('/calendar'));
      expect(scope.taskScope, isNull);
    });

    test('copyWith, equality and hashCode consistency', () {
      const scope1 = PageContextScope(projectId: 'p1', route: '/projects/p1');
      const scope2 = PageContextScope(projectId: 'p1', route: '/projects/p1');
      expect(scope1, equals(scope2));
      expect(scope1.hashCode, equals(scope2.hashCode));

      final modified = scope1.copyWith(projectId: 'p2');
      expect(modified.projectId, equals('p2'));
      expect(modified.route, equals('/projects/p1'));
      expect(scope1 == modified, isFalse);
    });
  });

  group('PageContextScopeNotifier & Provider Tests', () {
    test('Notifier lifecycle transitions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state
      expect(
        container.read(pageContextScopeProvider),
        equals(PageContextScope.empty),
      );

      // Transition to project
      container
          .read(pageContextScopeProvider.notifier)
          .setFromTaskScope(
            const ProjectTaskScope('p-alpha'),
            route: '/projects/p-alpha',
          );
      expect(
        container.read(pageContextScopeProvider).projectId,
        equals('p-alpha'),
      );

      // Transition to calendar
      final calDate = DateTime(2026, 12, 1);
      container
          .read(pageContextScopeProvider.notifier)
          .setCalendarDate(calDate);
      expect(
        container.read(pageContextScopeProvider).focusedDate,
        equals(calDate),
      );
      expect(container.read(pageContextScopeProvider).projectId, isNull);

      // Clear
      container.read(pageContextScopeProvider.notifier).clear();
      expect(
        container.read(pageContextScopeProvider),
        equals(PageContextScope.empty),
      );
    });
  });

  group('QuickCaptureBar Contextual Task Creation Tests ("所见即所建")', () {
    late AppDatabase db;
    late TodoRepository repo;
    late Project workProject;
    late AppSettingsCache cache;

    setUp(() async {
      db = openTestDatabase();
      repo = TodoRepository(database: db);
      await repo.ensureInboxProject('收集箱');
      workProject = await repo.createProject(name: '工作项目', color: 0xFF2196F3);
      cache = AppSettingsCache();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'QuickCaptureBar inherits initialProjectId and creates task in that project',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appSettingsCacheProvider.overrideWithValue(cache),
              todoRepositoryProvider.overrideWithValue(repo),
              projectsStreamProvider.overrideWithValue(
                AsyncData([workProject]),
              ),
              tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: QuickCaptureBar(initialProjectId: workProject.id),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Project chip should reflect '工作项目'
        expect(find.text('工作项目'), findsOneWidget);

        // Enter task title
        final inputField = find.byType(TextField);
        expect(inputField, findsOneWidget);
        await tester.enterText(inputField, '撰写季度总结');
        await tester.pumpAndSettle();

        // Submit via arrow up button
        final submitBtn = find.byIcon(Icons.arrow_upward_rounded);
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify task in DB
        final tasks = await repo.tasks.getByProject(workProject.id);
        expect(tasks.length, equals(1));
        expect(tasks.first.title, equals('撰写季度总结'));
        expect(tasks.first.projectId, equals(workProject.id));
      },
    );

    testWidgets(
      'QuickCaptureBar inherits initialDate and creates task on that date',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final targetDate = DateTime(2026, 10, 15, 9, 0);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appSettingsCacheProvider.overrideWithValue(cache),
              todoRepositoryProvider.overrideWithValue(repo),
              projectsStreamProvider.overrideWithValue(
                AsyncData([workProject]),
              ),
              tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: QuickCaptureBar(
                  initialProjectId: workProject.id,
                  initialDate: targetDate,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Capsule row should display the specific date "10月15日"
        expect(find.text('10月15日'), findsWidgets);

        // Enter task title without date keyword
        final inputField = find.byType(TextField);
        await tester.enterText(inputField, '日历指定日任务');
        await tester.pumpAndSettle();

        // Submit
        final submitBtn = find.byIcon(Icons.arrow_upward_rounded);
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify task in DB carries targetDate startAt
        final tasks = await repo.tasks.getByProject(workProject.id);
        expect(tasks.length, equals(1));
        expect(tasks.first.title, equals('日历指定日任务'));
        expect(tasks.first.startAt, equals(targetDate.millisecondsSinceEpoch));
      },
    );
  });

  group('FloatingMinimalDock Contextual Quick Capture Integration Tests', () {
    late AppDatabase db;
    late TodoRepository repo;
    late Project devProject;
    late AppSettingsCache cache;

    setUp(() async {
      db = openTestDatabase();
      repo = TodoRepository(database: db);
      await repo.ensureInboxProject('收集箱');
      devProject = await repo.createProject(name: '研发项目', color: 0xFF4CAF50);
      cache = AppSettingsCache();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Clicking FAB on FloatingMinimalDock in project route pre-fills project in QuickCaptureBar',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            appSettingsCacheProvider.overrideWithValue(cache),
            todoRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWithValue(AsyncData([devProject])),
            tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
          ],
        );
        addTearDown(container.dispose);

        // Pre-set pageContextScopeProvider to project scope
        container
            .read(pageContextScopeProvider.notifier)
            .setFromTaskScope(
              ProjectTaskScope(devProject.id),
              route: '/projects/${devProject.id}',
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FloatingMinimalDock(
                  currentRoute: '/projects/${devProject.id}',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the FAB in the Action Island
        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // QuickCaptureBar bottom sheet opens with '研发项目'
        expect(find.byType(QuickCaptureBar), findsOneWidget);
        expect(find.text('研发项目'), findsOneWidget);
      },
    );

    testWidgets(
      'Clicking FAB on FloatingMinimalDock in calendar route pre-fills selectedDate in QuickCaptureBar',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final container = ProviderContainer(
          overrides: [
            appSettingsCacheProvider.overrideWithValue(cache),
            todoRepositoryProvider.overrideWithValue(repo),
            projectsStreamProvider.overrideWithValue(AsyncData([devProject])),
            tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
          ],
        );
        addTearDown(container.dispose);

        final targetCalendarDate = DateTime(2026, 11, 20, 9, 0);
        container
            .read(calendarStateProvider.notifier)
            .selectDate(targetCalendarDate);
        container
            .read(pageContextScopeProvider.notifier)
            .setCalendarDate(targetCalendarDate, route: '/calendar');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FloatingMinimalDock(currentRoute: '/calendar'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap FAB
        final fab = find.byType(FloatingActionButton);
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // QuickCaptureBar bottom sheet opens with 11月20日 capsule
        expect(find.byType(QuickCaptureBar), findsOneWidget);
        expect(find.text('11月20日'), findsWidgets);
      },
    );
  });
}
