import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../project_providers.dart';

/// 模式：清单 vs 文件夹
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

/// 8 款精选主题色
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

/// 丰富预置图标库（每类 16 个语义图标）
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
    PresetIconItem(
      id: 'pin',
      icon: Icons.push_pin_outlined,
      nameZh: '置顶',
      nameEn: 'Pin',
    ),
    PresetIconItem(
      id: 'bookmark',
      icon: Icons.bookmark_outline_rounded,
      nameZh: '书签',
      nameEn: 'Bookmark',
    ),
    PresetIconItem(
      id: 'bolt',
      icon: Icons.bolt_rounded,
      nameZh: '闪念',
      nameEn: 'Quick',
    ),
    PresetIconItem(
      id: 'check-circle',
      icon: Icons.check_circle_outline_rounded,
      nameZh: '完成',
      nameEn: 'Done',
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
    PresetIconItem(
      id: 'terminal',
      icon: Icons.terminal_rounded,
      nameZh: '终端',
      nameEn: 'Terminal',
    ),
    PresetIconItem(
      id: 'code',
      icon: Icons.code_rounded,
      nameZh: '编程',
      nameEn: 'Code',
    ),
    PresetIconItem(
      id: 'bug',
      icon: Icons.bug_report_outlined,
      nameZh: '缺陷',
      nameEn: 'Bug',
    ),
    PresetIconItem(
      id: 'build',
      icon: Icons.build_outlined,
      nameZh: '工具',
      nameEn: 'Build',
    ),
    PresetIconItem(
      id: 'design',
      icon: Icons.design_services_outlined,
      nameZh: '设计',
      nameEn: 'Design',
    ),
    PresetIconItem(
      id: 'assessment',
      icon: Icons.assessment_outlined,
      nameZh: '报告',
      nameEn: 'Report',
    ),
    PresetIconItem(
      id: 'meeting',
      icon: Icons.meeting_room_outlined,
      nameZh: '会议',
      nameEn: 'Meeting',
    ),
    PresetIconItem(
      id: 'campaign',
      icon: Icons.campaign_outlined,
      nameZh: '推广',
      nameEn: 'Campaign',
    ),
    PresetIconItem(
      id: 'architecture',
      icon: Icons.architecture_rounded,
      nameZh: '架构',
      nameEn: 'Architecture',
    ),
    PresetIconItem(
      id: 'handshake',
      icon: Icons.handshake_outlined,
      nameZh: '合作',
      nameEn: 'Collaboration',
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
    PresetIconItem(
      id: 'flight',
      icon: Icons.flight_takeoff_rounded,
      nameZh: '旅行',
      nameEn: 'Travel',
    ),
    PresetIconItem(
      id: 'car',
      icon: Icons.directions_car_outlined,
      nameZh: '出行',
      nameEn: 'Transport',
    ),
    PresetIconItem(
      id: 'florist',
      icon: Icons.local_florist_outlined,
      nameZh: '绿植',
      nameEn: 'Plant',
    ),
    PresetIconItem(
      id: 'pets',
      icon: Icons.pets_rounded,
      nameZh: '宠物',
      nameEn: 'Pets',
    ),
    PresetIconItem(
      id: 'movie',
      icon: Icons.movie_outlined,
      nameZh: '电影',
      nameEn: 'Movie',
    ),
    PresetIconItem(
      id: 'weekend',
      icon: Icons.weekend_outlined,
      nameZh: '假期',
      nameEn: 'Weekend',
    ),
    PresetIconItem(
      id: 'child',
      icon: Icons.child_friendly_rounded,
      nameZh: '亲子',
      nameEn: 'Family',
    ),
    PresetIconItem(
      id: 'cleaning',
      icon: Icons.cleaning_services_outlined,
      nameZh: '家务',
      nameEn: 'Cleaning',
    ),
    PresetIconItem(
      id: 'umbrella',
      icon: Icons.beach_access_rounded,
      nameZh: '度假',
      nameEn: 'Resort',
    ),
    PresetIconItem(
      id: 'camera',
      icon: Icons.camera_alt_outlined,
      nameZh: '摄影',
      nameEn: 'Photo',
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
    PresetIconItem(
      id: 'auto-stories',
      icon: Icons.auto_stories_rounded,
      nameZh: '书籍',
      nameEn: 'Books',
    ),
    PresetIconItem(
      id: 'psychology',
      icon: Icons.psychology_outlined,
      nameZh: '思维',
      nameEn: 'Mind',
    ),
    PresetIconItem(
      id: 'science',
      icon: Icons.science_outlined,
      nameZh: '科学',
      nameEn: 'Science',
    ),
    PresetIconItem(
      id: 'calculate',
      icon: Icons.calculate_outlined,
      nameZh: '数学',
      nameEn: 'Math',
    ),
    PresetIconItem(
      id: 'translate',
      icon: Icons.translate_rounded,
      nameZh: '语言',
      nameEn: 'Language',
    ),
    PresetIconItem(
      id: 'quiz',
      icon: Icons.quiz_outlined,
      nameZh: '测验',
      nameEn: 'Quiz',
    ),
    PresetIconItem(
      id: 'draw',
      icon: Icons.draw_outlined,
      nameZh: '写作',
      nameEn: 'Writing',
    ),
    PresetIconItem(
      id: 'history',
      icon: Icons.history_edu_rounded,
      nameZh: '历史',
      nameEn: 'History',
    ),
    PresetIconItem(
      id: 'history-toggle',
      icon: Icons.history_toggle_off_rounded,
      nameZh: '复习',
      nameEn: 'Review',
    ),
    PresetIconItem(
      id: 'spellcheck',
      icon: Icons.spellcheck_rounded,
      nameZh: '语法',
      nameEn: 'Grammar',
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
    PresetIconItem(
      id: 'hospital',
      icon: Icons.local_hospital_outlined,
      nameZh: '医疗',
      nameEn: 'Hospital',
    ),
    PresetIconItem(
      id: 'run',
      icon: Icons.directions_run_rounded,
      nameZh: '跑步',
      nameEn: 'Running',
    ),
    PresetIconItem(
      id: 'walk',
      icon: Icons.directions_walk_rounded,
      nameZh: '步行',
      nameEn: 'Walking',
    ),
    PresetIconItem(
      id: 'meditation',
      icon: Icons.self_improvement_rounded,
      nameZh: '冥想',
      nameEn: 'Meditation',
    ),
    PresetIconItem(
      id: 'monitor-heart',
      icon: Icons.monitor_heart_outlined,
      nameZh: '心率',
      nameEn: 'Heart Rate',
    ),
    PresetIconItem(
      id: 'pool',
      icon: Icons.pool_rounded,
      nameZh: '游泳',
      nameEn: 'Swimming',
    ),
    PresetIconItem(
      id: 'spa',
      icon: Icons.spa_outlined,
      nameZh: '水疗',
      nameEn: 'Spa',
    ),
    PresetIconItem(
      id: 'pharmacy',
      icon: Icons.local_pharmacy_outlined,
      nameZh: '用药',
      nameEn: 'Medicine',
    ),
    PresetIconItem(
      id: 'nature',
      icon: Icons.nature_people_outlined,
      nameZh: '户外',
      nameEn: 'Outdoor',
    ),
    PresetIconItem(
      id: 'blind',
      icon: Icons.blind_rounded,
      nameZh: '视力',
      nameEn: 'Eye Care',
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
      nameZh: '投资',
      nameEn: 'Invest',
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
      nameZh: '消费',
      nameEn: 'Expense',
    ),
    PresetIconItem(
      id: 'savings',
      icon: Icons.savings_outlined,
      nameZh: '储蓄',
      nameEn: 'Savings',
    ),
    PresetIconItem(
      id: 'bank',
      icon: Icons.account_balance_outlined,
      nameZh: '银行',
      nameEn: 'Bank',
    ),
    PresetIconItem(
      id: 'payments',
      icon: Icons.payments_outlined,
      nameZh: '支付',
      nameEn: 'Payments',
    ),
    PresetIconItem(
      id: 'monetization',
      icon: Icons.monetization_on_outlined,
      nameZh: '收入',
      nameEn: 'Income',
    ),
    PresetIconItem(
      id: 'point-of-sale',
      icon: Icons.point_of_sale_rounded,
      nameZh: '结算',
      nameEn: 'POS',
    ),
    PresetIconItem(
      id: 'price-change',
      icon: Icons.price_change_outlined,
      nameZh: '行情',
      nameEn: 'Market',
    ),
    PresetIconItem(
      id: 'currency-exchange',
      icon: Icons.currency_exchange_rounded,
      nameZh: '外汇',
      nameEn: 'Exchange',
    ),
    PresetIconItem(
      id: 'pie-chart',
      icon: Icons.pie_chart_outline_rounded,
      nameZh: '预算',
      nameEn: 'Budget',
    ),
    PresetIconItem(
      id: 'bar-chart',
      icon: Icons.bar_chart_rounded,
      nameZh: '报表',
      nameEn: 'Analytics',
    ),
    PresetIconItem(
      id: 'qr-code',
      icon: Icons.qr_code_rounded,
      nameZh: '扫码',
      nameEn: 'QR Pay',
    ),
  ],
};

/// 根据 iconId 查找预置图标项
PresetIconItem? getPresetIconById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final list in kPresetModalIcons.values) {
    for (final item in list) {
      if (item.id == id) return item;
    }
  }
  return null;
}

