import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_tokens.dart';

/// 紧凑标签 chip（纯展示）：任务行 / 扁平行 / 编辑器已选标签共用的外观
/// （0.12 色底 + 色字 w500 + [AppTokens.radiusChip]，maxLines 1 + ellipsis）。
///
/// 无交互（display-only）；三个调用方渲染结果与改造前逐像素一致。
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Color(tag.color).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        border: Border.all(
          color: Color(tag.color).withValues(alpha: 0.22),
          width: 0.5,
        ),
      ),
      child: Text(
        tag.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: Color(tag.color),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
