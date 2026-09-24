import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/utils/custom_view_models.dart';
import 'package:ordo/features/custom_views/widgets/filter_criteria_sheet.dart';
import 'package:ordo/features/projects/project_providers.dart';
import 'package:ordo/features/tags/tag_providers.dart';
import 'package:ordo/shared/widgets/settings_card.dart';

void main() {
  group('FilterCriteriaSheet & SettingsCard', () {
    testWidgets('SettingsCard renders children correctly', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            locale: Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SettingsCard(
                children: [Text('Card Header'), Text('Card Body')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Card Header'), findsOneWidget);
      expect(find.text('Card Body'), findsOneWidget);
      expect(find.byType(SettingsCard), findsOneWidget);
    });

    testWidgets(
      'FilterCriteriaSheet renders sections and handles interactions',
      (tester) async {
        FilterCriteria? appliedCriteria;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              projectsStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              foldersStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              tagsStreamProvider.overrideWith((ref) => Stream.value(const [])),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () async {
                        appliedCriteria = await showFilterCriteriaSheet(
                          context: context,
                          initialCriteria: const FilterCriteria(
                            statuses: [TaskStatus.todo],
                            priorities: [TaskPriority.high],
                          ),
                        );
                      },
                      child: const Text('Open Filter'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Open sheet / dialog
        await tester.tap(find.text('Open Filter'));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(tester.element(find.byType(Dialog)));

        // Check header and buttons
        expect(find.text(l10n.filterCriteria), findsOneWidget);
        expect(find.text(l10n.resetFilter), findsOneWidget);
        expect(find.text(l10n.applyFilter), findsOneWidget);

        // Check status pills
        expect(find.text(l10n.statusTodo), findsOneWidget);
        expect(find.text(l10n.statusInProgress), findsOneWidget);
        expect(find.text(l10n.statusDone), findsOneWidget);

        // Check priority pills
        expect(find.text(l10n.priorityHigh), findsOneWidget);
        expect(find.text(l10n.priorityMedium), findsOneWidget);
        expect(find.text(l10n.priorityLow), findsOneWidget);
        expect(find.text(l10n.priorityNone), findsOneWidget);

        // Toggle '进行中'
        await tester.tap(find.text(l10n.statusInProgress));
        await tester.pumpAndSettle();

        // Apply
        await tester.tap(find.text(l10n.applyFilter));
        await tester.pumpAndSettle();

        expect(appliedCriteria, isNotNull);
        expect(
          appliedCriteria!.statuses,
          containsAll([TaskStatus.todo, TaskStatus.inProgress]),
        );
        expect(appliedCriteria!.priorities, contains(TaskPriority.high));
      },
    );

    testWidgets('FilterCriteriaSheet reset button clears selections', (
      tester,
    ) async {
      FilterCriteria? appliedCriteria;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectsStreamProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            foldersStreamProvider.overrideWith((ref) => Stream.value(const [])),
            tagsStreamProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      appliedCriteria = await showFilterCriteriaSheet(
                        context: context,
                        initialCriteria: const FilterCriteria(
                          statuses: [TaskStatus.todo],
                          priorities: [TaskPriority.high],
                        ),
                      );
                    },
                    child: const Text('Open Filter'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Filter'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(Dialog)));

      // Tap Reset
      await tester.tap(find.text(l10n.resetFilter));
      await tester.pumpAndSettle();

      // Tap Apply
      await tester.tap(find.text(l10n.applyFilter));
      await tester.pumpAndSettle();

      expect(appliedCriteria, isNotNull);
      expect(appliedCriteria!.statuses, isEmpty);
      expect(appliedCriteria!.priorities, isEmpty);
    });
  });
}
