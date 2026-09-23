import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_background_wrapper.dart';
import '../models/quadrant_models.dart';
import 'quadrant_card.dart';
import 'quadrant_focus_sheet.dart';

/// 四象限 2x2 矩阵网格主体布局。
///
/// 视觉规范：
/// 1. 将原本四个分离的圆角矩形合并为一个统一的大圆角容器（带自适应壁纸毛玻璃与柔和投影）；
/// 2. 在屏幕中心用两条正交相交的细直线（水平与垂直分割线）划分出四个象限（Q1/Q2/Q3/Q4）；
/// 3. 四个象限内部去卡片化，各象限独立承载滚动任务列表与跨象限拖拽放置；
/// 4. 支持点击任意象限卡片右上角聚焦按钮打开单象限沉浸视图。
class QuadrantGrid extends StatelessWidget {
  const QuadrantGrid({super.key, required this.data});

  final QuadrantData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);

    final baseCardColor = isDark
        ? AppTokens.surfaceCardDark
        : AppTokens.surfaceCard;
    final cardColor = hasWallpaper
        ? baseCardColor.withValues(
            alpha: isDark
                ? AppTokens.alphaCardFrostedDark
                : AppTokens.alphaCardFrostedLight,
          )
        : baseCardColor;

    final defaultBorderColor = isDark
        ? Colors.white.withValues(
            alpha: hasWallpaper
                ? AppTokens.alphaTintStrong
                : AppTokens.alphaTintFaint,
          )
        : (hasWallpaper
              ? Colors.black.withValues(alpha: AppTokens.alphaTintSoft)
              : AppTokens.borderSubtleNeutralLight);

    final crossLineColor = isDark
        ? Colors.white.withValues(
            alpha: hasWallpaper
                ? AppTokens.alphaTintStrong
                : AppTokens.alphaBorderSubtle,
          )
        : (hasWallpaper
              ? Colors.black.withValues(alpha: AppTokens.alphaTintSoft)
              : AppTokens.borderSubtleNeutralLight);

    const double crossLineWidth = 0.8;

    final gridContent = Column(
      children: [
        // 第一行：Q1（重要且紧急）与 Q2（重要不紧急）
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: QuadrantCard(
                  quadrantType: QuadrantType.urgentImportant,
                  tasks: data.tasksOf(QuadrantType.urgentImportant),
                  onFocus: () => QuadrantFocusSheet.show(
                    context,
                    QuadrantType.urgentImportant,
                  ),
                ),
              ),
              Container(width: crossLineWidth, color: crossLineColor),
              Expanded(
                child: QuadrantCard(
                  quadrantType: QuadrantType.notUrgentImportant,
                  tasks: data.tasksOf(QuadrantType.notUrgentImportant),
                  onFocus: () => QuadrantFocusSheet.show(
                    context,
                    QuadrantType.notUrgentImportant,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 屏幕中心水平分割直线
        Container(height: crossLineWidth, color: crossLineColor),

        // 第二行：Q3（紧急不重要）与 Q4（不重要不紧急）
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: QuadrantCard(
                  quadrantType: QuadrantType.urgentUnimportant,
                  tasks: data.tasksOf(QuadrantType.urgentUnimportant),
                  onFocus: () => QuadrantFocusSheet.show(
                    context,
                    QuadrantType.urgentUnimportant,
                  ),
                ),
              ),
              Container(width: crossLineWidth, color: crossLineColor),
              Expanded(
                child: QuadrantCard(
                  quadrantType: QuadrantType.notUrgentUnimportant,
                  tasks: data.tasksOf(QuadrantType.notUrgentUnimportant),
                  onFocus: () => QuadrantFocusSheet.show(
                    context,
                    QuadrantType.notUrgentUnimportant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        0,
        AppTokens.spaceSm,
        AppTokens.spaceSm,
      ),
      child: hasWallpaper
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark
                          ? AppTokens.alphaBorderEmphasis
                          : AppTokens.alphaTintFaint,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: AppTokens.blurFrostedGlass,
                    sigmaY: AppTokens.blurFrostedGlass,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusDialog,
                      ),
                      border: Border.all(color: defaultBorderColor, width: 0.8),
                    ),
                    child: gridContent,
                  ),
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                border: Border.all(color: defaultBorderColor, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark
                          ? AppTokens.alphaBorderEmphasis
                          : AppTokens.alphaTintFaint,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                child: gridContent,
              ),
            ),
    );
  }
}
