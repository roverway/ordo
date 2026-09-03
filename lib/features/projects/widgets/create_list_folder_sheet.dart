import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../project_providers.dart';

/// 创建模式：新建清单 vs 新建文件夹
enum CreateType { list, folder }

/// 图标分类
enum PresetIconCategory { common, work, life, study, health, finance }

/// 预设图标项
class PresetIconItem {
  const PresetIconItem({
    required this.id,
    required this.icon,
    required this.nameZh,
    required this.nameEn,
  });

  final String id;
  final IconData icon;
  final String nameZh;
  final String nameEn;
}

/// 预设主题色
class PresetModalColor {
  const PresetModalColor({
    required this.id,
    required this.color,
    required this.nameZh,
    required this.nameEn,
  });

  final String id;
  final Color color;
  final String nameZh;
  final String nameEn;

  String localizedName(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return isZh ? nameZh : nameEn;
  }
}

/// 8 款精选主题色（与原型完全一致）
const List<PresetModalColor> kPresetModalColors = [
  PresetModalColor(
    id: 'black',
    color: Color(0xFF111827),
    nameZh: '曜石黑',
    nameEn: 'Obsidian Black',
  ),
  PresetModalColor(
    id: 'blue',
    color: Color(0xFF2563EB),
    nameZh: '克莱因蓝',
    nameEn: 'Klein Blue',
  ),
  PresetModalColor(
    id: 'emerald',
    color: Color(0xFF059669),
    nameZh: '翡翠绿',
    nameEn: 'Emerald Green',
  ),
  PresetModalColor(
    id: 'amber',
    color: Color(0xFFD97706),
    nameZh: '琥珀橙',
    nameEn: 'Amber Orange',
  ),
  PresetModalColor(
    id: 'purple',
    color: Color(0xFF7C3AED),
    nameZh: '罗兰紫',
    nameEn: 'Violet Purple',
  ),
  PresetModalColor(
    id: 'rose',
    color: Color(0xFFE11D48),
    nameZh: '玫瑰红',
    nameEn: 'Rose Red',
  ),
  PresetModalColor(
    id: 'teal',
    color: Color(0xFF0891B2),
    nameZh: '松石青',
    nameEn: 'Turquoise Teal',
  ),
  PresetModalColor(
    id: 'slate',
    color: Color(0xFF64748B),
    nameZh: '烟雨灰',
    nameEn: 'Misty Slate',
  ),
];

