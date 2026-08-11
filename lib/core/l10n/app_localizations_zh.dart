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

  @override
  String get newProject => '新建项目';

  @override
  String get projectName => '项目名称';

  @override
  String get projectColor => '项目颜色';

  @override
  String get editProject => '编辑项目';

  @override
  String get deleteProject => '删除项目';

  @override
  String deleteProjectConfirm(Object name) {
    return '确定要删除项目「$name」吗？';
  }

  @override
  String get deleteProjectWarning => '该项目下的所有任务也会被删除，此操作不可撤销。';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get newTask => '新建任务';

  @override
  String get newSubtask => '新建子任务';

  @override
  String get taskTitle => '任务标题';

  @override
  String get taskDescription => '描述';

  @override
  String get taskNotes => '备注';

  @override
  String get taskStartTime => '开始时间';

  @override
  String get taskEndTime => '截止时间';

  @override
  String get taskStatus => '状态';

  @override
  String get taskTags => '标签';

  @override
  String get taskProject => '所属项目';

  @override
  String get taskParent => '父任务';

  @override
  String get statusTodo => '待办';

  @override
  String get statusInProgress => '进行中';

  @override
  String get statusDone => '已完成';

  @override
  String get statusCancelled => '已取消';

  @override
  String get titleRequired => '标题不能为空';

  @override
  String get endTimeBeforeStart => '截止时间不能早于开始时间';

  @override
  String get depthLimitExceeded => '已达到最大层级（3级），无法创建子任务';

  @override
  String get moveDepthExceeded => '移动后层级超过上限';

  @override
  String get cannotMoveToSelf => '不能移动到自身';

  @override
  String get cannotMoveToDescendant => '不能移动到自身的子任务下';

  @override
  String get deleteTask => '删除任务';

  @override
  String deleteTaskConfirm(Object title) {
    return '确定要删除任务「$title」吗？';
  }

  @override
  String get deleteTaskWarning => '该任务的子任务也会被删除，此操作不可撤销。';

  @override
  String get emptyProjectDetail => '还没有任务，点击下方按钮新建';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get indent => '缩进';

  @override
  String get outdent => '缩出';

  @override
  String get dueDate => '截止日期';

  @override
  String get startDate => '开始日期';

  @override
  String get noTags => '暂无标签';

  @override
  String get pickDate => '选择日期';

  @override
  String get pickTime => '选择时间';

  @override
  String moveFailed(Object reason) {
    return '移动失败：$reason';
  }

  @override
  String get unsavedChanges => '有未保存的更改';

  @override
  String get unsavedChangesConfirm => '确定要离开吗？未保存的更改将丢失。';

  @override
  String get discard => '放弃';

  @override
  String get keepEditing => '继续编辑';

  @override
  String tasksCount(Object count) {
    return '$count 个任务';
  }

  @override
  String tasksRemaining(Object count) {
    return '$count 个待完成';
  }

  @override
  String get progress => '进度';
}
