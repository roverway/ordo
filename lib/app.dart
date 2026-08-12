import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/l10n/app_localizations_en.dart';
import 'core/l10n/app_localizations_zh.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_providers.dart';
import 'router.dart';
import 'shared/widgets/lifecycle_sync_listener.dart';

/// Application root: assembles theme, l10n, and routing.
///
/// Theme (light/dark/system) and language (zh/en) are driven by settings
/// providers, persisted to SharedPreferences, and switch instantly.
class TodoApp extends ConsumerWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    final appTitle = locale.languageCode == 'en'
        ? AppLocalizationsEn().appTitle
        : AppLocalizationsZh().appTitle;

    return LifecycleSyncListener(
      child: MaterialApp.router(
        title: appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(Brightness.light),
        darkTheme: AppTheme.build(Brightness.dark),
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter,
      ),
    );
  }
}
