import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../projects/project_providers.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import 'quadrant_task_tile.dart';

/// 聚焦单象限的全屏/半屏详情弹层。
///
/// 当用户需要沉浸式处理某一象限的任务时，可通过点击象限卡片右上角的聚焦按钮进入。
class QuadrantFocusSheet extends ConsumerWidget {
  const QuadrantFocusSheet({super.key, required this.quadrantType});

  final QuadrantType quadrantType;

  static Future<void> show(BuildContext context, QuadrantType quadrantType) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuadrantFocusSheet(quadrantType: quadrantType),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final quadrantDataAsync = ref.watch(quadrantDataProvider);
    final filter = ref.watch(quadrantFilterProvider);
    final accentColor = quadrantType.accentColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTokens.sheetTopBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTokens.alphaTintStrong),
            blurRadius: 36,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 抓手
            Container(
              width: AppTokens.sheetGrabberWidth,
              height: AppTokens.sheetGrabberHeight,
              margin: const EdgeInsets.only(
                top: AppTokens.spaceSm,
                bottom: AppTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(
                  alpha: AppTokens.alphaTintStrong,
                ),
                borderRadius: BorderRadius.circular(
                  AppTokens.sheetGrabberRadius,
                ),
              ),
            ),

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
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusMicro,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quadrantType.title(l10n),
                          style: TextStyle(
                            fontSize: AppTokens.textTitleSize,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          quadrantType.subtitle(l10n),
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
                  final tasks = data.tasksOf(quadrantType);
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

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceSm,
                      vertical: AppTokens.spaceSm,
                    ),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) =>
                        QuadrantTaskTile(taskView: tasks[index]),
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
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusButton,
                      ),
                    ),
                  ),
                  onPressed: () => _openCreateTask(context, filter),
                ),
              ),
            ),
          ],
        ),
      ),
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
      initialPriority: quadrantType.initialPriority,
      initialEndAt: quadrantType.initialEndAt(now),
    );
  }
}
