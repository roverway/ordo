import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/background_config.dart';
import '../../../shared/widgets/app_background_wrapper.dart';
import '../settings_providers.dart';

/// 呼出通用壁纸选择与调节弹层
Future<BackgroundConfig?> showWallpaperPickerSheet({
  required BuildContext context,
  required BackgroundConfig initialConfig,
  bool isGlobal = false,
  String? title,
}) {
  return showModalBottomSheet<BackgroundConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WallpaperPickerSheet(
      initialConfig: initialConfig,
      isGlobal: isGlobal,
      title: title,
    ),
  );
}

/// 壁纸选择与实时调节弹层
class WallpaperPickerSheet extends ConsumerStatefulWidget {
  const WallpaperPickerSheet({
    super.key,
    required this.initialConfig,
    this.isGlobal = false,
    this.title,
  });

  final BackgroundConfig initialConfig;
  final bool isGlobal;
  final String? title;

  @override
  ConsumerState<WallpaperPickerSheet> createState() =>
      _WallpaperPickerSheetState();
}

class _WallpaperPickerSheetState extends ConsumerState<WallpaperPickerSheet> {
  late BackgroundConfig _currentConfig;
  bool _isCustomLoading = false;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.initialConfig;
  }

  void _updateConfig(BackgroundConfig newConfig) {
    setState(() {
      _currentConfig = newConfig;
    });
  }

  Future<void> _pickCustomImage() async {
    setState(() => _isCustomLoading = true);
    try {
      final storage = ref.read(wallpaperStorageServiceProvider);
      final savedPath = await storage.pickAndSaveCustomWallpaper();
      if (savedPath != null && mounted) {
        _updateConfig(
          _currentConfig.copyWith(
            type: BackgroundType.custom,
            value: savedPath,
            opacity: _currentConfig.opacity > 0 ? _currentConfig.opacity : 0.35,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCustomLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetTitle =
        widget.title ??
        (widget.isGlobal ? l10n.wallpaperTitleApp : l10n.wallpaperTitleProject);

    return Container(
      constraints: const BoxConstraints(maxHeight: 700),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
        borderRadius: AppTokens.sheetTopBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTokens.alphaTintStrong),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 顶部拖动手柄与标题栏 ──
            _buildHeader(sheetTitle, colorScheme, l10n),
            const Divider(height: 1),

            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceLg,
                  vertical: AppTokens.spaceMd,
                ),
                shrinkWrap: true,
                children: [
                  // ── 1. 实时预览区域 ──
                  _buildPreviewArea(isDark, theme, l10n),
                  const SizedBox(height: AppTokens.spaceLg),

                  // ── 2. 快捷模式切换（无壁纸/跟随、自定义、预设） ──
                  _buildSourceSelector(l10n, colorScheme, isDark),
                  const SizedBox(height: AppTokens.spaceLg),

                  // ── 3. 参数调节滑块（仅在有壁纸时展示） ──
                  if (_currentConfig.isEffective) ...[
                    _buildAdjustmentsSection(l10n, colorScheme),
                    const SizedBox(height: AppTokens.spaceMd),
                  ],
                ],
              ),
            ),

            // ── 底部保存按钮 ──
            _buildBottomBar(l10n, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String title,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: AppTokens.sheetGrabberWidth,
          height: AppTokens.sheetGrabberHeight,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(AppTokens.sheetGrabberRadius),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppTokens.textTitleSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 实时小部件卡片交互预览
  Widget _buildPreviewArea(
    bool isDark,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: AppTokens.alphaBorderSubtle)
              : Colors.black.withValues(alpha: AppTokens.alphaBorderSubtle),
        ),
      ),
      child: AppBackgroundWrapper(
        overrideConfig: _currentConfig,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    ),
                    child: Text(
                      l10n.wallpaperPreviewBadge,
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  if (_currentConfig.isEffective)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: l10n.delete,
                      onPressed: () {
                        _updateConfig(
                          const BackgroundConfig(type: BackgroundType.none),
                        );
                      },
                    ),
                ],
              ),
              const Spacer(),
              // 模拟任务卡片
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTokens.surfaceCardDark.withValues(
                          alpha: AppTokens.alphaOverlayHeavy,
                        )
                      : AppTokens.surfaceCard.withValues(
                          alpha: AppTokens.alphaOverlayHeavy,
                        ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(
                            alpha: AppTokens.alphaBorderSubtle,
                          )
                        : Colors.black.withValues(
                            alpha: AppTokens.alphaBorderSubtle,
                          ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.wallpaperPreviewText,
                        style: const TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 壁纸来源选择网格
  Widget _buildSourceSelector(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.wallpaperPresetLabel,
          style: const TextStyle(
            fontSize: AppTokens.textBodySize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTokens.spaceSm),

        // 网格展示：无壁纸/跟随选项 + 预设壁纸 + 自定义上传
        GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.8,
          children: [
            // 选项 1: 无壁纸（或跟随应用）
            _buildNoneTile(l10n, colorScheme, isDark),

            // 预设壁纸列表
            ...kPresetWallpapers.map((preset) {
              final isSelected =
                  _currentConfig.type == BackgroundType.preset &&
                  _currentConfig.value == preset.assetPath;
              return _buildPresetTile(preset, isSelected, colorScheme);
            }),

            // 选项 3: 自定义本地相册/文件选择
            _buildCustomUploadTile(l10n, colorScheme, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildNoneTile(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final isSelected = !_currentConfig.isEffective;
    final label = widget.isGlobal
        ? l10n.wallpaperDefaultPure
        : l10n.wallpaperFollowApp;

    return GestureDetector(
      onTap: () {
        _updateConfig(const BackgroundConfig(type: BackgroundType.none));
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusList),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isSelected ? 2.5 : 1.0,
                ),
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.surfaceContainerLow,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.block,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTokens.textFootnoteSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected ? colorScheme.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetTile(
    PresetWallpaperItem preset,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    final langCode = Localizations.localeOf(context).languageCode;
    final title = preset.localizedLabel(langCode);
    final config = BackgroundConfig(
      type: BackgroundType.preset,
      value: preset.assetPath,
      opacity: _currentConfig.opacity > 0 ? _currentConfig.opacity : 0.35,
      blur: _currentConfig.blur,
    );

    return GestureDetector(
      onTap: () {
        _updateConfig(config);
      },
      child: Column(
        children: [
          Expanded(
            child: WallpaperThumbnail(
              config: config,
              isSelected: isSelected,
              borderRadius: AppTokens.radiusList,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: AppTokens.textFootnoteSize,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected ? colorScheme.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomUploadTile(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final isCustomSelected =
        _currentConfig.type == BackgroundType.custom &&
        _currentConfig.isEffective;

    return GestureDetector(
      onTap: _isCustomLoading ? null : _pickCustomImage,
      child: Column(
        children: [
          Expanded(
            child: isCustomSelected
                ? WallpaperThumbnail(
                    config: _currentConfig,
                    isSelected: true,
                    borderRadius: AppTokens.radiusList,
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusList),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        style: BorderStyle.solid,
                      ),
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.surfaceContainerLow,
                    ),
                    alignment: Alignment.center,
                    child: _isCustomLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.add_photo_alternate_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.wallpaperCustomUpload,
            style: TextStyle(
              fontSize: AppTokens.textFootnoteSize,
              fontWeight: isCustomSelected
                  ? FontWeight.w700
                  : FontWeight.normal,
              color: isCustomSelected ? colorScheme.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 遮罩透明度与高斯模糊调节
  Widget _buildAdjustmentsSection(
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: AppTokens.alphaBorderSubtle,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 遮罩暗度调节 ──
          Row(
            children: [
              const Icon(Icons.tonality, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.wallpaperOpacityLabel,
                style: const TextStyle(
                  fontSize: AppTokens.textBodySize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(_currentConfig.opacity * 100).round()}%',
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _currentConfig.opacity.clamp(0.0, 0.85),
            min: 0.0,
            max: 0.85,
            divisions: 17,
            onChanged: (val) {
              _updateConfig(_currentConfig.copyWith(opacity: val));
            },
          ),

          const SizedBox(height: AppTokens.spaceSm),

          // ── 高斯模糊调节 ──
          Row(
            children: [
              const Icon(Icons.blur_on, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.wallpaperBlurLabel,
                style: const TextStyle(
                  fontSize: AppTokens.textBodySize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_currentConfig.blur.round()}px',
                style: TextStyle(
                  fontSize: AppTokens.textFootnoteSize,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _currentConfig.blur.clamp(0.0, 20.0),
            min: 0.0,
            max: 20.0,
            divisions: 20,
            onChanged: (val) {
              _updateConfig(_currentConfig.copyWith(blur: val));
            },
          ),
        ],
      ),
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar(AppLocalizations l10n, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop(_currentConfig);
              },
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}