/// 6 大分类矢量图标库（与原型完全一致）
const Map<PresetIconCategory, List<PresetIconItem>> kPresetModalIcons = {
  PresetIconCategory.common: [
    PresetIconItem(
      id: 'list',
      icon: Icons.format_list_bulleted_rounded,
      nameZh: '清单',
      nameEn: 'List',
    ),
    PresetIconItem(
      id: 'check-square',
      icon: Icons.check_box_outlined,
      nameZh: '待办',
      nameEn: 'Todo',
    ),
    PresetIconItem(
      id: 'star',
      icon: Icons.star_outline_rounded,
      nameZh: '重要',
      nameEn: 'Star',
    ),
    PresetIconItem(
      id: 'flag',
      icon: Icons.flag_outlined,
      nameZh: '旗帜',
      nameEn: 'Flag',
    ),
    PresetIconItem(
      id: 'clock',
      icon: Icons.schedule_rounded,
      nameZh: '提醒',
      nameEn: 'Reminder',
    ),
    PresetIconItem(
      id: 'calendar',
      icon: Icons.calendar_today_rounded,
      nameZh: '日程',
      nameEn: 'Calendar',
    ),
    PresetIconItem(
      id: 'tag',
      icon: Icons.label_outline_rounded,
      nameZh: '标签',
      nameEn: 'Tag',
    ),
    PresetIconItem(
      id: 'bell',
      icon: Icons.notifications_none_rounded,
      nameZh: '通知',
      nameEn: 'Notification',
    ),
    PresetIconItem(
      id: 'inbox',
      icon: Icons.inbox_rounded,
      nameZh: '收集箱',
      nameEn: 'Inbox',
    ),
    PresetIconItem(
      id: 'folder',
      icon: Icons.folder_outlined,
      nameZh: '文件夹',
      nameEn: 'Folder',
    ),
    PresetIconItem(
      id: 'archive',
      icon: Icons.archive_outlined,
      nameZh: '归档',
      nameEn: 'Archive',
    ),
    PresetIconItem(
      id: 'sparkles',
      icon: Icons.auto_awesome_outlined,
      nameZh: '想法',
      nameEn: 'Idea',
    ),
  ],
  PresetIconCategory.work: [
    PresetIconItem(
      id: 'briefcase',
      icon: Icons.work_outline_rounded,
      nameZh: '办公',
      nameEn: 'Work',
    ),
    PresetIconItem(
      id: 'laptop',
      icon: Icons.laptop_mac_rounded,
      nameZh: '电脑',
      nameEn: 'Laptop',
    ),
    PresetIconItem(
      id: 'file-text',
      icon: Icons.description_outlined,
      nameZh: '文档',
      nameEn: 'Document',
    ),
    PresetIconItem(
      id: 'users',
      icon: Icons.group_outlined,
      nameZh: '团队',
      nameEn: 'Team',
    ),
    PresetIconItem(
      id: 'mail',
      icon: Icons.mail_outline_rounded,
      nameZh: '邮件',
      nameEn: 'Mail',
    ),
    PresetIconItem(
      id: 'rocket',
      icon: Icons.rocket_launch_outlined,
      nameZh: '项目',
      nameEn: 'Rocket',
    ),
  ],
  PresetIconCategory.life: [
    PresetIconItem(
      id: 'home',
      icon: Icons.home_outlined,
      nameZh: '居家',
      nameEn: 'Home',
    ),
    PresetIconItem(
      id: 'shopping-cart',
      icon: Icons.shopping_cart_outlined,
      nameZh: '购物',
      nameEn: 'Shopping',
    ),
    PresetIconItem(
      id: 'coffee',
      icon: Icons.local_cafe_outlined,
      nameZh: '休闲',
      nameEn: 'Coffee',
    ),
    PresetIconItem(
      id: 'utensils',
      icon: Icons.restaurant_rounded,
      nameZh: '美食',
      nameEn: 'Food',
    ),
    PresetIconItem(
      id: 'gift',
      icon: Icons.card_giftcard_rounded,
      nameZh: '心愿',
      nameEn: 'Gift',
    ),
    PresetIconItem(
      id: 'music',
      icon: Icons.music_note_rounded,
      nameZh: '娱乐',
      nameEn: 'Music',
    ),
  ],
  PresetIconCategory.study: [
    PresetIconItem(
      id: 'book-open',
      icon: Icons.menu_book_rounded,
      nameZh: '阅读',
      nameEn: 'Reading',
    ),
    PresetIconItem(
      id: 'graduation-cap',
      icon: Icons.school_outlined,
      nameZh: '课程',
      nameEn: 'Course',
    ),
    PresetIconItem(
      id: 'edit-3',
      icon: Icons.edit_note_rounded,
      nameZh: '笔记',
      nameEn: 'Notes',
    ),
    PresetIconItem(
      id: 'lightbulb',
      icon: Icons.lightbulb_outline_rounded,
      nameZh: '灵感',
      nameEn: 'Idea',
    ),
    PresetIconItem(
      id: 'search',
      icon: Icons.search_rounded,
      nameZh: '探索',
      nameEn: 'Explore',
    ),
    PresetIconItem(
      id: 'trophy',
      icon: Icons.emoji_events_outlined,
      nameZh: '目标',
      nameEn: 'Goal',
    ),
  ],
  PresetIconCategory.health: [
    PresetIconItem(
      id: 'heart',
      icon: Icons.favorite_border_rounded,
      nameZh: '健康',
      nameEn: 'Health',
    ),
    PresetIconItem(
      id: 'activity',
      icon: Icons.fitness_center_rounded,
      nameZh: '运动',
      nameEn: 'Exercise',
    ),
    PresetIconItem(
      id: 'droplet',
      icon: Icons.water_drop_outlined,
      nameZh: '喝水',
      nameEn: 'Water',
    ),
    PresetIconItem(
      id: 'moon',
      icon: Icons.bedtime_outlined,
      nameZh: '睡眠',
      nameEn: 'Sleep',
    ),
    PresetIconItem(
      id: 'shield',
      icon: Icons.shield_outlined,
      nameZh: '防护',
      nameEn: 'Shield',
    ),
    PresetIconItem(
      id: 'smile',
      icon: Icons.sentiment_satisfied_alt_rounded,
      nameZh: '心情',
      nameEn: 'Mood',
    ),
  ],
  PresetIconCategory.finance: [
    PresetIconItem(
      id: 'wallet',
      icon: Icons.account_balance_wallet_outlined,
      nameZh: '钱包',
      nameEn: 'Wallet',
    ),
    PresetIconItem(
      id: 'credit-card',
      icon: Icons.credit_card_rounded,
      nameZh: '卡片',
      nameEn: 'Card',
    ),
    PresetIconItem(
      id: 'dollar-sign',
      icon: Icons.attach_money_rounded,
      nameZh: '账单',
      nameEn: 'Bill',
    ),
    PresetIconItem(
      id: 'trending-up',
      icon: Icons.trending_up_rounded,
      nameZh: '理财',
      nameEn: 'Finance',
    ),
    PresetIconItem(
      id: 'receipt',
      icon: Icons.receipt_long_outlined,
      nameZh: '发票',
      nameEn: 'Receipt',
    ),
    PresetIconItem(
      id: 'shopping-bag',
      icon: Icons.shopping_bag_outlined,
      nameZh: '支出',
      nameEn: 'Expense',
    ),
  ],
};

