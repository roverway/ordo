import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_background_wrapper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../models/quadrant_models.dart';
import 'quadrant_task_tile.dart';

/// 移动端专属：水平滑动聚焦卡视图（Quadrant Cards View）。
///
/// 遵循乔布斯极致聚焦原则：
/// 1. 全宽水平滑卡，每次滑入手指只专注于一个象限的纵深清单；
/// 2. 顶部提供 2x2 微缩矩阵动态指示器，直观展示当前聚焦位置并支持轻触直达；
/// 3. 卡片内包含该象限专属特征色徽标、策略文案、任务数以及轻量快速录入入口。
class QuadrantCardsView extends ConsumerStatefulWidget {
  const QuadrantCardsView({super.key, required this.data});

  final QuadrantData data;

  @override
  ConsumerState<QuadrantCardsView> createState() => _QuadrantCardsViewState();
}

class _QuadrantCardsViewState extends ConsumerState<QuadrantCardsView> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const List<QuadrantType> _quadrants = [
    QuadrantType.urgentImportant,
    QuadrantType.notUrgentImportant,
    QuadrantType.urgentUnimportant,
    QuadrantType.notUrgentUnimportant,
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentPage != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentPage = index);
    }
  }

  void _jumpToQuadrant(int index) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      index,
      duration: AppTokens.motionNormal,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);

    return Column(
      children: [
        // 顶部微缩 2x2 矩阵指示器 + 翻页指示
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceXs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniMatrixIndicator(),
              const SizedBox(width: AppTokens.spaceSm),
              Text(
                '${_quadrants[_currentPage].title(l10n)} · ${_quadrants[_currentPage].subtitle(l10n)}',
                style: TextStyle(
                  fontSize: AppTokens.textMicroSize,
                  fontWeight: FontWeight.w600,
                  color: _quadrants[_currentPage].accentColor,
                ),
              ),
            ],
          ),
        ),

        // 水平滑动卡片 PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _quadrants.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final type = _quadrants[index];
              final tasks = widget.data.tasksOf(type);
              return _buildQuadrantCard(
                context: context,
                type: type,
                tasks: tasks,
                isDark: isDark,
                hasWallpaper: hasWallpaper,
                colorScheme: colorScheme,
                l10n: l10n,
              );
            },
          ),
        ),
        const SizedBox(height: AppTokens.bottomNavClearance),
      ],
    );
  }

  /// 2x2 微缩矩阵动态指示器
  Widget _buildMiniMatrixIndicator() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Column(
        children: [
          Row(
            children: [
              _buildMiniMatrixCell(0),
              const SizedBox(width: 2),
              _buildMiniMatrixCell(1),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _buildMiniMatrixCell(2),
              const SizedBox(width: 2),
              _buildMiniMatrixCell(3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMatrixCell(int index) {
    final isSelected = _currentPage == index;
    final type = _quadrants[index];
    final color = type.accentColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => _jumpToQuadrant(index),
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          height: 9,
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : color.withValues(alpha: AppTokens.alphaTintStrong),
            borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            border: Border.all(
              color: isSelected
                  ? color
                  : color.withValues(alpha: AppTokens.alphaBorderSubtle),
              width: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  /// 单个象限聚焦全高卡片
  Widget _buildQuadrantCard({
    required BuildContext context,
    required QuadrantType type,
    required List<QuadrantTaskView> tasks,
    required bool isDark,
    required bool hasWallpaper,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
  }) {
    final accentColor = type.accentColor;
    final cardBg = hasWallpaper
        ? (isDark
              ? AppTokens.surfaceCardDark.withValues(
                  alpha: AppTokens.alphaCardFrostedDark,
                )
              : AppTokens.surfaceCardLight.withValues(
                  alpha: AppTokens.alphaCardFrostedLight,
                ))
        : (isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCardLight);

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXs,
        vertical: AppTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? AppTokens.alphaBorderEmphasis
                  : AppTokens.alphaTintFaint,
            ),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
        child: Column(
          children: [
            // 卡片顶栏：图标、名称、策略文案、快速新增按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.spaceMd,
                AppTokens.spaceSm,
                AppTokens.spaceSm,
                AppTokens.spaceXs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(
                        alpha: isDark
                            ? AppTokens.alphaTintStrong
                            : AppTokens.alphaBorderSubtle,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                      border: Border.all(
                        color: accentColor.withValues(
                          alpha: isDark
                              ? AppTokens.alphaBorderEmphasis
                              : AppTokens.alphaTintStrong,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(type.icon, size: 18, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              type.title(l10n),
                              style: const TextStyle(
                                fontSize: AppTokens.textBodySize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppTokens.spaceXs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(
                                  alpha: AppTokens.alphaTintFaint,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusPill,
                                ),
                              ),
                              child: Text(
                                '${tasks.length}',
                                style: TextStyle(
                                  fontSize: AppTokens.textMicroSize,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: AppTokens.fontTabular,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          type.subtitle(l10n),
                          style: TextStyle(
                            fontSize: AppTokens.textCaptionSize,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle_outline_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                    tooltip: l10n.newTask,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      TaskCreateSheet.show(
                        context,
                        initialPriority: type.initialPriority,
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),

            // 任务列表或空态
            Expanded(
              child: tasks.isEmpty
                  ? EmptyState(
                      icon: type.icon,
                      accentColor: accentColor,
                      message: l10n.quadrantEmpty,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                        vertical: AppTokens.spaceSm,
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (context, idx) {
                        final taskView = tasks[idx];
                        return QuadrantTaskTile(
                          key: ValueKey(taskView.task.id),
                          taskView: taskView,
                          showDivider: idx < tasks.length - 1,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
