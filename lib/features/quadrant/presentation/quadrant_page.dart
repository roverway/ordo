import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/hero_progress_ring.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_hero_header.dart';
import '../../../shared/widgets/scope_switcher_sheet.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import '../widgets/quadrant_filter_bar.dart';
import '../widgets/quadrant_grid.dart';
import '../widgets/quadrant_list_view.dart';

/// 四象限（艾森豪威尔矩阵）主页面。
///
/// 遵循全局极简沉浸式规范与设计系统：
/// 1. 顶部 Hero 大标题（带下拉指示器、任务数副标题、标准尺寸环形进度条 HeroProgressRing）；
/// 2. 工具栏 QuadrantFilterBar（左侧项目筛选胶囊 + 右侧 2x2 矩阵/聚焦列表双模式切换）；
/// 3. 支持无缝在 2x2 田字格（宏观全局）与聚焦列表（单列纵向滚动）之间平滑切换；
/// 4. 深度接入应用主题色、壁纸系统与语义令牌（零魔法值）。
class QuadrantPage extends ConsumerWidget {
  const QuadrantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    final quadrantDataAsync = ref.watch(quadrantDataProvider);
    final viewMode = ref.watch(quadrantViewModeProvider);

    final totalCount = quadrantDataAsync.asData?.value.activeTotalCount ?? 0;
    final totalAll =
        quadrantDataAsync.asData?.value.totalAllCount ?? totalCount;
    final completedCount = quadrantDataAsync.asData?.value.completedCount ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Hero 大标题区（副标题展示待办数，右侧环形完成度对齐其他页面标准尺寸）
            PageHeroHeader(
              title: l10n.navQuadrant,
              subtitle: l10n.quadrantSummarySubtitle(totalCount),
              showDropdownChevron: true,
              onTitleTap: () => showScopeSwitcherSheet(context),
              trailing: HeroProgressRing(
                completed: completedCount,
                total: totalAll,
              ),
            ),

            // 项目筛选胶囊与视图模式切换器
            QuadrantFilterBar(totalTasksCount: totalCount),
            const SizedBox(height: AppTokens.spaceMicro),

            // 矩阵 vs 列表双视图无缝切换
            Expanded(
              child: quadrantDataAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (data) => AnimatedSwitcher(
                  duration: AppTokens.motionFast,
                  switchInCurve: AppTokens.motionSpring,
                  switchOutCurve: AppTokens.motionSpring,
                  child: viewMode == QuadrantViewMode.matrix
                      ? KeyedSubtree(
                          key: const ValueKey('quadrant_matrix_view'),
                          child: QuadrantGrid(data: data),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('quadrant_list_view'),
                          child: QuadrantListView(data: data),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
