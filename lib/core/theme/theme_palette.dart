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
