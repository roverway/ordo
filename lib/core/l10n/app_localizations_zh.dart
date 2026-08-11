// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Todo';

  @override
  String get navToday => '今日';

  @override
  String get navCalendar => '日历';

  @override
  String get navProjects => '项目';

  @override
  String get navTags => '标签';

  @override
  String get search => '搜索';

  @override
  String get settings => '设置';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get aboutVersion => '版本';

  @override
  String get emptyToday => '今天还没有任务';

  @override
  String get emptyCalendar => '日历暂无安排';

  @override
  String get emptyProjects => '还没有项目';

  @override
  String get emptyTags => '还没有标签';

  @override
  String get emptySearch => '未找到相关内容';
}
