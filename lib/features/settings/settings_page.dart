import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'settings_providers.dart';

/// 应用版本号（与 pubspec.yaml 的 version 保持一致，非可翻译文案）。
const String appVersion = '1.0.0';

/// 设置页（50-ui-ux.md §5.7）：外观（主题模式/语言）+ 关于。
///
/// M0 阶段实现主题三模式与 zh/en 语言切换，即时生效并持久化
/// （FR-SET-01 / FR-SET-02）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          _SectionHeader(title: l10n.settingsSectionAppearance),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.themeMode),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceXs),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.themeModeSystem),
                    icon: const Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.themeModeLight),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.themeModeDark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) => ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selection.first),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.language),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceXs),
              child: SegmentedButton<Locale>(
                segments: [
                  ButtonSegment(
                    value: const Locale('zh'),
                    label: Text(l10n.languageZh),
                  ),
                  ButtonSegment(
                    value: const Locale('en'),
                    label: Text(l10n.languageEn),
                  ),
                ],
                selected: {locale},
                onSelectionChanged: (selection) => ref
                    .read(localeProvider.notifier)
                    .setLocale(selection.first),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.spaceXl),
          _SectionHeader(title: l10n.settingsSectionAbout),
          ListTile(contentPadding: EdgeInsets.zero, title: Text(l10n.appTitle)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.aboutVersion),
            trailing: Text(appVersion),
          ),
        ],
      ),
    );
  }
}

/// 设置分组标题。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceXs,
        vertical: AppTokens.spaceXs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
