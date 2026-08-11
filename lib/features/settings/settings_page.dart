import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'settings_providers.dart';

/// App version (keep in sync with pubspec.yaml version, not translatable).
const String appVersion = '1.0.0';

/// Settings page: Appearance (theme/language) + About.
///
/// Theme mode (system/light/dark) and language (zh/en) switch instantly
/// and persist via SharedPreferences (FR-SET-01 / FR-SET-02).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          _SectionHeader(title: l10n.settingsSectionAppearance),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.themeMode, style: theme.textTheme.bodyLarge),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceSm),
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
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.language, style: theme.textTheme.bodyLarge),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceSm),
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
            ],
          ),
          const SizedBox(height: AppTokens.spaceXl),
          _SectionHeader(title: l10n.settingsSectionAbout),
          _SettingsCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.appTitle),
                subtitle: Text(
                  l10n.aboutVersion,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Text(
                  appVersion,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings section label.
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Card wrapper for a settings group.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(children: children),
      ),
    );
  }
}
