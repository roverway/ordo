// 搜索页（FR-VIEW-05 / FR-VIEW-06，M3）。
//
// 遵循 Linear 风格极致工业质感与乔布斯无冗余交互哲学：
// - 极简紧凑的微发光搜索输入条，左侧集成触觉反馈返回键，移除了冗余的取消按钮；
// - 输入框与占位文本绝对垂直居中（零魔法值，纯净度量对齐）；
// - 输入即搜：防抖 300ms（searchQueryProvider），按标题/描述/备注匹配；
// - 结果卡片采用 Linear 纯净无杂质列表，支持微交互滑动与状态标记；
// - 空搜索态优雅陈列「最近搜索」历史胶囊，支持轻触快速重填与一键清空。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../../shared/widgets/task_filter_bar.dart';
import '../projects/project_providers.dart';
import '../tags/tag_providers.dart';
import '../tasks/task_edit_page.dart';
import '../tasks/widgets/task_swipe_wrapper.dart';
import 'search_providers.dart';

/// Linear 风格全局搜索页。
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _queryController;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).add(query.trim());
    }
  }

  void _selectHistory(String keyword) {
    HapticFeedback.selectionClick();
    _queryController.text = keyword;
    _queryController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
    ref.read(searchQueryProvider.notifier).setImmediate(keyword);
    ref.read(searchHistoryProvider.notifier).add(keyword);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final resultsAsync = ref.watch(searchResultsProvider);
    final allAsync = ref.watch(allActiveTasksProvider);
    final filter = ref.watch(searchFilterProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final history = ref.watch(searchHistoryProvider);
    final query = ref.watch(searchQueryProvider);

    final inputBg = isDark
        ? AppTokens.surfaceCardDark.withValues(
            alpha: AppTokens.alphaCardFrostedDark,
          )
        : AppTokens.surfaceCardLight.withValues(
            alpha: AppTokens.alphaCardFrostedLight,
          );

    final borderColor = _isFocused
        ? colorScheme.primary.withValues(alpha: AppTokens.alphaBorderEmphasis)
        : (isDark ? AppTokens.borderSubtleDark : AppTokens.borderSubtleLight);

    return Scaffold(
      backgroundColor: isDark ? AppTokens.surfaceDark : AppTokens.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // Linear 风格沉浸式搜索顶栏（左侧返回 + 居中搜索框，去除了冗余取消按钮）
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppTokens.motionFast,
                      height: AppTokens.searchBarHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusPill,
                        ),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: _isFocused
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: AppTokens.alphaTintStrong,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color: _isFocused
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppTokens.spaceXs),
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              focusNode: _focusNode,
                              autofocus: true,
                              textAlignVertical: TextAlignVertical.center,
                              textInputAction: TextInputAction.search,
                              onSubmitted: _onSearchSubmitted,
                              onChanged: (value) {
                                ref
                                    .read(searchQueryProvider.notifier)
                                    .onQueryChanged(value);
                                setState(() {});
                              },
                              style: TextStyle(
                                fontSize: AppTokens.textSecondarySize,
                                color: colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: l10n.searchHint,
                                hintStyle: TextStyle(
                                  fontSize: AppTokens.textSecondarySize,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(
                                        alpha: AppTokens.alphaContentMuted,
                                      ),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_queryController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () {
                                _queryController.clear();
                                ref
                                    .read(searchQueryProvider.notifier)
                                    .setImmediate('');
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 属性筛选条
            TaskFilterBar(
              status: filter.status,
              tagId: filter.tagId,
              range: filter.range,
              tags: tagsAsync.value ?? const [],
              onStatusChanged: (status) =>
                  ref.read(searchFilterProvider.notifier).setStatus(status),
              onTagChanged: (tagId) =>
                  ref.read(searchFilterProvider.notifier).setTagId(tagId),
              onTimeRangeChanged: (range) =>
                  ref.read(searchFilterProvider.notifier).setTimeRange(range),
              onClear: () => ref.read(searchFilterProvider.notifier).clear(),
            ),

            // 搜索结果列表或空态历史记录
            Expanded(
              child: query.trim().isEmpty
                  ? _buildEmptyOrHistory(context, l10n, history)
                  : resultsAsync.when(
                      data: (results) => _buildResults(
                        context,
                        l10n,
                        results,
                        allAsync.value ?? const <Task>[],
                      ),
                      loading: () => const LoadingView(),
                      error: (e, st) {
                        logAsyncError(e, st);
                        return ErrorView(
                          onRetry: () => ref.invalidate(searchResultsProvider),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空搜索态：展示「最近搜索」历史标签与一键清除
  Widget _buildEmptyOrHistory(
    BuildContext context,
    AppLocalizations l10n,
    List<String> history,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (history.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        accentColor: colorScheme.primary,
        message: l10n.searchHint,
      );
    }

    final chipBg = isDark
        ? AppTokens.surfaceCardDark.withValues(
            alpha: AppTokens.alphaCardFrostedDark,
          )
        : AppTokens.surfaceCardLight.withValues(
            alpha: AppTokens.alphaCardFrostedLight,
          );

    final chipBorder = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.localeName == 'zh' ? '最近搜索' : 'Recent Searches',
                style: TextStyle(
                  fontSize: AppTokens.textSectionLabelSize,
                  fontWeight: AppTokens.textSectionLabelWeight,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(searchHistoryProvider.notifier).clear();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceXs,
                    vertical: AppTokens.spaceMicro,
                  ),
                  child: Text(
                    l10n.localeName == 'zh' ? '清空' : 'Clear',
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceXs,
            runSpacing: AppTokens.spaceXs,
            children: [
              for (final keyword in history)
                InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  onTap: () => _selectHistory(keyword),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceSm,
                      vertical: AppTokens.spaceXxs,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      border: Border.all(color: chipBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 13,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: AppTokens.alphaContentMuted,
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceXxs),
                        Text(
                          keyword,
                          style: TextStyle(
                            fontSize: AppTokens.textFootnoteSize,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AppLocalizations l10n,
    List<Task> results,
    List<Task> allTasks,
  ) {
    if (results.isEmpty) {
      return EmptyState(icon: Icons.search_off, message: l10n.emptySearch);
    }

    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final projectsMap = {for (final p in projects) p.id: p};

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceSm,
        AppTokens.spaceMd,
        AppTokens.bottomNavClearance,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final task = results[index];
        final isDone = task.status == TaskStatus.done;
        final project = projectsMap[task.projectId];

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
          child: TaskSwipeWrapper(
            task: task,
            hasChildren: false,
            isDone: isDone,
            child: SimpleTaskTile(
              task: task,
              hasChildren: false,
              isDone: isDone,
              projectName: project?.name,
              projectColor: project?.color,
              onTap: () => openTaskEdit(context, taskId: task.id),
              onToggleDone: (done) {
                ref
                    .read(todoRepositoryProvider)
                    .updateTask(
                      task.id,
                      status: (done ?? false)
                          ? TaskStatus.done
                          : TaskStatus.todo,
                    );
              },
            ),
          ),
        );
      },
    );
  }
}
