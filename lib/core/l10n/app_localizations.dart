import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Todo'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get navToday;

  /// No description provided for @navCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get navCalendar;

  /// No description provided for @navProjects.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get navProjects;

  /// No description provided for @navTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get navTags;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsSectionAppearance;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @themeModeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeModeSystem;

  /// No description provided for @themeModeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeModeLight;

  /// No description provided for @themeModeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeModeDark;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsSectionAbout;

  /// No description provided for @aboutVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get aboutVersion;

  /// No description provided for @emptyToday.
  ///
  /// In zh, this message translates to:
  /// **'今天还没有任务'**
  String get emptyToday;

  /// No description provided for @emptyCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历暂无安排'**
  String get emptyCalendar;

  /// No description provided for @emptyProjects.
  ///
  /// In zh, this message translates to:
  /// **'还没有项目'**
  String get emptyProjects;

  /// No description provided for @emptyTags.
  ///
  /// In zh, this message translates to:
  /// **'还没有标签'**
  String get emptyTags;

  /// No description provided for @emptySearch.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关内容'**
  String get emptySearch;

  /// No description provided for @newProject.
  ///
  /// In zh, this message translates to:
  /// **'新建项目'**
  String get newProject;

  /// No description provided for @projectName.
  ///
  /// In zh, this message translates to:
  /// **'项目名称'**
  String get projectName;

  /// No description provided for @projectColor.
  ///
  /// In zh, this message translates to:
  /// **'项目颜色'**
  String get projectColor;

  /// No description provided for @editProject.
  ///
  /// In zh, this message translates to:
  /// **'编辑项目'**
  String get editProject;

  /// No description provided for @deleteProject.
  ///
  /// In zh, this message translates to:
  /// **'删除项目'**
  String get deleteProject;

  /// No description provided for @deleteProjectConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除项目「{name}」吗？'**
  String deleteProjectConfirm(Object name);

  /// No description provided for @deleteProjectWarning.
  ///
  /// In zh, this message translates to:
  /// **'该项目下的所有任务也会被删除，此操作不可撤销。'**
  String get deleteProjectWarning;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @newTask.
  ///
  /// In zh, this message translates to:
  /// **'新建任务'**
  String get newTask;

  /// No description provided for @newSubtask.
  ///
  /// In zh, this message translates to:
  /// **'新建子任务'**
  String get newSubtask;

  /// No description provided for @taskTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务标题'**
  String get taskTitle;

  /// No description provided for @taskDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get taskDescription;

  /// No description provided for @taskNotes.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get taskNotes;

  /// No description provided for @taskStartTime.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get taskStartTime;

  /// No description provided for @taskEndTime.
  ///
  /// In zh, this message translates to:
  /// **'截止时间'**
  String get taskEndTime;

  /// No description provided for @taskStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get taskStatus;

  /// No description provided for @taskTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get taskTags;

  /// No description provided for @taskProject.
  ///
  /// In zh, this message translates to:
  /// **'所属项目'**
  String get taskProject;

  /// No description provided for @taskParent.
  ///
  /// In zh, this message translates to:
  /// **'父任务'**
  String get taskParent;

  /// No description provided for @statusTodo.
  ///
  /// In zh, this message translates to:
  /// **'待办'**
  String get statusTodo;

  /// No description provided for @statusInProgress.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get statusInProgress;

  /// No description provided for @statusDone.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusDone;

  /// No description provided for @statusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get statusCancelled;

  /// No description provided for @titleRequired.
  ///
  /// In zh, this message translates to:
  /// **'标题不能为空'**
  String get titleRequired;

  /// No description provided for @endTimeBeforeStart.
  ///
  /// In zh, this message translates to:
  /// **'截止时间不能早于开始时间'**
  String get endTimeBeforeStart;

  /// No description provided for @depthLimitExceeded.
  ///
  /// In zh, this message translates to:
  /// **'已达到最大层级（3级），无法创建子任务'**
  String get depthLimitExceeded;

  /// No description provided for @moveDepthExceeded.
  ///
  /// In zh, this message translates to:
  /// **'移动后层级超过上限'**
  String get moveDepthExceeded;

  /// No description provided for @cannotMoveToSelf.
  ///
  /// In zh, this message translates to:
  /// **'不能移动到自身'**
  String get cannotMoveToSelf;

  /// No description provided for @cannotMoveToDescendant.
  ///
  /// In zh, this message translates to:
  /// **'不能移动到自身的子任务下'**
  String get cannotMoveToDescendant;

  /// No description provided for @deleteTask.
  ///
  /// In zh, this message translates to:
  /// **'删除任务'**
  String get deleteTask;

  /// No description provided for @deleteTaskConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除任务「{title}」吗？'**
  String deleteTaskConfirm(Object title);

  /// No description provided for @deleteTaskWarning.
  ///
  /// In zh, this message translates to:
  /// **'该任务的子任务也会被删除，此操作不可撤销。'**
  String get deleteTaskWarning;

  /// No description provided for @emptyProjectDetail.
  ///
  /// In zh, this message translates to:
  /// **'还没有任务，点击下方按钮新建'**
  String get emptyProjectDetail;

  /// No description provided for @moveUp.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get moveDown;

  /// No description provided for @indent.
  ///
  /// In zh, this message translates to:
  /// **'缩进'**
  String get indent;

  /// No description provided for @outdent.
  ///
  /// In zh, this message translates to:
  /// **'缩出'**
  String get outdent;

  /// No description provided for @dueDate.
  ///
  /// In zh, this message translates to:
  /// **'截止日期'**
  String get dueDate;

  /// No description provided for @startDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get startDate;

  /// No description provided for @noTags.
  ///
  /// In zh, this message translates to:
  /// **'暂无标签'**
  String get noTags;

  /// No description provided for @pickDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get pickDate;

  /// No description provided for @pickTime.
  ///
  /// In zh, this message translates to:
  /// **'选择时间'**
  String get pickTime;

  /// No description provided for @moveFailed.
  ///
  /// In zh, this message translates to:
  /// **'移动失败：{reason}'**
  String moveFailed(Object reason);

  /// No description provided for @unsavedChanges.
  ///
  /// In zh, this message translates to:
  /// **'有未保存的更改'**
  String get unsavedChanges;

  /// No description provided for @unsavedChangesConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要离开吗？未保存的更改将丢失。'**
  String get unsavedChangesConfirm;

  /// No description provided for @discard.
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get discard;

  /// No description provided for @keepEditing.
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get keepEditing;

  /// No description provided for @tasksCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个任务'**
  String tasksCount(Object count);

  /// No description provided for @tasksRemaining.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个待完成'**
  String tasksRemaining(Object count);

  /// No description provided for @progress.
  ///
  /// In zh, this message translates to:
  /// **'进度'**
  String get progress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
