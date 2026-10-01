import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';
import '../../../shared/widgets/app_adaptive_dialog.dart';
import '../../../shared/widgets/app_frosted_container.dart';
import '../../../shared/widgets/app_modal_sheet.dart';
import '../../../shared/widgets/app_scroll_fade_wrapper.dart';
import '../../projects/project_providers.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import 'quadrant_task_tile.dart';

/// 聚焦单象限的全屏/半屏详情弹层。
///
/// 当用户需要沉浸式处理某一象限的任务时，可通过点击象限卡片右上角的聚焦按钮进入。
class QuadrantFocusSheet extends ConsumerStatefulWidget {
  const QuadrantFocusSheet({
    super.key,
    required this.quadrantType,
    this.isDialog = false,
  });

  final QuadrantType quadrantType;
  final bool isDialog;

  static Future<void> show(BuildContext context, QuadrantType quadrantType) {
    if (AppBreakpoints.isWide(context)) {
      return showAppAdaptiveDialog<void>(
        context: context,
        builder: (dialogCtx) => AppAdaptiveDialog(
          maxWidth: 680,
          padding: EdgeInsets.zero,
          child: QuadrantFocusSheet(quadrantType: quadrantType, isDialog: true),
        ),
      );
    }

    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuadrantFocusSheet(quadrantType: quadrantType),
    );
  }

  @override
  ConsumerState<QuadrantFocusSheet> createState() => _QuadrantFocusSheetState();
}

class _QuadrantFocusSheetState extends ConsumerState<QuadrantFocusSheet> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final quadrantDataAsync = ref.watch(quadrantDataProvider);
    final filter = ref.watch(quadrantFilterProvider);
    final accentColor = widget.quadrantType.accentColor;

    final isEffectiveDialog = widget.isDialog || AppBreakpoints.isWide(context);

    final bodyWidget = Container(
      constraints: BoxConstraints(
        maxHeight: isEffectiveDialog
            ? 760.0
            : MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        children: [
          // 抓手 (仅在移动端展示)
          if (!isEffectiveDialog)
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: AppTokens.sheetGrabberMiniMarginTop,
                  bottom: AppTokens.sheetGrabberMiniMarginBottom,
                ),
                width: AppTokens.sheetGrabberMiniWidth,
                height: AppTokens.sheetGrabberMiniHeight,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(
                    alpha: AppTokens.alphaTintStrong,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
              ),
            )
          else
            const SizedBox(height: AppTokens.spaceSm),

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.quadrantType.title(l10n),
                        style: TextStyle(
                          fontSize: AppTokens.textTitleSize,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        widget.quadrantType.subtitle(l10n),
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: AppTokens.alphaContentMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.cancel,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 任务列表
          Expanded(
            child: quadrantDataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text(err.toString())),
              data: (data) {
                final tasks = data.tasksOf(widget.quadrantType);
                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 36,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: AppTokens.alphaBorderEmphasis,
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXs),
                        Text(
                          l10n.quadrantEmpty,
                          style: TextStyle(
                            fontSize: AppTokens.textBodySize,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: AppTokens.alphaContentMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return AppScrollFadeWrapper(
                  scrollController: _scrollController,
                  bottomRadius: isEffectiveDialog ? AppTokens.radiusDialog : 0,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceSm,
                      vertical: AppTokens.spaceSm,
                    ),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) =>
                        QuadrantTaskTile(taskView: tasks[index]),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 底部快速添加按钮
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceSm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.quadrantAddTask),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.spaceSm,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                  ),
                ),
                onPressed: () => _openCreateTask(context, filter),
              ),
            ),
          ),
        ],
      ),
    );

    if (isEffectiveDialog) {
      return bodyWidget;
    }

    return AppFrostedContainer(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusSheet),
      ),
      child: SafeArea(top: false, child: bodyWidget),
    );
  }

  void _openCreateTask(BuildContext context, QuadrantFilterState filter) {
    final now = DateTime.now();
    final targetProjectId =
        (filter.selectedProjectIds != null &&
            filter.selectedProjectIds!.length == 1)
        ? filter.selectedProjectIds!.first
        : inboxProjectId;

    TaskCreateSheet.show(
      context,
      projectId: targetProjectId,
      initialPriority: widget.quadrantType.initialPriority,
      initialEndAt: widget.quadrantType.initialEndAt(now),
    );
  }
}
