import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/utils/app_breakpoints.dart';

/// Adaptive navigation shell (30-architecture.md §5).
///
/// - Narrow (<600dp): top AppBar (title + search/settings) + bottom NavigationBar
/// - Wide (≥600dp): top AppBar + left NavigationRail
///
/// 5 destinations: Inbox, Today, Calendar, Projects, Tags.
/// Highlight derived from the current route path.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child});

  /// Page title (from ARB, passed by each feature page).
  final String title;

  /// Page body content.
  final Widget child;

  /// 5 top-level destination paths (keep in sync with router.dart).
  static const List<String> _destinationPaths = [
    '/inbox',
    '/today',
    '/calendar',
    '/projects',
    '/tags',
  ];

  /// Derive destination index from route path; fall back to 0 (inbox).
  static int _selectedIndex(String path) {
    final index = _destinationPaths.indexOf(path);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = AppBreakpoints.isNarrow(context);
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);

    final destinations =
        <({String label, IconData icon, IconData selectedIcon})>[
          (
            label: l10n.navInbox,
            icon: Icons.inbox_outlined,
            selectedIcon: Icons.inbox,
          ),
          (
            label: l10n.navToday,
            icon: Icons.today_outlined,
            selectedIcon: Icons.today,
          ),
          (
            label: l10n.navCalendar,
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today,
          ),
          (
            label: l10n.navProjects,
            icon: Icons.folder_outlined,
            selectedIcon: Icons.folder,
          ),
          (
            label: l10n.navTags,
            icon: Icons.label_outline,
            selectedIcon: Icons.label,
          ),
        ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: narrow
          ? child
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      context.go(_destinationPaths[index]),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: child),
              ],
            ),
      bottomNavigationBar: narrow
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  context.go(_destinationPaths[index]),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }
}
