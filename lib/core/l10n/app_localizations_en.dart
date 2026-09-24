// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ordo';

  @override
  String get inbox => 'Inbox';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navToday => 'Today';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navProjects => 'Projects';

  @override
  String get navTags => 'Tags';

  @override
  String get openDrawer => 'Open sidebar';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get taskGroups => 'Task Groups';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get themeColorBlack => 'Obsidian Black';

  @override
  String get themeColorBlue => 'Klein Blue';

  @override
  String get themeColorEmerald => 'Emerald Green';

  @override
  String get themeColorAmber => 'Amber Orange';

  @override
  String get themeColorPurple => 'Violet Purple';

  @override
  String get themeColorRose => 'Rose Red';

  @override
  String get themeColorTeal => 'Turquoise Teal';

  @override
  String get themeColorSlate => 'Misty Slate';

  @override
  String get language => 'Language';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageEn => 'English';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get aboutVersion => 'Version';

  @override
  String get aboutSlogan => 'Pure order for your daily flow.';

  @override
  String get aboutBrandZhTitle => '知序 (Zhī Xù)';

  @override
  String get aboutBrandZhDesc =>
      '\"Clarify priorities, act with order.\" Emphasizes local data ownership and pure, distraction-free personal flow.';

  @override
  String get aboutBrandEnTitle => 'Ordo';

  @override
  String get aboutBrandEnDesc =>
      'The Latin root for \'order\' — clean, four-letter visual balance designed for clarity and focus.';

  @override
  String get emptyToday => 'No tasks today';

  @override
  String get emptyCalendar => 'Nothing scheduled';

  @override
  String get emptyProjects => 'No projects yet';

  @override
  String get emptyTags => 'No tags yet';

  @override
  String get emptySearch => 'No results found';

  @override
  String get loading => 'Loading…';

  @override
  String get errorLoadFailed => 'Failed to load. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get newProject => 'New Project';

  @override
  String get projectName => 'Project name';

  @override
  String get projectColor => 'Project color';

  @override
  String get projectDescription => 'Project description';

  @override
  String get editProject => 'Edit Project';

  @override
  String get deleteProject => 'Delete Project';

  @override
  String deleteProjectConfirm(Object name) {
    return 'Delete project \"$name\"?';
  }

  @override
  String get deleteProjectWarning =>
      'All tasks in this project will also be deleted. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'New';

  @override
  String get showCompletedTasks => 'Show completed tasks';

  @override
  String get hideCompletedTasks => 'Hide completed tasks';

  @override
  String get allTasksCompleted => 'All tasks completed';

  @override
  String get newTask => 'New Task';

  @override
  String get addTask => 'Add a task';

  @override
  String get newSubtask => 'New Subtask';

  @override
  String get taskTitle => 'Task title';

  @override
  String get taskTitleHint => 'What needs to be done?';

  @override
  String get taskDescription => 'Description';

  @override
  String get taskNotes => 'Notes';

  @override
  String get taskStartTime => 'Start time';

  @override
  String get taskEndTime => 'Due time';

  @override
  String get taskStatus => 'Status';

  @override
  String get taskTags => 'Tags';

  @override
  String get taskProject => 'Project';

  @override
  String get taskParent => 'Parent task';

  @override
  String get statusTodo => 'To Do';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusDone => 'Done';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get titleRequired => 'Title cannot be empty';

  @override
  String nameTooLong(Object max) {
    return 'Name cannot exceed $max characters';
  }

  @override
  String get endTimeBeforeStart => 'Due time cannot be earlier than start time';

  @override
  String get depthLimitExceeded =>
      'Maximum depth (3 levels) reached, cannot create subtask';

  @override
  String get moveDepthExceeded => 'Move would exceed depth limit';

  @override
  String get cannotMoveToSelf => 'Cannot move to itself';

  @override
  String get cannotMoveToDescendant => 'Cannot move to a descendant task';

  @override
  String get deleteTask => 'Delete Task';

  @override
  String deleteTaskConfirm(Object title) {
    return 'Delete task \"$title\"?';
  }

  @override
  String get deleteTaskWarning =>
      'All subtasks will also be deleted. This cannot be undone.';

  @override
  String get emptyProjectDetail => 'No tasks yet, tap below to create one';

  @override
  String get moveUp => 'Move Up';

  @override
  String get moveDown => 'Move Down';

  @override
  String get indent => 'Indent';

  @override
  String get outdent => 'Outdent';

  @override
  String get dueDate => 'Due date';

  @override
  String get startDate => 'Start date';

  @override
  String get noTags => 'No tags';

  @override
  String get pickDate => 'Pick date';

  @override
  String get pickTime => 'Pick time';

  @override
  String moveFailed(Object reason) {
    return 'Move failed: $reason';
  }

  @override
  String get taskUpdateFailed => 'Failed to update task';

  @override
  String get projectRequired => 'Please select a project first';

  @override
  String get statusDerivedFromChildren => 'Status is derived from subtasks';

  @override
  String get rowActions => 'Task actions';

  @override
  String get dropToRoot => 'Drop here to move to top level';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String get unsavedChangesConfirm =>
      'Leave without saving? Your changes will be lost.';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep Editing';

  @override
  String tasksCount(Object count) {
    return '$count tasks';
  }

  @override
  String tasksRemaining(Object count) {
    return '$count remaining';
  }

  @override
  String get progress => 'Progress';

  @override
  String progressPercent(Object percent) {
    return 'Progress $percent%';
  }

  @override
  String relativeStartInDays(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Starts in $days days',
      one: 'Starts in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get noDueDate => 'No due date';

  @override
  String get selectProject => 'Select project';

  @override
  String get done => 'Done';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get overdue => 'Overdue';

  @override
  String get viewMonth => 'Month';

  @override
  String get viewWeek => 'Week';

  @override
  String get prevMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get newTag => 'New Tag';

  @override
  String get editTag => 'Edit Tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get tagColor => 'Tag color';

  @override
  String get deleteTag => 'Delete Tag';

  @override
  String deleteTagConfirm(Object name) {
    return 'Delete tag \"$name\"?';
  }

  @override
  String get deleteTagWarning =>
      'The tag will be removed from all tasks; the tasks themselves are not deleted.';

  @override
  String get searchHint => 'Search title, description, notes…';

  @override
  String get filter => 'Filter';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterAll => 'All';

  @override
  String get filterTag => 'Tag';

  @override
  String get filterTimeRange => 'Time range';

  @override
  String get timeRangeAll => 'Any time';

  @override
  String get timeRangeToday => 'Today';

  @override
  String get timeRangeThisWeek => 'This week';

  @override
  String get timeRangeThisMonth => 'This month';

  @override
  String get clearFilter => 'Clear filter';

  @override
  String get tagNameDuplicate => 'Tag name already exists (case-insensitive)';

  @override
  String get moveTo => 'Move to';

  @override
  String get searchProjects => 'Search projects';

  @override
  String get addProject => 'Add project';

  @override
  String get folder => 'Folder';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get newFolder => 'New Folder';

  @override
  String get renameFolder => 'Rename Folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get folderActions => 'Folder actions';

  @override
  String get deleteFolder => 'Delete Folder';

  @override
  String deleteFolderConfirm(Object name) {
    return 'Delete folder \"$name\"?';
  }

  @override
  String get deleteFolderWarning =>
      'Projects inside will return to Ungrouped; the projects themselves are not deleted.';

  @override
  String get dateAndReminder => 'Date & reminder';

  @override
  String get priority => 'Priority';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNone => 'None';

  @override
  String get thisWeekend => 'This weekend';

  @override
  String get nextWeek => 'Next week';

  @override
  String get custom => 'Custom';

  @override
  String get clear => 'Clear';

  @override
  String get collapse => 'Collapse';

  @override
  String get expand => 'Expand';

  @override
  String get dragReorder => 'Drag to reorder';

  @override
  String get subtasks => 'Subtasks';

  @override
  String get addSubtask => 'Add subtask';

  @override
  String get subtaskHint => 'Subtask title';

  @override
  String get noStartTime => 'No start time';

  @override
  String get attachmentComingSoon => 'Attachments coming soon';

  @override
  String get sync => 'Sync';

  @override
  String get syncSettings => 'Sync settings';

  @override
  String get syncType => 'Remote type';

  @override
  String get syncTypeNutstore => 'Nutstore';

  @override
  String get syncTypeS3 => 'S3-compatible bucket';

  @override
  String get syncEnabled => 'Enable sync';

  @override
  String get syncServerUrl => 'Server URL';

  @override
  String get syncServerUrlHint => 'e.g. https://dav.jianguoyun.com/dav/todo/';

  @override
  String get syncEndpoint => 'Endpoint';

  @override
  String get syncEndpointHint =>
      'e.g. https://<bucket>.r2.cloudflarestorage.com';

  @override
  String get syncUsername => 'Username';

  @override
  String get syncPassword => 'Password';

  @override
  String get syncWebdavPasswordHint =>
      'Use an app password generated in Nutstore security settings';

  @override
  String get syncAccessKey => 'Access Key';

  @override
  String get syncSecretKey => 'Secret Key';

  @override
  String get syncBucket => 'Bucket';

  @override
  String get syncRegion => 'Region';

  @override
  String get syncRegionHint => 'us-east-1 / auto';

  @override
  String get syncPrefix => 'Prefix';

  @override
  String get syncPrefixHint => 'Default: todo/';

  @override
  String get syncAutoOnStart => 'Sync on app start';

  @override
  String get syncAutoOnEdit => 'Sync after edits';

  @override
  String get syncWifiOnly => 'Auto-sync on WiFi only';

  @override
  String get syncWifiOnlyHint => 'Auto-sync only on Wi-Fi; skipped on cellular';

  @override
  String get syncTestConnection => 'Test connection';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncSave => 'Save';

  @override
  String get syncStatusIdle => 'Not synced';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusSuccess => 'Synced';

  @override
  String get syncStatusError => 'Sync failed';

  @override
  String syncLastSyncedAt(Object time) {
    return 'Last synced: $time';
  }

  @override
  String get syncTestOk => 'Connection successful';

  @override
  String syncTestFail(Object reason) {
    return 'Connection failed: $reason';
  }

  @override
  String get syncConfigIncomplete => 'Please fill in the connection details';

  @override
  String get syncClockSkewTitle => 'Clock skew warning';

  @override
  String get syncClockSkewBody =>
      'The remote clock differs significantly from yours. Continue?';

  @override
  String get syncCredsSaved => 'Saved';

  @override
  String get syncSaveFail => 'Save failed';

  @override
  String get syncNotConfigured => 'Sync not configured';

  @override
  String get syncRetryable => 'Will retry automatically';

  @override
  String get syncErrSkippedRunning => 'Sync already in progress';

  @override
  String get syncErrClockSkew =>
      'Device clock skew detected, please calibrate and retry';

  @override
  String get syncErrAuth =>
      'Authentication failed, please check your credentials';

  @override
  String get syncErrNetwork => 'Network error or timeout';

  @override
  String get syncErrRemote => 'Remote server error, please retry later';

  @override
  String get syncErrConfig => 'Invalid sync configuration';

  @override
  String get syncErrSchemaMismatch =>
      'Remote data version incompatible, please update the app';

  @override
  String get syncErrSnapshotCorrupt =>
      'Remote data corrupted, original file kept';

  @override
  String get syncErrUnknown => 'Sync failed, please retry';

  @override
  String get customViews => 'Custom Views';

  @override
  String get newCustomView => 'New View';

  @override
  String get editCustomView => 'Edit View';

  @override
  String get deleteCustomView => 'Delete View';

  @override
  String deleteCustomViewConfirm(String name) {
    return 'Are you sure you want to delete view \"$name\"?';
  }

  @override
  String get viewName => 'View Name';

  @override
  String get viewNameHint => 'Enter view name';

  @override
  String get viewIcon => 'View Icon';

  @override
  String get viewColor => 'View Color';

  @override
  String get viewLayout => 'Layout Mode';

  @override
  String get layoutKanban => 'Kanban Board';

  @override
  String get layoutList => 'List View';

  @override
  String get addPanel => 'Add Panel';

  @override
  String get editPanel => 'Edit Panel';

  @override
  String get deletePanel => 'Delete Panel';

  @override
  String get panelTitle => 'Panel Title';

  @override
  String get panelTitleHint => 'e.g., Todo, High Priority';

  @override
  String get filterCriteria => 'Filter Rules';

  @override
  String get filterByFolder => 'Folder';

  @override
  String get filterByProject => 'Project';

  @override
  String get filterByTag => 'Tags';

  @override
  String get filterByPriority => 'Priority';

  @override
  String get filterByStatus => 'Status';

  @override
  String get filterByDate => 'Date Range';

  @override
  String get filterByHierarchy => 'Task Hierarchy';

  @override
  String get tagMatchAll => 'Match all selected tags (AND)';

  @override
  String get tagMatchAny => 'Match any selected tag (OR)';

  @override
  String get dateScopeAll => 'All Dates';

  @override
  String get dateScopeToday => 'Today';

  @override
  String get dateScopeTomorrow => 'Tomorrow';

  @override
  String get dateScopeThisWeek => 'This Week';

  @override
  String get dateScopeOverdue => 'Overdue';

  @override
  String get dateScopeNoDate => 'No Date';

  @override
  String get hierarchyAll => 'All Tasks';

  @override
  String get hierarchyRootOnly => 'Root Tasks Only';

  @override
  String get hierarchySubtasksOnly => 'Subtasks Only';

  @override
  String get presetTemplates => 'Preset Templates';

  @override
  String get presetStatusKanban => 'Status Kanban (Todo / In Progress / Done)';

  @override
  String get presetPriorityKanban =>
      'Priority Kanban (High / Medium / Low / None)';

  @override
  String get saveAsCustomView => 'Save as View';

  @override
  String get saveAsCustomViewSuccess => 'Saved as custom view successfully';

  @override
  String get noCustomViews => 'No custom views yet';

  @override
  String get noTasksInPanel => 'No matching tasks in panel';

  @override
  String get quickFilter => 'Quick Filter';

  @override
  String get applyFilter => 'Apply Filter';

  @override
  String get resetFilter => 'Reset Filter';

  @override
  String get parentTaskDerivedStatusNotice =>
      'This task has subtasks; status is derived automatically';

  @override
  String get sortBy => 'Sort By';

  @override
  String get sortOrderManual => 'Custom Order';

  @override
  String get sortOrderPriority => 'By Priority';

  @override
  String get sortOrderDueDate => 'By Due Date';

  @override
  String get sortOrderTitle => 'By Title';

  @override
  String get sortAsc => 'Ascending';

  @override
  String get sortDesc => 'Descending';

  @override
  String get treeView => 'Tree View';

  @override
  String get flatView => 'Flat List';

  @override
  String get emptyCustomView => 'No panels configured in this view';

  @override
  String get emptyDayTasks => 'No tasks scheduled for this day';

  @override
  String get prevPeriod => 'Previous Period';

  @override
  String get nextPeriod => 'Next Period';

  @override
  String get switchMonth => 'Select Month';

  @override
  String get moreOptions => 'More Options';

  @override
  String get goToToday => 'Go to Today';

  @override
  String get switchToWeekView => 'Switch to Week View';

  @override
  String get switchToMonthView => 'Switch to Month View';

  @override
  String get calendarScopeDay => 'Day';

  @override
  String get calendarScopeWeek => 'Week';

  @override
  String get calendarScopeMonth => 'Month';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get selectDate => 'Select Date';

  @override
  String projectCount(int count) {
    return '$count projects';
  }

  @override
  String folderCount(int count) {
    return '$count folders';
  }

  @override
  String customViewMoveConfirmMessage(String panelTitle) {
    return 'Moved to panel \"$panelTitle\". Please confirm the attributes to modify:';
  }

  @override
  String customViewModifyStatusTo(String status) {
    return 'Change status to $status';
  }

  @override
  String customViewModifyPriorityTo(String priority) {
    return 'Change priority to $priority';
  }

  @override
  String get customViewModifyProject => 'Change project';

  @override
  String get projectsOverview => 'Overview';

  @override
  String get autoSaveOnClose => 'Auto-save on close';

  @override
  String get taskDetails => 'Task Details';

  @override
  String get createList => 'New List';

  @override
  String get createFolder => 'New Folder';

  @override
  String get listName => 'List Name';

  @override
  String get listNameHint => 'Enter list name...';

  @override
  String get folderNameHint => 'Enter folder name...';

  @override
  String get selectIcon => 'Select Icon';

  @override
  String get instantApply => 'Tap to apply';

  @override
  String get belongingFolder => 'Folder';

  @override
  String get singleChoiceBelonging => 'Single selection';

  @override
  String get noFolderRoot => 'None (Top level)';

  @override
  String listsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists',
      one: '1 list',
    );
    return '$_temp0';
  }

  @override
  String createListSuccess(String name) {
    return 'List \"$name\" created';
  }

  @override
  String createFolderSuccess(String name) {
    return 'Folder \"$name\" created';
  }

  @override
  String get catCommon => 'Common';

  @override
  String get catWork => 'Work';

  @override
  String get catLife => 'Life';

  @override
  String get catStudy => 'Study';

  @override
  String get catHealth => 'Health';

  @override
  String get catFinance => 'Finance';

  @override
  String get colorObsidianBlack => 'Obsidian Black';

  @override
  String get colorKleinBlue => 'Klein Blue';

  @override
  String get colorEmeraldGreen => 'Emerald Green';

  @override
  String get colorAmberOrange => 'Amber Orange';

  @override
  String get colorVioletPurple => 'Violet Purple';

  @override
  String get colorRoseRed => 'Rose Red';

  @override
  String get colorTurquoiseTeal => 'Turquoise Teal';

  @override
  String get colorMistySlate => 'Misty Slate';

  @override
  String get modalThemeColor => 'Theme Color';

  @override
  String get editList => 'Edit List';

  @override
  String get editFolder => 'Edit Folder';

  @override
  String editListSuccess(String name) {
    return 'List \"$name\" updated';
  }

  @override
  String editFolderSuccess(String name) {
    return 'Folder \"$name\" updated';
  }

  @override
  String get addSubtaskHint => 'Add subtask, press enter to confirm';

  @override
  String get noTimeSet => 'No time set';

  @override
  String get titleCannotBeEmpty => 'Title cannot be empty';

  @override
  String saveTaskFailed(String error) {
    return 'Failed to save task: $error';
  }

  @override
  String get overdueSubtitle => 'Overdue';

  @override
  String get completedSubtitle => 'Completed';

  @override
  String get startTime => 'Start time';

  @override
  String get endTime => 'End time';

  @override
  String taskCreatedOn(String date) {
    return 'Created on $date';
  }

  @override
  String taskCompletedOn(String date) {
    return 'Completed on $date';
  }

  @override
  String get searchNoResults => 'No matching tasks';

  @override
  String get noCompletedTasks => 'No completed tasks';

  @override
  String get descriptionHint => 'Add description or notes…';

  @override
  String get notesHint => 'Add notes…';

  @override
  String get notAdded => 'None added';

  @override
  String get notSet => 'Not set';

  @override
  String startPrefix(String time) {
    return 'Start $time';
  }

  @override
  String duePrefix(String time) {
    return 'Due $time';
  }

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String get viewsSection => 'Views';

  @override
  String get listsSection => 'Lists';

  @override
  String get webdavSync => 'WebDAV Sync';

  @override
  String get searchTasks => 'Search tasks';

  @override
  String searchMatchCount(int count) {
    return '$count matching tasks';
  }

  @override
  String progressA11y(String label) {
    return 'Completion progress $label';
  }

  @override
  String get weeklyProgress => 'This week\'s progress';

  @override
  String projectsSummarySubtitle(int total, int pending) {
    return '$total projects · $pending to-dos';
  }

  @override
  String itemsProgress(int done, int total) {
    return '$done/$total items';
  }

  @override
  String manageTagsSubtitle(int count) {
    return 'Manage task tags · $count total';
  }

  @override
  String get autoSync => 'Auto sync';

  @override
  String get autoSyncSubtitle => 'Sync on data changes or app start';

  @override
  String get seedColorSubtitle => 'Give the app an accent color';

  @override
  String get basicInfo => 'Basics';

  @override
  String get displayMode => 'Display as';

  @override
  String get quickTemplates => 'Quick templates';

  @override
  String get statusKanbanDesc => 'To-do / In progress / Done';

  @override
  String get priorityKanbanDesc => 'High / Medium / Low / None';

  @override
  String filterStatusCount(int count) {
    return '$count statuses';
  }

  @override
  String filterPriorityCount(int count) {
    return '$count priorities';
  }

  @override
  String filterProjectCount(int count) {
    return '$count projects';
  }

  @override
  String filterTagCount(int count) {
    return '$count tags';
  }

  @override
  String get allTasksLabel => 'All tasks';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get syncedJustNow => 'Synced just now';

  @override
  String syncedMinutesAgo(int count) {
    return 'Synced $count min ago';
  }

  @override
  String syncedAt(String time) {
    return 'Synced $time';
  }

  @override
  String get monthLabel => 'Month';

  @override
  String get weekLabel => 'Week';

  @override
  String get overview => 'Overview';

  @override
  String get projectLabel => 'Belongs to';

  @override
  String get statusKanbanName => 'Status kanban';

  @override
  String get priorityKanbanName => 'Priority kanban';

  @override
  String get settingsSectionCalendar => 'Calendar';

  @override
  String get showLunar => 'Chinese Lunar Calendar';

  @override
  String get showLunarSubtitle =>
      'Show lunar dates, 24 solar terms, and traditional festivals';

  @override
  String get showHolidays => 'Public Holidays & Workdays';

  @override
  String get showHolidaysSubtitle =>
      'Show official holidays and weekend alternate workdays (Rest / Work)';

  @override
  String get settingsSectionBackup => 'Data & Backup';

  @override
  String get backupExportTitle => 'Export Backup';

  @override
  String get backupExportSubtitle =>
      'Export all data as .ordobak file (excluding credentials)';

  @override
  String get backupExportSuccess => 'Backup exported successfully';

  @override
  String get backupImportTitle => 'Import Backup';

  @override
  String get backupImportSubtitle =>
      'Restore or merge data from a .ordobak file';

  @override
  String get backupSnapshotPoolTitle => 'Local Snapshots';

  @override
  String backupSnapshotPoolSubtitle(int count) {
    return '$count snapshots available for rollback';
  }

  @override
  String get backupRetentionDaysTitle => 'Snapshot Retention';

  @override
  String get backupRetentionDaysSubtitle =>
      'Auto-purges expired snapshots while keeping at least one';

  @override
  String backupRetentionDaysOption(int days) {
    return '$days days';
  }

  @override
  String get backupImportDialogTitle => 'Confirm Backup Import';

  @override
  String backupImportDialogSummary(
    String time,
    int projects,
    int tasks,
    int tags,
    int folders,
    int views,
  ) {
    return 'Exported at: $time\\nContains: $projects projects · $tasks tasks · $tags tags · $folders folders · $views views';
  }

  @override
  String get backupImportModeMerge => 'Merge (Recommended)';

  @override
  String get backupImportModeMergeDesc =>
      'Merges data using LWW timestamp, preserving latest changes on both sides';

  @override
  String get backupImportModeReplace => 'Full Replace';

  @override
  String get backupImportModeReplaceDesc =>
      'Clears current data and restores from backup (a safety snapshot is created beforehand)';

  @override
  String get backupImportAction => 'Import Now';

  @override
  String get backupImportSuccess => 'Data imported successfully';

  @override
  String get backupSnapshotSheetTitle => 'Local Snapshot History';

  @override
  String get backupCreateSnapshotManual => 'New Snapshot';

  @override
  String get backupRestoreAction => 'Restore From Snapshot';

  @override
  String get backupDeleteAction => 'Delete';

  @override
  String get backupSnapshotEmpty => 'No local snapshots yet';

  @override
  String get backupInvalidFile => 'Invalid or corrupted backup file';

  @override
  String backupOperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get backupRestoreButton => 'Restore';

  @override
  String backupSnapshotPoint(String time, String label) {
    return 'Snapshot: $time ($label)';
  }

  @override
  String get snapshotTriggerDaily => 'Daily Auto';

  @override
  String get snapshotTriggerPreSync => 'Pre-sync';

  @override
  String get snapshotTriggerPreRestore => 'Pre-restore';

  @override
  String get snapshotTriggerManual => 'Manual';

  @override
  String get settingsHelp => 'Help & Manual';

  @override
  String get settingsHelpSubtitle => 'Explore Ordo features and user manual';

  @override
  String get manualTOC => 'Table of Contents';

  @override
  String get manualSearchHint => 'Search in manual...';

  @override
  String get manualLanguage => 'Switch Language';

  @override
  String get manualLoading => 'Loading manual...';

  @override
  String get manualLoadFailed => 'Failed to load manual';

  @override
  String get wallpaperTitleApp => 'App Background';

  @override
  String get wallpaperTitleProject => 'List Background';

  @override
  String get wallpaperActive => 'Custom wallpaper active';

  @override
  String get wallpaperDefaultPure => 'Default pure background';

  @override
  String get wallpaperFollowApp => 'Follow app default';

  @override
  String get wallpaperFollow => 'Follow';

  @override
  String get wallpaperNone => 'None';

  @override
  String get wallpaperPresetLabel => 'Presets & Source';

  @override
  String get wallpaperCustomUpload => 'Pick local image';

  @override
  String get wallpaperCustom => 'Local Image';

  @override
  String get wallpaperOpacityLabel => 'Mask Opacity';

  @override
  String get wallpaperBlurLabel => 'Gaussian Blur';

  @override
  String get wallpaperPreviewText => 'Live preview of wallpaper effect';

  @override
  String get wallpaperPreviewBadge => 'Preview';

  @override
  String get navQuadrant => 'Matrix';

  @override
  String get quadrantScopeFilter => 'Scope Filter';

  @override
  String get quadrantAllScopes => 'All Lists & Scopes';

  @override
  String get quadrantUngroupedLists => 'Ungrouped Lists';

  @override
  String get quadrantSelectAll => 'Select All';

  @override
  String get quadrantReset => 'Reset';

  @override
  String get quadrantDone => 'Done';

  @override
  String get quadrantShowCompleted => 'Show Completed Tasks';

  @override
  String get quadrantEmpty => 'No tasks in this quadrant';

  @override
  String get quadrantQ1Title => 'Urgent & Important';

  @override
  String get quadrantQ1Subtitle => 'Do First · Crises & Deadlines';

  @override
  String get quadrantQ2Title => 'Important, Not Urgent';

  @override
  String get quadrantQ2Subtitle => 'Schedule · Planning & Growth';

  @override
  String get quadrantQ3Title => 'Urgent, Not Important';

  @override
  String get quadrantQ3Subtitle => 'Delegate · Interruptions & Busywork';

  @override
  String get quadrantQ4Title => 'Neither Urgent nor Important';

  @override
  String get quadrantQ4Subtitle => 'Don\'t Do · Distractions & Waste';

  @override
  String get quadrantFocusMode => 'Focus Mode';

  @override
  String get quadrantExitFocus => 'Exit Focus';

  @override
  String get quadrantDragHint =>
      'Long press task card to drag into another quadrant';

  @override
  String quadrantSummarySubtitle(int count) {
    return '4 Quadrants · $count Tasks';
  }

  @override
  String get quadrantViewMatrix => '2x2 Matrix';

  @override
  String get quadrantViewList => 'Focus List';

  @override
  String get quadrantAllProjects => 'All Projects';

  @override
  String get quadrantTabAll => 'All';

  @override
  String get quadrantAddTask => 'Add Task';

  @override
  String get quadrantListEmpty => 'No tasks in this quadrant';
}
