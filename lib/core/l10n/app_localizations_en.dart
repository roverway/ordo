// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Todo';

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
  String get emptyInbox => 'All clear! Nothing in your inbox.';

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
  String get nextWeek => 'Next week';

  @override
  String get custom => 'Custom';

  @override
  String get clear => 'Clear';

  @override
  String get collapse => 'Collapse';

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
}
