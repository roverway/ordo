import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../../shared/widgets/app_menu_item.dart';
import '../../../shared/widgets/page_hero_header.dart';
import '../../../shared/widgets/scope_switcher_sheet.dart';
import '../providers/custom_view_providers.dart';
import '../widgets/panel_column.dart';
import 'custom_view_action_handler.dart';
import 'custom_view_editor_page.dart';

/// 自定义视图主页面（支持多栏看板与多 Tab 列表切换）。
class CustomViewPage extends ConsumerStatefulWidget {
  const CustomViewPage({super.key, required this.viewId});

  final String viewId;

  @override
  ConsumerState<CustomViewPage> createState() => _CustomViewPageState();
}

class _CustomViewPageState extends ConsumerState<CustomViewPage> {
  late final ScrollController _horizontalScrollController;
  late final CustomViewActionHandler _actionHandler;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _actionHandler = CustomViewActionHandler(ref);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _openEditView(BuildContext context, CustomView view) {
    if (AppBreakpoints.isNarrow(context)) {
      context.push('/custom_view/${view.id}/edit');
    } else {
      showCustomViewEditorSideSheet(context, viewId: view.id);
    }
  }

  Widget _buildTrailingActions(
    BuildContext context,
    AppLocalizations l10n,
    CustomView view,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.editCustomView,
          icon: const Icon(Icons.tune, size: 20),
          onPressed: () => _openEditView(context, view),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (val) {
            if (val == 'delete') {
              _actionHandler.confirmDeleteView(context, view);
            }
          },
          itemBuilder: (ctx) => [
            AppMenuItem(
              value: 'delete',
              icon: Icons.delete_outline,
              label: l10n.deleteCustomView,
              destructive: true,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = AppBreakpoints.isWide(context);
    final narrow = AppBreakpoints.isNarrow(context);

    final viewAsync = ref.watch(customViewDetailProvider(widget.viewId));

    return viewAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text(err.toString()))),
      data: (CustomView? view) {
        if (view == null) {
          return Scaffold(body: Center(child: Text(l10n.noCustomViews)));
        }

        final panels = decodePanelsJson(view.panelsJson);
        final isKanban = isWide || view.layoutMode == 'kanban';

        final header = PageHeroHeader(
          title: view.name,
          onTitleTap: narrow ? () => showScopeSwitcherSheet(context) : null,
          trailing: _buildTrailingActions(context, l10n, view),
        );

        if (panels.isEmpty) {
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header,
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  Expanded(
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.all(AppTokens.spaceXl),
                        padding: const EdgeInsets.all(AppTokens.spaceXl),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTokens.surfaceCardDark
                              : AppTokens.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusCard,
                          ),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.dashboard_customize_outlined,
                              size: 56,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceMd),
                            Text(
                              l10n.noTasksInPanel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: AppTokens.textHeadingWeight,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceXs),
                            Text(
                              l10n.emptyCustomView,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppTokens.spaceMd),
                            FilledButton.icon(
                              onPressed: () => _openEditView(context, view),
                              icon: const Icon(Icons.tune, size: 18),
                              label: Text(l10n.editCustomView),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (isKanban) {
          // 看板模式：横向多列滚动
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header,
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceXs,
                        horizontal: AppTokens.spaceSm,
                      ),
                      child: Scrollbar(
                        controller: _horizontalScrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: panels.length,
                          itemBuilder: (context, index) {
                            final panel = panels[index];
                            return PanelColumn(
                              key: ValueKey(panel.id),
                              panel: panel,
                              isKanban: true,
                              onUpdatePanel: (updated) => _actionHandler
                                  .updatePanel(view, index, updated),
                              onDeletePanel: () =>
                                  _actionHandler.deletePanel(view, index),
                              onTaskDropped: (task, targetPanel) =>
                                  _actionHandler.handleTaskDrop(
                                    context: context,
                                    view: view,
                                    task: task,
                                    targetPanel: targetPanel,
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (panels.length == 1) {
          final panel = panels.first;
          return Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header,
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  Expanded(
                    child: PanelColumn(
                      key: ValueKey(panel.id),
                      panel: panel,
                      isKanban: false,
                      onUpdatePanel: (updated) =>
                          _actionHandler.updatePanel(view, 0, updated),
                      onDeletePanel: () => _actionHandler.deletePanel(view, 0),
                      onTaskDropped: (task, targetPanel) =>
                          _actionHandler.handleTaskDrop(
                            context: context,
                            view: view,
                            task: task,
                            targetPanel: targetPanel,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 列表模式：多 Tab 顶部切换 + 单列展示
        return DefaultTabController(
          length: panels.length,
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header,
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      isScrollable: panels.length > 3,
                      tabAlignment: panels.length > 3
                          ? TabAlignment.start
                          : TabAlignment.fill,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: panels.map((p) => _PanelTabItem(panel: p)).toList(),
                    ),
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  Expanded(
                    child: TabBarView(
                      children: panels.asMap().entries.map((entry) {
                        final index = entry.key;
                        final panel = entry.value;
                        return PanelColumn(
                          key: ValueKey(panel.id),
                          panel: panel,
                          isKanban: false,
                          onUpdatePanel: (updated) =>
                              _actionHandler.updatePanel(view, index, updated),
                          onDeletePanel: () =>
                              _actionHandler.deletePanel(view, index),
                          onTaskDropped: (task, targetPanel) =>
                              _actionHandler.handleTaskDrop(
                                context: context,
                                view: view,
                                task: task,
                                targetPanel: targetPanel,
                              ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 单个 Tab 标签项
class _PanelTabItem extends ConsumerWidget {
  const _PanelTabItem({required this.panel});

  final CustomViewPanelConfig panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(panelTasksProvider(panel)).value?.totalCount ?? 0;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(panel.title, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppTokens.spaceXs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.7,
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusChip),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppTokens.textMicroSize,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
