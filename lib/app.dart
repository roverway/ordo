import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/l10n/app_localizations_en.dart';
import 'core/l10n/app_localizations_zh.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/settings_providers.dart';
import 'router.dart';

/// 应用根组件：MaterialApp.router 装配主题 + l10n + 路由（30-architecture.md §2）。
///
/// 主题三模式（跟随系统/浅色/深色）与语言（zh/en）由设置页 Provider 驱动，
/// 切换即时生效并持久化。
class TodoApp extends ConsumerWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // 平台标题（任务切换器/窗口标题）：按当前语言取 ARB 文案。
    final appTitle = locale.languageCode == 'en'
        ? AppLocalizationsEn().appTitle
        : AppLocalizationsZh().appTitle;

    return MaterialApp.router(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(ThemeMode.light),
      darkTheme: AppTheme.build(ThemeMode.dark),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
