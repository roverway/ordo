import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/preset_icons.dart';
import '../project_providers.dart';

/// 模式：清单 vs 文件夹
enum CreateType { list, folder }

/// 底部弹出模态：新建/编辑清单与文件夹
Future<T?> showCreateListFolderSheet<T>({
  required BuildContext context,
  CreateType initialType = CreateType.list,
  String? initialFolderId,
  Project? editingProject,
  Folder? editingFolder,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => KeyboardInsetBuilder(
      builder: (context, keyboardHeight, bottomInset, child) => Padding(
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: CreateListFolderSheet(
          initialType: initialType,
          initialFolderId: initialFolderId,
          editingProject: editingProject,
          editingFolder: editingFolder,
        ),
      ),
    ),
  );
}

/// 快速打开「编辑清单」
Future<Project?> showEditListSheet(BuildContext context, Project project) {
  return showCreateListFolderSheet<Project>(
    context: context,
    initialType: CreateType.list,
    editingProject: project,
  );
}

/// 快速打开「编辑文件夹」
Future<Folder?> showEditFolderSheet(BuildContext context, Folder folder) {
  return showCreateListFolderSheet<Folder>(
    context: context,
    initialType: CreateType.folder,
    editingFolder: folder,
  );
}

/// 新建/编辑清单与文件夹的底部模态组件
class CreateListFolderSheet extends ConsumerStatefulWidget {
  const CreateListFolderSheet({
    super.key,
    this.initialType = CreateType.list,
    this.initialFolderId,
    this.editingProject,
    this.editingFolder,
  });

  final CreateType initialType;
  final String? initialFolderId;
  final Project? editingProject;
  final Folder? editingFolder;

  @override
  ConsumerState<CreateListFolderSheet> createState() =>
      _CreateListFolderSheetState();
}

class _CreateListFolderSheetState extends ConsumerState<CreateListFolderSheet> {
  static const int _maxNameLength = 24;

  late CreateType _createType;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  late PresetModalColor _selectedColor;
  late PresetIconCategory _selectedCategory;
  late PresetIconItem _selectedIcon;
  String? _selectedFolderId;
  bool _isSubmitting = false;

  bool get _isEditing =>
      widget.editingProject != null || widget.editingFolder != null;

