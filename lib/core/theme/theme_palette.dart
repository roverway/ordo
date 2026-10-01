import 'package:flutter/widgets.dart';

/// 主题调色盘预设模型。
class ThemePalettePreset {
  const ThemePalettePreset({
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

/// 8 款经过明度与对比度校准的精选现代调色盘预设（全应用统一主题色体系）。
const List<ThemePalettePreset> defaultThemePalettes = [
  ThemePalettePreset(
    id: 'black',
    color: Color(0xFF111827),
    nameZh: '曜石黑',
    nameEn: 'Obsidian Black',
  ),
  ThemePalettePreset(
    id: 'blue',
    color: Color(0xFF2563EB),
    nameZh: '克莱因蓝',
    nameEn: 'Klein Blue',
  ),
  ThemePalettePreset(
    id: 'emerald',
    color: Color(0xFF059669),
    nameZh: '翡翠绿',
    nameEn: 'Emerald Green',
  ),
  ThemePalettePreset(
    id: 'amber',
    color: Color(0xFFD97706),
    nameZh: '琥珀橙',
    nameEn: 'Amber Orange',
  ),
  ThemePalettePreset(
    id: 'purple',
    color: Color(0xFF7C3AED),
    nameZh: '罗兰紫',
    nameEn: 'Violet Purple',
  ),
  ThemePalettePreset(
    id: 'rose',
    color: Color(0xFFE11D48),
    nameZh: '玫瑰红',
    nameEn: 'Rose Red',
  ),
  ThemePalettePreset(
    id: 'teal',
    color: Color(0xFF0891B2),
    nameZh: '松石青',
    nameEn: 'Turquoise Teal',
  ),
  ThemePalettePreset(
    id: 'slate',
    color: Color(0xFF64748B),
    nameZh: '烟雨灰',
    nameEn: 'Misty Slate',
  ),
];
