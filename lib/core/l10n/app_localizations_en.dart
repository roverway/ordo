// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Ordo';

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
  String get themeColorClassic => 'Classic Iris';

  @override
  String get themeColorOcean => 'Ocean Sky';

  @override
  String get themeColorPine => 'Emerald Pine';

  @override
  String get themeColorAmber => 'Warm Amber';

  @override
  String get themeColorRose => 'Crimson Rose';

  @override
  String get themeColorLavender => 'Lavender Violet';

  @override
  String get themeColorPink => 'Berry Pink';

  @override
  String get themeColorSlate => 'Slate Obsidian';

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
  String get syncServerUrlHint => 'e.g. https://dav.jianguoyun.com/dav/';

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
}
