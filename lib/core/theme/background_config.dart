import 'dart:convert';

/// 壁纸类型。
enum BackgroundType {
  /// 无壁纸（或跟随上一级默认）
  none,

  /// 预设应用内壁纸 (assets/images/wallpapers/...)
  preset,

  /// 自定义本地图片 (沙箱文件绝对路径)
  custom,
}

/// 壁纸平铺与适配模式。
enum BackgroundFit {
  /// 保持宽高比铺满裁剪（默认）
  cover,

  /// 完整显示并留白
  contain,

  /// 居中不缩放
  center,
}

/// 预设壁纸数据描述项。
class PresetWallpaperItem {
  const PresetWallpaperItem({
    required this.id,
    required this.assetPath,
    required this.labelZh,
    required this.labelEn,
  });

  final String id;
  final String assetPath;
  final String labelZh;
  final String labelEn;

  String localizedLabel(String languageCode) =>
      languageCode == 'en' ? labelEn : labelZh;
}

/// 内置精选壁纸列表。
const List<PresetWallpaperItem> kPresetWallpapers = [
  PresetWallpaperItem(
    id: 'aurora',
    assetPath: 'assets/images/wallpapers/wp_aurora.png',
    labelZh: '极光渐变',
    labelEn: 'Aurora Glow',
  ),
  PresetWallpaperItem(
    id: 'mountain',
    assetPath: 'assets/images/wallpapers/wp_mountain.png',
    labelZh: '远山暮色',
    labelEn: 'Mountain Dusk',
  ),
  PresetWallpaperItem(
    id: 'minimal_ocean',
    assetPath: 'assets/images/wallpapers/wp_ocean.png',
    labelZh: '静谧深海',
    labelEn: 'Quiet Ocean',
  ),
  PresetWallpaperItem(
    id: 'warm_dune',
    assetPath: 'assets/images/wallpapers/wp_dune.png',
    labelZh: '暖沙暮光',
    labelEn: 'Warm Dune',
  ),
  PresetWallpaperItem(
    id: 'cyber_mist',
    assetPath: 'assets/images/wallpapers/wp_mist.png',
    labelZh: '晨雾淡青',
    labelEn: 'Cyber Mist',
  ),
];

/// 背景壁纸完整配置（不可变对象）。
class BackgroundConfig {
  const BackgroundConfig({
    this.type = BackgroundType.none,
    this.value,
    this.opacity = 0.35,
    this.blur = 0.0,
    this.fit = BackgroundFit.cover,
  });

  /// 壁纸类型
  final BackgroundType type;

  /// 壁纸资源：预设 asset 相对路径 或 本地绝对文件路径
  final String? value;

  /// 遮罩暗度/透明度（0.0 ~ 0.85，默认 0.35）
  final double opacity;

  /// 高斯模糊强度 sigma（0.0 ~ 20.0，默认 0.0）
  final double blur;

  /// 填充适配模式
  final BackgroundFit fit;

  /// 默认无壁纸状态
  static const BackgroundConfig none = BackgroundConfig();

  /// 是否真正生效（非 none 且路径有效）
  bool get isEffective =>
      type != BackgroundType.none && value != null && value!.trim().isNotEmpty;

  /// 拷贝并修改特定属性
  BackgroundConfig copyWith({
    BackgroundType? type,
    String? value,
    double? opacity,
    double? blur,
    BackgroundFit? fit,
  }) {
    return BackgroundConfig(
      type: type ?? this.type,
      value: value ?? this.value,
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      fit: fit ?? this.fit,
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'value': value,
    'opacity': opacity,
    'blur': blur,
    'fit': fit.name,
  };

  /// 从 JSON Map 解析
  factory BackgroundConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = BackgroundType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => BackgroundType.none,
    );
    final value = json['value'] as String?;
    final opacity = (json['opacity'] as num?)?.toDouble() ?? 0.35;
    final blur = (json['blur'] as num?)?.toDouble() ?? 0.0;
    final fitName = json['fit'] as String?;
    final fit = BackgroundFit.values.firstWhere(
      (e) => e.name == fitName,
      orElse: () => BackgroundFit.cover,
    );

    return BackgroundConfig(
      type: type,
      value: value,
      opacity: opacity.clamp(0.0, 0.85),
      blur: blur.clamp(0.0, 20.0),
      fit: fit,
    );
  }

  /// 序列化为 JSON 字符串以持久化存储
  String serialize() => jsonEncode(toJson());

  /// 从持久化字符串反序列化
  static BackgroundConfig deserialize(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return BackgroundConfig.none;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return BackgroundConfig.fromJson(decoded);
      }
    } catch (_) {
      // 容错降级
    }
    return BackgroundConfig.none;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundConfig &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          opacity == other.opacity &&
          blur == other.blur &&
          fit == other.fit;

  @override
  int get hashCode => Object.hash(type, value, opacity, blur, fit);

  @override
  String toString() =>
      'BackgroundConfig(type: $type, value: $value, opacity: $opacity, blur: $blur, fit: $fit)';
}
