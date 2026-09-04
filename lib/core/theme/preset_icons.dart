import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 图标分类枚举。
enum PresetIconCategory { common, work, life, study, health, finance }

/// 预设图标数据模型。
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

/// 预设主题色（全应用统一主题色体系，别名引用 ThemePalettePreset）。
typedef PresetModalColor = ThemePalettePreset;

/// 8 款精选主题色。
const List<PresetModalColor> kPresetModalColors = AppTokens.themePalettes;

/// 丰富预置图标库（每类 16 个语义图标，共 96 款）。
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

/// 静态哈希索引表，实现 O(1) 瞬时查找。
final Map<String, PresetIconItem> _presetIconsById = {
  for (final list in kPresetModalIcons.values)
    for (final item in list) item.id: item,
};

/// 根据 iconId 查找预置图标项（O(1) 索引查找）。
PresetIconItem? getPresetIconById(String? id) {
  if (id == null || id.isEmpty) return null;
  return _presetIconsById[id];
}

/// 根据 iconId 查找 IconData。
IconData getIconDataById(
  String? id, {
  IconData fallback = Icons.format_list_bulleted_rounded,
}) {
  return getPresetIconById(id)?.icon ?? fallback;
}
