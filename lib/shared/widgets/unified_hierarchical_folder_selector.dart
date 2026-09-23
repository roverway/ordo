import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/preset_icons.dart';
import 'settings_card.dart';

/// 统一层级架构下的微胶囊芯片 (32dp 高度，黑曜石深色选中态，带状态点与勾选图标)。
class HierarchicalChip extends StatelessWidget {
  const HierarchicalChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.leadingDotColor,
    required this.onTap,
    this.showCheckmark = true,
    this.height = 32.0,
  });

  final String label;
  final bool isSelected;
  final Color? leadingDotColor;
  final VoidCallback onTap;
  final bool showCheckmark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // 选中态与未选态背景与边框
    final Color bg = isSelected
        ? colorScheme.primary
        : (isDark ? AppTokens.surfaceSubtleDark : Colors.white);

    final Color border = isSelected
        ? colorScheme.primary
        : (isDark
              ? AppTokens.borderSubtleNeutralDark
              : AppTokens.slate200);

    final Color fg = isSelected
        ? colorScheme.onPrimary
        : (isDark ? AppTokens.textPrimaryDark : AppTokens.slate700);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTokens.radiusItem),
            border: Border.all(color: border, width: 0.7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: AppTokens.alphaTintStrong),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelected && showCheckmark) ...[
                Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: 5),
              ] else if (leadingDotColor != null) ...[
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: BoxDecoration(
                    color: leadingDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTokens.textCaptionSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统一层级架构单圆角矩形融合容器 (UnifiedHierarchicalFolderContainer)。
///
/// 1. 单圆角矩形容器设计：收拢合并至与设置页风格一致的 SettingsCard 圆角矩形块中。
/// 2. 极简横线分隔：区块间以细微横线区分。
/// 3. 原生丝滑折叠展开：带旋转动画 Chevron 下拉指示箭头与计数徽标。
/// 4. 头部批量「全选 / 清空」快速操作。
/// 5. 展开后内部清单直接整齐平铺流式排列 (Wrap of HierarchicalChip)。
class UnifiedHierarchicalFolderContainer extends StatefulWidget {
  const UnifiedHierarchicalFolderContainer({
    super.key,
    required this.unassignedProjects,
    required this.folders,
    required this.folderProjects,
    required this.selectedProjectIds,
    required this.onToggleProject,
    required this.onToggleGroup,
    this.unassignedTitle = '顶层与独立清单',
    this.unassignedIcon = Icons.inbox_outlined,
    this.initialExpandedFolderIds,
  });

  final List<Project> unassignedProjects;
  final List<Folder> folders;
  final Map<String, List<Project>> folderProjects;
  final Set<String> selectedProjectIds;
  final void Function(String projectId) onToggleProject;
  final void Function(List<String> projectIds, bool selectAll) onToggleGroup;
  final String unassignedTitle;
  final IconData unassignedIcon;
  final Set<String>? initialExpandedFolderIds;

  @override
  State<UnifiedHierarchicalFolderContainer> createState() =>
      _UnifiedHierarchicalFolderContainerState();
}

class _UnifiedHierarchicalFolderContainerState
    extends State<UnifiedHierarchicalFolderContainer> {
  late Set<String> _expandedIds;

  @override
  void initState() {
    super.initState();
    // 默认全部展开，保证平整通透的高效查看
    _expandedIds =
        widget.initialExpandedFolderIds ??
        {'unassigned', for (final f in widget.folders) f.id};
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dividerColor = isDark
        ? AppTokens.borderSubtleNeutralDark
        : AppTokens.slate200;

    return SettingsCard(
      padding: EdgeInsets.zero,
      children: [
        // 1. 顶层与独立清单区块 (若有)
        if (widget.unassignedProjects.isNotEmpty) ...[
          _buildGroupSection(
            id: 'unassigned',
            title: widget.unassignedTitle,
            iconData: widget.unassignedIcon,
            iconColor: isDark
                ? AppTokens.textMutedDark
                : AppTokens.slate600,
            iconBg: isDark
                ? AppTokens.surfaceSubtleDark
                : AppTokens.slate100,
            projects: widget.unassignedProjects,
          ),
          if (widget.folders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Divider(height: 1, thickness: 0.8, color: dividerColor),
            ),
        ],

        // 2. 各文件夹区块
        for (var i = 0; i < widget.folders.length; i++) ...[
          _buildFolderSection(widget.folders[i]),
          if (i < widget.folders.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Divider(height: 1, thickness: 0.8, color: dividerColor),
            ),
        ],
      ],
    );
  }

  Widget _buildFolderSection(Folder folder) {
    final projects = widget.folderProjects[folder.id] ?? const <Project>[];
    final folderColor = folder.color != null
        ? Color(folder.color!)
        : Theme.of(context).colorScheme.primary;
    final iconData = getIconDataById(
      folder.icon,
      fallback: Icons.folder_outlined,
    );

    return _buildGroupSection(
      id: folder.id,
      title: folder.name,
      iconData: iconData,
      iconColor: folderColor,
      iconBg: folderColor.withValues(alpha: AppTokens.alphaTintStrong),
      projects: projects,
    );
  }

  Widget _buildGroupSection({
    required String id,
    required String title,
    required IconData iconData,
    required Color iconColor,
    required Color iconBg,
    required List<Project> projects,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final isExpanded = _expandedIds.contains(id);
    final projectIds = projects.map((p) => p.id).toList();

    final selectedCount = projects
        .where((p) => widget.selectedProjectIds.contains(p.id))
        .length;
    final allSelected = projects.isNotEmpty && selectedCount == projects.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部行：图标、名称、计数、选中徽标、折叠指示箭头、全选/清空按钮
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _toggleExpand(id),
                  borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        // 图标微徽标 (24x24dp, 圆角 7dp)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                          ),
                          alignment: Alignment.center,
                          child: Icon(iconData, size: 14, color: iconColor),
                        ),
                        const SizedBox(width: 8),

                        // 名称
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: AppTokens.textFootnoteSize,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTokens.textPrimaryDark
                                  : AppTokens.slate800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),

                        // 项数
                        Text(
                          '(${projects.length})',
                          style: TextStyle(
                            fontSize: AppTokens.textCaptionSize,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTokens.textMutedDark
                                : AppTokens.slate400,
                          ),
                        ),

                        // 已选状态徽标
                        if (selectedCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: allSelected
                                  ? colorScheme.primary
                                  : colorScheme.primary.withValues(alpha: AppTokens.alphaTintSoft),
                              borderRadius: BorderRadius.circular(AppTokens.radiusList),
                            ),
                            child: Text(
                              allSelected
                                  ? '全选'
                                  : '$selectedCount/${projects.length}',
                              style: TextStyle(
                                fontSize: AppTokens.textNanoSize,
                                fontWeight: FontWeight.w600,
                                color: allSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(width: 4),

                        // 折叠指示箭头（带旋转微动效）
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: isExpanded ? 0.0 : -math.pi / 2,
                            end: isExpanded ? 0.0 : -math.pi / 2,
                          ),
                          duration: AppTokens.motionNormal,
                          curve: Curves.easeInOut,
                          builder: (context, angle, child) {
                            return Transform.rotate(angle: angle, child: child);
                          },
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 17,
                            color: isDark
                                ? AppTokens.textMutedDark
                                : AppTokens.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 右侧快速「全选 / 清空」操作
              InkWell(
                onTap: () {
                  widget.onToggleGroup(projectIds, !allSelected);
                },
                borderRadius: BorderRadius.circular(AppTokens.radiusXs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    allSelected ? '清空' : '全选',
                    style: TextStyle(
                      fontSize: AppTokens.textCaptionSize,
                      fontWeight: FontWeight.w600,
                      color: allSelected
                          ? (isDark
                                ? AppTokens.textMutedDark
                                : AppTokens.slate500)
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 折叠内容：平铺流式排列的微胶囊芯片
          AnimatedSize(
            duration: AppTokens.motionNormal,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded && projects.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: projects.map((p) {
                        final isSelected = widget.selectedProjectIds.contains(
                          p.id,
                        );
                        return HierarchicalChip(
                          label: p.name,
                          isSelected: isSelected,
                          leadingDotColor: Color(p.color),
                          onTap: () => widget.onToggleProject(p.id),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