/// 根据 iconId 查找 IconData
IconData getIconDataById(
  String? id, {
  IconData fallback = Icons.format_list_bulleted_rounded,
}) {
  return getPresetIconById(id)?.icon ?? fallback;
}

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
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        // 聚焦后全屏，非聚焦时对齐导航弹窗（0.85）
        maxHeight: targetMaxHeight,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191D) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isFocused ? 16 : 24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
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
                    foregroundColor: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    l10n.cancel,
                    style: const TextStyle(
                      fontSize: 15,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF3F4F6)
                          : const Color(0xFF111827),
                    ),
                  )
                else
                  _buildSegmentedControl(l10n, isDark),

                // 右侧完成
                TextButton(
                  onPressed: isNameValid && !_isSubmitting ? _submit : null,
                  style: TextButton.styleFrom(
                    foregroundColor: activeAccent,
                    disabledForegroundColor: isDark
                        ? const Color(0xFF4B5563)
                        : const Color(0xFFD1D5DB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: isNameValid
                        ? activeAccent.withValues(alpha: 0.12)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                            fontSize: 15,
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
        color: isDark ? const Color(0xFF262830) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF374151) : const Color(0xFFFFFFFF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
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
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFFF9FAFB) : const Color(0xFF111827))
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
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
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
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

              // 输入框：无任何背景色或边框
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
                          : const Color(0xFF9CA3AF),
                    ),
                    isDense: true,
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
                      color: isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
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
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? const Color(0xFF18191D)
                              : Colors.white,
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
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
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
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? activeAccent
                          : (isDark
                                ? const Color(0xFF262830)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getCategoryName(cat, l10n),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // 图标网格
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2025) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: isDark ? const Color(0xFF262830) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
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
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: itemWidth,
                      height: itemWidth,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeAccent.withValues(alpha: 0.14)
                            : (isDark
                                  ? const Color(0xFF262830)
                                  : const Color(0xFFFFFFFF)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? activeAccent
                              : (isDark
                                    ? const Color(0xFF333640)
                                    : const Color(0xFFE5E7EB)),
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
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFF4B5563)),
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
                color: isDark
                    ? const Color(0xFF6B7280)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2025) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: isDark ? const Color(0xFF262830) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
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
                      const Divider(height: 1, thickness: 0.5),
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
        (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFolderId = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isSelected
            ? activeAccent.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
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