/// 呼出移动端新建清单与新建文件夹抽屉模态
Future<T?> showCreateListFolderSheet<T>({
  required BuildContext context,
  CreateType initialType = CreateType.list,
  String? initialFolderId,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => KeyboardInsetBuilder(
      child: RepaintBoundary(
        child: CreateListFolderSheet(
          initialType: initialType,
          initialFolderId: initialFolderId,
        ),
      ),
      builder: (context, effectiveInset, _, child) => Padding(
        padding: EdgeInsets.only(bottom: effectiveInset),
        child: child!,
      ),
    ),
  );
}

/// 移动端新建清单与新建文件夹底部抽屉模态（对齐原型 mobile-create-list-folder-modal-2-2.html）
class CreateListFolderSheet extends ConsumerStatefulWidget {
  const CreateListFolderSheet({
    super.key,
    this.initialType = CreateType.list,
    this.initialFolderId,
  });

  final CreateType initialType;
  final String? initialFolderId;

  @override
  ConsumerState<CreateListFolderSheet> createState() =>
      _CreateListFolderSheetState();
}

class _CreateListFolderSheetState extends ConsumerState<CreateListFolderSheet> {
  late CreateType _createType;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  late PresetModalColor _selectedColor;
  late PresetIconItem _selectedIcon;
  PresetIconCategory _selectedCategory = PresetIconCategory.common;
  String? _selectedFolderId; // null = 无 (顶层清单)

  static const int _maxNameLength = 24;