  @override
  void initState() {
    super.initState();

    if (widget.editingProject != null) {
      _createType = CreateType.list;
    } else if (widget.editingFolder != null) {
      _createType = CreateType.folder;
    } else {
      _createType = widget.initialType;
    }

    final initialName =
        widget.editingProject?.name ?? widget.editingFolder?.name ?? '';
    _nameController = TextEditingController(text: initialName);
    _nameFocusNode = FocusNode();

    // 监听聚焦变化以动态全屏与避让状态栏
    _nameFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // 监听名称变化以更新完成按钮及字数统计
    _nameController.addListener(() {
      setState(() {});
    });

    // 初始化颜色
    final initialColorInt =
        widget.editingProject?.color ?? widget.editingFolder?.color;
    if (initialColorInt != null) {
      final found = kPresetModalColors.where(
        (c) => c.color.toARGB32() == initialColorInt,
      );
      _selectedColor = found.isNotEmpty ? found.first : kPresetModalColors[1];
    } else {
      _selectedColor = _createType == CreateType.list
          ? kPresetModalColors[1] // 克莱因蓝
          : kPresetModalColors[3]; // 琥珀橙
    }

    // 初始化图标
    final initialIconId =
        widget.editingProject?.icon ?? widget.editingFolder?.icon;
    final presetIcon = getPresetIconById(initialIconId);
    if (presetIcon != null) {
      _selectedIcon = presetIcon;
      // 反查 category
      PresetIconCategory? foundCat;
      for (final entry in kPresetModalIcons.entries) {
        if (entry.value.any((item) => item.id == presetIcon.id)) {
          foundCat = entry.key;
          break;
        }
      }
      _selectedCategory = foundCat ?? PresetIconCategory.common;
    } else {
      _selectedCategory = PresetIconCategory.common;
      _selectedIcon = _createType == CreateType.list
          ? kPresetModalIcons[PresetIconCategory.common]![0]
          : kPresetModalIcons[PresetIconCategory.common]![9]; // folder
    }

    _selectedFolderId =
        widget.editingProject?.folderId ?? widget.initialFolderId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _switchType(CreateType type) {
    if (_isEditing || _createType == type) return;
    setState(() {
      _createType = type;
      if (type == CreateType.folder) {
        _selectedIcon =
            kPresetModalIcons[PresetIconCategory.common]![9]; // 文件夹图标
        _selectedColor = kPresetModalColors[3]; // 琥珀橙
      } else {
        _selectedIcon =
            kPresetModalIcons[PresetIconCategory.common]![0]; // 清单图标
        _selectedColor = kPresetModalColors[1]; // 克莱因蓝
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    _nameFocusNode.unfocus();

    setState(() {
      _isSubmitting = true;
    });

    final repo = ref.read(todoRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final normalizedFolderId =
          (_selectedFolderId != null && _selectedFolderId!.trim().isNotEmpty)
          ? _selectedFolderId!.trim()
          : null;

      if (widget.editingProject != null) {
        // ── 编辑清单 ──
        final targetProject = widget.editingProject!;
        await repo.updateProject(
          targetProject.id,
          name: name,
          color: _selectedColor.color.toARGB32(),
          icon: _selectedIcon.id,
          folderId: Value(normalizedFolderId),
        );
        final updatedProject =
            (await repo.projects.getById(targetProject.id)) ?? targetProject;
        if (mounted) {
          Navigator.of(context).pop(updatedProject);
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.editListSuccess(name)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (widget.editingFolder != null) {
        // ── 编辑文件夹 ──
        final targetFolder = widget.editingFolder!;
        await repo.updateFolder(
          targetFolder.id,
          name: name,
          color: _selectedColor.color.toARGB32(),
          icon: _selectedIcon.id,
        );
        final updatedFolder =
            (await repo.folders.getById(targetFolder.id)) ?? targetFolder;
        if (mounted) {
          Navigator.of(context).pop(updatedFolder);
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.editFolderSuccess(name)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (_createType == CreateType.list) {
        // ── 新建清单 ──
        final newProject = await repo.createProject(
          name: name,
          color: _selectedColor.color.toARGB32(),
          icon: _selectedIcon.id,
          folderId: normalizedFolderId,
        );
        if (mounted) {
          Navigator.of(context).pop(newProject);
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.createListSuccess(name)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // ── 新建文件夹 ──
        final newFolder = await repo.createFolder(
          name: name,
          color: _selectedColor.color.toARGB32(),
          icon: _selectedIcon.id,
        );
        if (mounted) {
          Navigator.of(context).pop(newFolder);
          messenger?.showSnackBar(
            SnackBar(
              content: Text(l10n.createFolderSuccess(name)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final isList = _createType == CreateType.list;
    final isNameValid = _nameController.text.trim().isNotEmpty;
    final activeAccent = _selectedColor.color;
    final isFocused = _nameFocusNode.hasFocus;

    final groupingAsync = ref.watch(projectsByFolderProvider);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetMaxHeight = isFocused ? screenHeight : screenHeight * 0.85;

    // 状态栏高度真实检测：在 showModalBottomSheet 内部，MediaQuery.padding.top 会被路由剔除为 0
    // 因此优先从 MediaQuery.viewPadding.top 或 FlutterView 的 viewPadding 读取真实硬件顶栏避让高度
    final rawTopInset = MediaQuery.viewPaddingOf(context).top;
    final view = View.maybeOf(context);
    final engineTopInset = view != null
        ? (view.viewPadding.top / view.devicePixelRatio)
        : 0.0;
    final physicalTopInset = rawTopInset > 0 ? rawTopInset : engineTopInset;
    final isMobile =
        theme.platform == TargetPlatform.android ||
        theme.platform == TargetPlatform.iOS;
    final effectiveStatusBarHeight = physicalTopInset > 0
        ? physicalTopInset
        : (isMobile ? 36.0 : 0.0);

    final topClearance = isFocused ? (effectiveStatusBarHeight + 10.0) : 0.0;

    return AnimatedContainer(
      duration: AppTokens.motionFast,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        // 聚焦后全屏，非聚焦时对齐导航弹窗（0.85）
        maxHeight: targetMaxHeight,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfacePageDark : AppTokens.surfacePageLight,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isFocused ? 16 : 24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTokens.alphaBorderEmphasis),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 顶部状态栏安全距离（聚焦全屏时生效） ──
          if (isFocused)
            SizedBox(height: topClearance)
          else
            // ── 拖拽手柄（非全屏时显示） ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: AppTokens.alphaContentDisabled),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
                ),
              ),
            ),

          // ── 顶栏导航 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 左侧取消
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusList),
                    ),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // 中间：分段切换器（新建模式）或 标题（编辑模式）
                if (_isEditing)
                  Text(
                    widget.editingProject != null
                        ? l10n.editList
                        : l10n.editFolder,
                    style: TextStyle(
                      fontSize: AppTokens.textSubtitleSize,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTokens.textPrimaryDark : AppTokens.textPrimaryLight,
                    ),
                  )
                else
                  _buildSegmentedControl(l10n, isDark),

                // 右侧完成
                TextButton(
                  onPressed: isNameValid && !_isSubmitting ? _submit : null,
                  style: TextButton.styleFrom(
                    foregroundColor: activeAccent,
                    disabledForegroundColor: isDark ? AppTokens.checkboxDisabledBorderDark : AppTokens.checkboxDisabledBorderLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: isNameValid
                        ? activeAccent.withValues(alpha: AppTokens.alphaBorderSubtle)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: activeAccent,
                          ),
                        )
                      : Text(
                          l10n.done,
                          style: TextStyle(
                            fontSize: AppTokens.textBodySize,
                            fontWeight: isNameValid
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // ── 可滚动表单区域 ──
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 名称与图标前缀输入卡片
                  _buildNameInputCard(l10n, isDark, activeAccent, isList),

                  const SizedBox(height: 24),

                  // 2. 主题颜色选择
                  _buildColorPalette(l10n, isDark),

                  const SizedBox(height: 24),

                  // 3. 图标库选择
                  _buildIconPicker(l10n, isDark, activeAccent),

                  // 4. 所属文件夹（仅在清单模式展示）
                  if (isList) ...[
                    const SizedBox(height: 24),
                    _buildFolderSelector(
                      l10n,
                      isDark,
                      activeAccent,
                      groupingAsync,
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部分段切换器
  Widget _buildSegmentedControl(AppLocalizations l10n, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceSubtleDark : AppTokens.surfaceSubtleLight,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentItem(
            label: l10n.createList,
            type: CreateType.list,
            isSelected: _createType == CreateType.list,
            isDark: isDark,
          ),
          _buildSegmentItem(
            label: l10n.createFolder,
            type: CreateType.folder,
            isSelected: _createType == CreateType.folder,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem({
    required String label,
    required CreateType type,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _switchType(type),
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTokens.borderSubtleNeutralDark : AppTokens.surfaceDialogLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTokens.textFootnoteSize,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? AppTokens.textPrimaryDark : AppTokens.textPrimaryLight)
                : (isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight),
          ),
        ),
      ),
    );
  }

  /// 1. 名称与图标前缀输入卡片（按需编辑，聚焦无边框，仅光标闪烁）
  Widget _buildNameInputCard(
    AppLocalizations l10n,
    bool isDark,
    Color activeAccent,
    bool isList,
  ) {
    final name = _nameController.text;
    final labelTitle = isList ? l10n.listName : l10n.folderName;
    final hintTitle = isList ? l10n.listNameHint : l10n.folderNameHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              labelTitle.toUpperCase(),
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isDark ? AppTokens.checkboxDisabledFgDark : AppTokens.checkboxDisabledFgLight,
              ),
            ),
            Text(
              '${name.length}/$_maxNameLength',
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontFeatures: AppTokens.fontTabular,
                color: isDark
                    ? AppTokens.checkboxDisabledFgDark
                    : AppTokens.checkboxDisabledFgLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTokens.surfaceSubtleDark : AppTokens.borderSubtleNeutralLight,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              // 选中的图标与色彩预览徽章
              AnimatedContainer(
                duration: AppTokens.motionFast,
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activeAccent,
                  borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                  boxShadow: [
                    BoxShadow(
                      color: activeAccent.withValues(alpha: AppTokens.alphaBorderEmphasis),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _selectedIcon.icon,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 输入框：无任何背景色，保留浅色下边距横线
              Expanded(
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: false,
                  maxLength: _maxNameLength,
                  cursorColor: activeAccent,
                  cursorWidth: 2.0,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                  style: TextStyle(
                    fontSize: AppTokens.textSubtitleSize,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTokens.textPrimaryDark : AppTokens.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: hintTitle,
                    hintStyle: TextStyle(
                      fontSize: AppTokens.textSubtitleSize,
                      fontWeight: FontWeight.w400,
                      color: isDark ? AppTokens.checkboxDisabledBorderDark : AppTokens.checkboxDisabledFgLight,
                    ),
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
              ),

              // 清除按钮
              if (name.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _nameController.clear();
                    _nameFocusNode.requestFocus();
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDark ? AppTokens.borderSubtleNeutralDark : AppTokens.checkboxDisabledBorderLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. 主题颜色选择调色板
  Widget _buildColorPalette(AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.modalThemeColor.toUpperCase(),
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isDark ? AppTokens.checkboxDisabledFgDark : AppTokens.checkboxDisabledFgLight,
              ),
            ),
            Text(
              _selectedColor.localizedName(context),
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: FontWeight.w500,
                color: _selectedColor.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: kPresetModalColors.map((item) {
            final isSelected = _selectedColor.id == item.id;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = item;
                });
              },
              child: AnimatedContainer(
                duration: AppTokens.motionFast,
                curve: Curves.easeOutCubic,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: AppTokens.alphaContentDisabled),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: isSelected
                      ? Border.all(
                          color: isDark ? AppTokens.surfaceDark : Colors.white,
                          width: 2.5,
                        )
                      : null,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 3. 图标库选择
  Widget _buildIconPicker(
    AppLocalizations l10n,
    bool isDark,
    Color activeAccent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.selectIcon.toUpperCase(),
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isDark ? AppTokens.checkboxDisabledFgDark : AppTokens.checkboxDisabledFgLight,
              ),
            ),
            Text(
              l10n.instantApply,
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                color: isDark ? AppTokens.checkboxDisabledFgDark : AppTokens.checkboxDisabledFgLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 分类横向切换胶囊
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: PresetIconCategory.values.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  child: AnimatedContainer(
                    duration: AppTokens.motionFast,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeAccent
                          : (isDark
                              ? AppTokens.surfaceSubtleDark
                              : AppTokens.surfaceSubtleLight),
                      borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                    ),
                    child: Text(
                      _getCategoryName(cat, l10n),
                      style: TextStyle(
                        fontSize: AppTokens.textFootnoteSize,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? AppTokens.textMutedDark
                                : AppTokens.textMutedLight),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // 候选图标卡片（对齐设置页卡片视觉外观）
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCardLight,
            borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: AppTokens.alphaTintFaint)
                  : Colors.black.withValues(alpha: AppTokens.alphaTintFaint),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final icons = kPresetModalIcons[_selectedCategory] ?? [];
              const int columns = 6;
              final double itemWidth =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: icons.map((item) {
                  final isSelected = _selectedIcon.id == item.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = item;
                      });
                    },
                    child: AnimatedContainer(
                      duration: AppTokens.motionFast,
                      curve: Curves.easeOutCubic,
                      width: itemWidth,
                      height: itemWidth,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeAccent.withValues(alpha: AppTokens.alphaTintStrong)
                            : (isDark
                                ? AppTokens.surfaceSubtleDark
                                : AppTokens.surfaceLight),
                        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                        border: Border.all(
                          color: isSelected
                              ? activeAccent
                              : (isDark
                                  ? AppTokens.borderSubtleNeutralDark
                                  : AppTokens.borderSubtleNeutralLight),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: isSelected
                              ? activeAccent
                              : (isDark
                                  ? AppTokens.checkboxDisabledBorderLight
                                  : AppTokens.checkboxDisabledBorderDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getCategoryName(PresetIconCategory cat, AppLocalizations l10n) {
    switch (cat) {
      case PresetIconCategory.common:
        return l10n.catCommon;
      case PresetIconCategory.work:
        return l10n.catWork;
      case PresetIconCategory.life:
        return l10n.catLife;
      case PresetIconCategory.study:
        return l10n.catStudy;
      case PresetIconCategory.health:
        return l10n.catHealth;
      case PresetIconCategory.finance:
        return l10n.catFinance;
    }
  }

  /// 4. 所属文件夹单选器（仅清单模式）
  Widget _buildFolderSelector(
    AppLocalizations l10n,
    bool isDark,
    Color activeAccent,
    AsyncValue<ProjectGrouping> groupingAsync,
  ) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: AppTokens.alphaTintFaint)
        : Colors.black.withValues(alpha: AppTokens.alphaTintFaint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.belongingFolder.toUpperCase(),
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: isDark ? AppTokens.checkboxDisabledFgDark : AppTokens.checkboxDisabledFgLight,
              ),
            ),
            Text(
              l10n.singleChoiceBelonging,
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                color: isDark ? AppTokens.checkboxDisabledFgDark : AppTokens.checkboxDisabledFgLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCardLight,
            borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
            child: groupingAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  err.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (grouping) {
                final folders = grouping.folders;
                return Column(
                  children: [
                    // 顶层选项：无（顶层清单）
                    _buildFolderOptionTile(
                      id: null,
                      name: l10n.noFolderRoot,
                      icon: Icons.layers_outlined,
                      isSelected: _selectedFolderId == null,
                      isDark: isDark,
                      activeAccent: activeAccent,
                      l10n: l10n,
                    ),

                    // 已有文件夹列表
                    for (int i = 0; i < folders.length; i++) ...[
                      Divider(height: 1, thickness: 0.5, color: borderColor),
                      _buildFolderOptionTile(
                        id: folders[i].id,
                        name: folders[i].name,
                        icon: getIconDataById(
                          folders[i].icon,
                          fallback: Icons.folder_outlined,
                        ),
                        folderColor: folders[i].color != null
                            ? Color(folders[i].color!)
                            : null,
                        count: grouping.countInFolder(folders[i].id),
                        isSelected: _selectedFolderId == folders[i].id,
                        isDark: isDark,
                        activeAccent: activeAccent,
                        l10n: l10n,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderOptionTile({
    required String? id,
    required String name,
    required IconData icon,
    Color? folderColor,
    int? count,
    required bool isSelected,
    required bool isDark,
    required Color activeAccent,
    required AppLocalizations l10n,
  }) {
    final iconColor =
        folderColor ??
        (isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight);
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFolderId = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isSelected
            ? activeAccent.withValues(alpha: AppTokens.alphaTintFaint)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: AppTokens.textSecondarySize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isDark
                      ? AppTokens.textPrimaryDark
                      : AppTokens.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null) ...[
              Text(
                l10n.listsCount(count),
                style: TextStyle(
                  fontSize: AppTokens.textCaptionSize,
                  fontFeatures: AppTokens.fontTabular,
                  color: isDark
                      ? AppTokens.textMutedLight
                      : AppTokens.textMutedDark,
                ),
              ),
              const SizedBox(width: 8),
            ],
            AnimatedOpacity(
              duration: AppTokens.motionFast,
              opacity: isSelected ? 1.0 : 0.0,
              child: Icon(Icons.check_rounded, size: 18, color: activeAccent),
            ),
          ],
        ),
      ),
    );
  }
}
