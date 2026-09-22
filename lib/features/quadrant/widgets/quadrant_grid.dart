import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../models/quadrant_models.dart';
import 'quadrant_card.dart';
import 'quadrant_focus_sheet.dart';

/// 四象限 2x2 田字格主体布局。
///
/// 保持经典的四象限田字矩阵结构，各象限独立承载滚动任务列表与跨象限拖拽。
/// 支持点击任意象限卡片右上角聚焦按钮打开单象限沉浸视图。
class QuadrantGrid extends StatelessWidget {
  const QuadrantGrid({super.key, required this.data});

  final QuadrantData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        AppTokens.spaceXs,
        AppTokens.spaceSm,
        AppTokens.spaceSm,
      ),
      child: Column(
        children: [
          // 第一行：Q1（重要且紧急）与 Q2（重要不紧急）
          Expanded(
            child: Row(
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
                const SizedBox(width: AppTokens.spaceSm),
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
          const SizedBox(height: AppTokens.spaceSm),

          // 第二行：Q3（紧急不重要）与 Q4（不重要不紧急）
          Expanded(
            child: Row(
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
                const SizedBox(width: AppTokens.spaceSm),
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
      ),
    );
  }
}