  @override
  void initState() {
    super.initState();
    _createType = widget.initialType;
    _selectedFolderId = widget.initialFolderId;
    _nameController = TextEditingController();
    _nameFocusNode = FocusNode();

    _selectedColor = kPresetModalColors.first;
    if (_createType == CreateType.folder) {
      _selectedIcon = kPresetModalIcons[PresetIconCategory.common]!.firstWhere(
        (i) => i.id == 'folder',
      );
    } else {
      _selectedIcon = kPresetModalIcons[PresetIconCategory.common]!.first;
    }

    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _switchCreateType(CreateType type) {
    if (_createType == type) return;
    setState(() {
      _createType = type;
      if (type == CreateType.folder) {
        if (_selectedIcon.id == 'list') {
          _selectedIcon = kPresetModalIcons[PresetIconCategory.common]!
              .firstWhere((i) => i.id == 'folder');
        }
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final repo = ref.read(todoRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final isList = _createType == CreateType.list;

    try {
      dynamic createdItem;
      if (isList) {
        createdItem = await repo.createProject(
          name: name,
          color: _selectedColor.color.toARGB32(),
          folderId: _selectedFolderId,
        );
      } else {
        createdItem = await repo.createFolder(name: name);
      }

      if (mounted) {
        Navigator.of(context).pop(createdItem);
        final message = isList
            ? l10n.createListSuccess(name)
            : l10n.createFolderSuccess(name);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppTokens.colorDone,
                  size: 20,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

    final groupingAsync = ref.watch(projectsByFolderProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191D) : const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 拖拽手柄 ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // ── 抽屉顶栏导航 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 取消
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.cancel),
                  ),

                  // 清单 / 文件夹 Segmented Picker
                  _buildSegmentedPicker(isDark),

                  // 完成
                  TextButton(
                    onPressed: isNameValid ? _submit : null,
                    style: TextButton.styleFrom(
                      foregroundColor: activeAccent,
                      disabledForegroundColor: colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.35),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.done),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── 抽屉可滚动内容区 ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 名称与图标前缀输入卡片
                    _buildNameInputCard(l10n, isDark, activeAccent, isList),

                    const SizedBox(height: 20),

                    // 2. 主题颜色调色板
                    _buildThemeColorSection(l10n, isDark),

                    const SizedBox(height: 20),

                    // 3. 多分类图标选择区
                    _buildIconLibrarySection(l10n, isDark, activeAccent),

                    // 4. 所属文件夹单选列表 (仅在新建清单模式展示)
                    if (isList) ...[
                      const SizedBox(height: 20),
                      _buildFolderSelectionSection(
                        l10n,
                        isDark,
                        activeAccent,
                        groupingAsync,
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 顶栏 Segmented Control
  Widget _buildSegmentedPicker(bool isDark) {
    final isList = _createType == CreateType.list;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262830) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF32353F) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentedItem(
            title: l10n.createList,
            isActive: isList,
            isDark: isDark,
            onTap: () => _switchCreateType(CreateType.list),
          ),
          _buildSegmentedItem(
            title: l10n.createFolder,
            isActive: !isList,
            isDark: isDark,
            onTap: () => _switchCreateType(CreateType.folder),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedItem({
    required String title,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF18191D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive
                ? (isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827))
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
          ),
        ),
      ),
    );
  }

  /// 1. 名称与图标前缀输入卡片
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4B5563),
              ),
            ),
            Text(
              '${name.length}/$_maxNameLength',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontFeatures: AppTokens.fontTabular,
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2025) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: _nameFocusNode.hasFocus
                  ? (isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827))
                  : (isDark
                        ? const Color(0xFF262830)
                        : const Color(0xFFE2E8F0)),
              width: _nameFocusNode.hasFocus ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // 选中的图标与色彩预览徽章
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activeAccent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: activeAccent.withValues(alpha: 0.3),
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

