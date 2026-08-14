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

  /// No description provided for @inbox.
  ///
  /// In zh, this message translates to:
  /// **'收件箱'**
  String get inbox;

  /// No description provided for @navInbox.
  ///
  /// In zh, this message translates to:
  /// **'收件箱'**
  String get navInbox;

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

  /// No description provided for @openDrawer.
  ///
  /// In zh, this message translates to:
  /// **'打开侧边栏'**
  String get openDrawer;

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

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// No description provided for @errorLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败，请稍后重试'**
  String get errorLoadFailed;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

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

  /// No description provided for @projectDescription.
  ///
  /// In zh, this message translates to:
  /// **'项目描述'**
  String get projectDescription;

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

  /// No description provided for @showCompletedTasks.
  ///
  /// In zh, this message translates to:
  /// **'显示已完成任务'**
  String get showCompletedTasks;

  /// No description provided for @hideCompletedTasks.
  ///
  /// In zh, this message translates to:
  /// **'隐藏已完成任务'**
  String get hideCompletedTasks;

  /// No description provided for @allTasksCompleted.
  ///
  /// In zh, this message translates to:
  /// **'全部任务已完成'**
  String get allTasksCompleted;

  /// No description provided for @newTask.
  ///
  /// In zh, this message translates to:
  /// **'新建任务'**
  String get newTask;

  /// No description provided for @addTask.
  ///
  /// In zh, this message translates to:
  /// **'添加任务'**
  String get addTask;

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

  /// No description provided for @taskTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'要做什么？'**
  String get taskTitleHint;

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

  /// No description provided for @nameTooLong.
  ///
  /// In zh, this message translates to:
  /// **'名称不能超过 {max} 个字符'**
  String nameTooLong(Object max);

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

  /// No description provided for @projectRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先选择所属项目'**
  String get projectRequired;

  /// No description provided for @statusDerivedFromChildren.
  ///
  /// In zh, this message translates to:
  /// **'状态由子任务派生'**
  String get statusDerivedFromChildren;

  /// No description provided for @rowActions.
  ///
  /// In zh, this message translates to:
  /// **'任务操作'**
  String get rowActions;

  /// No description provided for @dropToRoot.
  ///
  /// In zh, this message translates to:
  /// **'拖到此处回到 1 级'**
  String get dropToRoot;

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

  /// No description provided for @progressPercent.
  ///
  /// In zh, this message translates to:
  /// **'进度 {percent}%'**
  String progressPercent(Object percent);

  /// No description provided for @relativeStartInDays.
  ///
  /// In zh, this message translates to:
  /// **'{days, plural, =1 {距开始 1 天} other {距开始 {days} 天}}'**
  String relativeStartInDays(num days);

  /// No description provided for @noDueDate.
  ///
  /// In zh, this message translates to:
  /// **'无截止日期'**
  String get noDueDate;

  /// No description provided for @selectProject.
  ///
  /// In zh, this message translates to:
  /// **'选择项目'**
  String get selectProject;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get tomorrow;

  /// No description provided for @overdue.
  ///
  /// In zh, this message translates to:
  /// **'已逾期'**
  String get overdue;

  /// No description provided for @viewMonth.
  ///
  /// In zh, this message translates to:
  /// **'月视图'**
  String get viewMonth;

  /// No description provided for @viewWeek.
  ///
  /// In zh, this message translates to:
  /// **'周视图'**
  String get viewWeek;

  /// No description provided for @prevMonth.
  ///
  /// In zh, this message translates to:
  /// **'上个月'**
  String get prevMonth;

  /// No description provided for @nextMonth.
  ///
  /// In zh, this message translates to:
  /// **'下个月'**
  String get nextMonth;

  /// No description provided for @newTag.
  ///
  /// In zh, this message translates to:
  /// **'新建标签'**
  String get newTag;

  /// No description provided for @editTag.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get editTag;

  /// No description provided for @tagName.
  ///
  /// In zh, this message translates to:
  /// **'标签名称'**
  String get tagName;

  /// No description provided for @tagColor.
  ///
  /// In zh, this message translates to:
  /// **'标签颜色'**
  String get tagColor;

  /// No description provided for @deleteTag.
  ///
  /// In zh, this message translates to:
  /// **'删除标签'**
  String get deleteTag;

  /// No description provided for @deleteTagConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除标签「{name}」吗？'**
  String deleteTagConfirm(Object name);

  /// No description provided for @deleteTagWarning.
  ///
  /// In zh, this message translates to:
  /// **'该标签将从所有任务中移除，任务本身不会被删除。'**
  String get deleteTagWarning;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索标题、描述、备注…'**
  String get searchHint;

  /// No description provided for @filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filter;

  /// No description provided for @filterStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get filterStatus;

  /// No description provided for @filterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get filterAll;

  /// No description provided for @filterTag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get filterTag;

  /// No description provided for @filterTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'时间段'**
  String get filterTimeRange;

  /// No description provided for @timeRangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部时间'**
  String get timeRangeAll;

  /// No description provided for @timeRangeToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get timeRangeToday;

  /// No description provided for @timeRangeThisWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get timeRangeThisWeek;

  /// No description provided for @timeRangeThisMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get timeRangeThisMonth;

  /// No description provided for @clearFilter.
  ///
  /// In zh, this message translates to:
  /// **'清除筛选'**
  String get clearFilter;

  /// No description provided for @tagNameDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'标签名已存在（不区分大小写）'**
  String get tagNameDuplicate;

  /// No description provided for @moveTo.
  ///
  /// In zh, this message translates to:
  /// **'移动到'**
  String get moveTo;

  /// No description provided for @searchProjects.
  ///
  /// In zh, this message translates to:
  /// **'搜索项目'**
  String get searchProjects;

  /// No description provided for @addProject.
  ///
  /// In zh, this message translates to:
  /// **'添加项目'**
  String get addProject;

  /// No description provided for @folder.
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get folder;

  /// No description provided for @ungrouped.
  ///
  /// In zh, this message translates to:
  /// **'未分组'**
  String get ungrouped;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @renameFolder.
  ///
  /// In zh, this message translates to:
  /// **'重命名文件夹'**
  String get renameFolder;

  /// No description provided for @folderName.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get folderName;

  /// No description provided for @folderActions.
  ///
  /// In zh, this message translates to:
  /// **'文件夹操作'**
  String get folderActions;

  /// No description provided for @deleteFolder.
  ///
  /// In zh, this message translates to:
  /// **'删除文件夹'**
  String get deleteFolder;

  /// No description provided for @deleteFolderConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除文件夹「{name}」吗？'**
  String deleteFolderConfirm(Object name);

  /// No description provided for @deleteFolderWarning.
  ///
  /// In zh, this message translates to:
  /// **'其中的项目将回到未分组，项目本身不会被删除。'**
  String get deleteFolderWarning;

  /// No description provided for @dateAndReminder.
  ///
  /// In zh, this message translates to:
  /// **'日期与提醒'**
  String get dateAndReminder;

  /// No description provided for @priority.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get priority;

  /// No description provided for @priorityHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get priorityHigh;

  /// No description provided for @priorityMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get priorityMedium;

  /// No description provided for @priorityLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get priorityLow;

  /// No description provided for @priorityNone.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get priorityNone;

  /// No description provided for @nextWeek.
  ///
  /// In zh, this message translates to:
  /// **'下周'**
  String get nextWeek;

  /// No description provided for @custom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get custom;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @dragReorder.
  ///
  /// In zh, this message translates to:
  /// **'拖拽排序'**
  String get dragReorder;

  /// No description provided for @subtasks.
  ///
  /// In zh, this message translates to:
  /// **'子任务'**
  String get subtasks;

  /// No description provided for @addSubtask.
  ///
  /// In zh, this message translates to:
  /// **'添加子任务'**
  String get addSubtask;

  /// No description provided for @subtaskHint.
  ///
  /// In zh, this message translates to:
  /// **'子任务标题'**
  String get subtaskHint;

  /// No description provided for @noStartTime.
  ///
  /// In zh, this message translates to:
  /// **'无开始时间'**
  String get noStartTime;

  /// No description provided for @attachmentComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'附件功能即将推出'**
  String get attachmentComingSoon;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @syncSettings.
  ///
  /// In zh, this message translates to:
  /// **'同步设置'**
  String get syncSettings;

  /// No description provided for @syncType.
  ///
  /// In zh, this message translates to:
  /// **'远端类型'**
  String get syncType;

  /// No description provided for @syncTypeWebdav.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV'**
  String get syncTypeWebdav;

  /// No description provided for @syncTypeS3.
  ///
  /// In zh, this message translates to:
  /// **'S3 兼容桶'**
  String get syncTypeS3;

  /// No description provided for @syncEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用同步'**
  String get syncEnabled;

  /// No description provided for @syncServerUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get syncServerUrl;

  /// No description provided for @syncServerUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'如 https://dav.example.com/todo/'**
  String get syncServerUrlHint;

  /// No description provided for @syncEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'Endpoint'**
  String get syncEndpoint;

  /// No description provided for @syncEndpointHint.
  ///
  /// In zh, this message translates to:
  /// **'如 https://<bucket>.r2.cloudflarestorage.com'**
  String get syncEndpointHint;

  /// No description provided for @syncUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get syncUsername;

  /// No description provided for @syncPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get syncPassword;

  /// No description provided for @syncAccessKey.
  ///
  /// In zh, this message translates to:
  /// **'Access Key'**
  String get syncAccessKey;

  /// No description provided for @syncSecretKey.
  ///
  /// In zh, this message translates to:
  /// **'Secret Key'**
  String get syncSecretKey;

  /// No description provided for @syncBucket.
  ///
  /// In zh, this message translates to:
  /// **'Bucket'**
  String get syncBucket;

  /// No description provided for @syncRegion.
  ///
  /// In zh, this message translates to:
  /// **'Region'**
  String get syncRegion;

  /// No description provided for @syncRegionHint.
  ///
  /// In zh, this message translates to:
  /// **'us-east-1 / auto'**
  String get syncRegionHint;

  /// No description provided for @syncPrefix.
  ///
  /// In zh, this message translates to:
  /// **'Prefix'**
  String get syncPrefix;

  /// No description provided for @syncPrefixHint.
  ///
  /// In zh, this message translates to:
  /// **'默认 todo/'**
  String get syncPrefixHint;

  /// No description provided for @syncAutoOnStart.
  ///
  /// In zh, this message translates to:
  /// **'启动时自动同步'**
  String get syncAutoOnStart;

  /// No description provided for @syncAutoOnEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑后自动同步'**
  String get syncAutoOnEdit;

  /// No description provided for @syncWifiOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅 WiFi 时自动同步'**
  String get syncWifiOnly;

  /// No description provided for @syncWifiOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'仅 WiFi 时自动同步，蜂窝网络下自动同步将被跳过'**
  String get syncWifiOnlyHint;

  /// No description provided for @syncTestConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get syncTestConnection;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @syncSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get syncSave;

  /// No description provided for @syncStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'未同步'**
  String get syncStatusIdle;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get syncStatusSuccess;

  /// No description provided for @syncStatusError.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncStatusError;

  /// No description provided for @syncLastSyncedAt.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String syncLastSyncedAt(Object time);

  /// No description provided for @syncTestOk.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get syncTestOk;

  /// No description provided for @syncTestFail.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{reason}'**
  String syncTestFail(Object reason);

  /// No description provided for @syncConfigIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'请填写完整的连接信息'**
  String get syncConfigIncomplete;

  /// No description provided for @syncClockSkewTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间偏差提醒'**
  String get syncClockSkewTitle;

  /// No description provided for @syncClockSkewBody.
  ///
  /// In zh, this message translates to:
  /// **'远端时间与本地相差较大，是否继续同步？'**
  String get syncClockSkewBody;

  /// No description provided for @syncCredsSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get syncCredsSaved;

  /// No description provided for @syncSaveFail.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get syncSaveFail;

  /// No description provided for @syncNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置同步'**
  String get syncNotConfigured;

  /// No description provided for @syncRetryable.
  ///
  /// In zh, this message translates to:
  /// **'将自动重试'**
  String get syncRetryable;

  /// No description provided for @syncErrSkippedRunning.
  ///
  /// In zh, this message translates to:
  /// **'同步进行中，本次触发已跳过'**
  String get syncErrSkippedRunning;

  /// No description provided for @syncErrClockSkew.
  ///
  /// In zh, this message translates to:
  /// **'检测到设备时间偏差，请校准后重试'**
  String get syncErrClockSkew;

  /// No description provided for @syncErrAuth.
  ///
  /// In zh, this message translates to:
  /// **'认证失败，请检查账号与密码'**
  String get syncErrAuth;

  /// No description provided for @syncErrNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败或超时'**
  String get syncErrNetwork;

  /// No description provided for @syncErrRemote.
  ///
  /// In zh, this message translates to:
  /// **'远端服务器错误，请稍后重试'**
  String get syncErrRemote;

  /// No description provided for @syncErrConfig.
  ///
  /// In zh, this message translates to:
  /// **'同步配置无效，请检查设置'**
  String get syncErrConfig;

  /// No description provided for @syncErrSchemaMismatch.
  ///
  /// In zh, this message translates to:
  /// **'远端数据版本不兼容，请升级应用'**
  String get syncErrSchemaMismatch;

  /// No description provided for @syncErrSnapshotCorrupt.
  ///
  /// In zh, this message translates to:
  /// **'远端数据异常，已保留原文件'**
  String get syncErrSnapshotCorrupt;

  /// No description provided for @syncErrUnknown.
  ///
  /// In zh, this message translates to:
  /// **'同步失败，请重试'**
  String get syncErrUnknown;
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
