import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/page_hero_header.dart';
import '../../../shared/widgets/scope_switcher_sheet.dart';
import '../providers/quadrant_providers.dart';
import '../widgets/quadrant_grid.dart';
import '../widgets/quadrant_scope_filter_sheet.dart';

/// 四象限（艾森豪威尔矩阵）主页面。
///
/// 遵循全局极简沉浸式规范与设计系统，支持右上角层级范围筛选器、
/// 2x2 响应式田字格与跨象限长按拖拽重组。
class QuadrantPage extends ConsumerWidget {
  const QuadrantPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filter = ref.watch(quadrantFilterProvider);
    final quadrantDataAsync = ref.watch(quadrantDataProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeroHeader(
              title: l10n.navQuadrant,
              onTitleTap: () => showScopeSwitcherSheet(context),
              trailing: IconButton(
                tooltip: l10n.quadrantScopeFilter,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.tune_rounded, size: 22),
                    if (filter.isCustomScoped)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => QuadrantScopeFilterSheet.show(context),
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            Expanded(
              child: quadrantDataAsync.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const LoadingView(),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (data) => QuadrantGrid(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