              // 输入框
              Expanded(
                child: TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  autofocus: true,
                  maxLength: _maxNameLength,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) => null,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    hintText: hintTitle,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFD1D5DB),
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
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
                      color: isDark
                          ? const Color(0xFF32353F)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. 主题颜色调色板
  Widget _buildThemeColorSection(AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.modalThemeColor.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4B5563),
              ),
            ),
            Text(
              _selectedColor.localizedName(context),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kPresetModalColors.map((colorPreset) {
              final isSelected = colorPreset.id == _selectedColor.id;
              return Padding(
                padding: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = colorPreset);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorPreset.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: isDark
                                  ? const Color(0xFFF3F4F6)
                                  : const Color(0xFF111827),
                              width: 2.5,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorPreset.color.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 3. 多分类图标选择区
  Widget _buildIconLibrarySection(
    AppLocalizations l10n,
    bool isDark,
    Color activeAccent,
  ) {
    final categories = [
      (PresetIconCategory.common, l10n.catCommon),
      (PresetIconCategory.work, l10n.catWork),
      (PresetIconCategory.life, l10n.catLife),
      (PresetIconCategory.study, l10n.catStudy),
      (PresetIconCategory.health, l10n.catHealth),
      (PresetIconCategory.finance, l10n.catFinance),
    ];

    final currentIcons = kPresetModalIcons[_selectedCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.selectIcon.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4B5563),
              ),
            ),
            Text(
              l10n.instantApply,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 分类胶囊标签
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final isCatActive = cat.$1 == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isCatActive
                          ? (isDark
                                ? const Color(0xFFF3F4F6)
                                : const Color(0xFF111827))
                          : (isDark
                                ? const Color(0xFF262830)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isCatActive
                            ? (isDark
                                  ? const Color(0xFFF3F4F6)
                                  : const Color(0xFF111827))
                            : (isDark
                                  ? const Color(0xFF32353F)
                                  : const Color(0xFFE2E8F0)),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      cat.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCatActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isCatActive
                            ? (isDark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFFFFFFF))
                            : (isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF4B5563)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // 图标网格
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2025) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: isDark ? const Color(0xFF262830) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: currentIcons.length,
            itemBuilder: (context, index) {
              final iconItem = currentIcons[index];
              final isIconActive = iconItem.id == _selectedIcon.id;

              return InkWell(
                onTap: () {
                  setState(() => _selectedIcon = iconItem);
                },
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isIconActive
                        ? (isDark
                              ? const Color(0xFF18191D)
                              : const Color(0xFFFFFFFF))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    border: Border.all(
                      color: isIconActive
                          ? (isDark
                                ? const Color(0xFF32353F)
                                : const Color(0xFFE2E8F0))
                          : Colors.transparent,
                      width: 1,
                    ),
                    boxShadow: isIconActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      iconItem.icon,
                      size: 20,
                      color: isIconActive
                          ? activeAccent
                          : (isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF4B5563)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 4. 所属文件夹单选列表
  Widget _buildFolderSelectionSection(
    AppLocalizations l10n,
    bool isDark,
    Color activeAccent,
    AsyncValue<ProjectGrouping> groupingAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.belongingFolder.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF4B5563),
              ),
            ),
            Text(
              l10n.singleChoiceBelonging,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2025) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: isDark ? const Color(0xFF262830) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard - 1),
            child: groupingAsync.maybeWhen(
              data: (grouping) {
                final folders = grouping.folders;
                return Column(
                  children: [
                    // 无 (顶层清单)
                    _buildFolderRowItem(
                      id: null,
                      name: l10n.noFolderRoot,
                      icon: Icons.do_not_disturb_alt_rounded,
                      count: null,
                      isSelected: _selectedFolderId == null,
                      isDark: isDark,
                      activeAccent: activeAccent,
                      isLast: folders.isEmpty,
                    ),

                    // 已有文件夹列表
                    for (var i = 0; i < folders.length; i++) ...[
                      const Divider(height: 1),
                      _buildFolderRowItem(
                        id: folders[i].id,
                        name: folders[i].name,
                        icon: Icons.folder_outlined,
                        count:
                            grouping.folderProjects[folders[i].id]?.length ?? 0,
                        isSelected: _selectedFolderId == folders[i].id,
                        isDark: isDark,
                        activeAccent: activeAccent,
                        isLast: i == folders.length - 1,
                      ),
                    ],
                  ],
                );
              },
              orElse: () => _buildFolderRowItem(
                id: null,
                name: l10n.noFolderRoot,
                icon: Icons.do_not_disturb_alt_rounded,
                count: null,
                isSelected: true,
                isDark: isDark,
                activeAccent: activeAccent,
                isLast: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderRowItem({
    required String? id,
    required String name,
    required IconData icon,
    required int? count,
    required bool isSelected,
    required bool isDark,
    required Color activeAccent,
    required bool isLast,
  }) {
    final l10n = AppLocalizations.of(context);

    return InkWell(
      onTap: () {
        setState(() => _selectedFolderId = id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFF3F4F6)
                      : const Color(0xFF111827),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null) ...[
              Text(
                l10n.listsCount(count),
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: AppTokens.fontTabular,
                  color: isDark
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
            ],
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isSelected ? 1.0 : 0.0,
              child: Icon(Icons.check_rounded, size: 18, color: activeAccent),
            ),
          ],
        ),
      ),
    );
  }
}
