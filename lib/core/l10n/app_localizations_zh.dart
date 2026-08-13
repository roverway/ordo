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
  String get inbox => '收件箱';

  @override
  String get navInbox => '收件箱';

  @override
  String get navToday => '今日';

  @override
  String get navCalendar => '日历';

  @override
  String get navProjects => '项目';

  @override
  String get navTags => '标签';

  @override
  String get openDrawer => '打开侧边栏';

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
  String get loading => '加载中…';

  @override
  String get errorLoadFailed => '加载失败，请稍后重试';

  @override
  String get retry => '重试';

  @override
  String get newProject => '新建项目';

  @override
  String get projectName => '项目名称';

  @override
  String get projectColor => '项目颜色';

  @override
  String get projectDescription => '项目描述';

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
  String get addTask => '添加任务';

  @override
  String get newSubtask => '新建子任务';

  @override
  String get taskTitle => '任务标题';

  @override
  String get taskTitleHint => '要做什么？';

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
  String nameTooLong(Object max) {
    return '名称不能超过 $max 个字符';
  }

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
  String get projectRequired => '请先选择所属项目';

  @override
  String get statusDerivedFromChildren => '状态由子任务派生';

  @override
  String get rowActions => '任务操作';

  @override
  String get dropToRoot => '拖到此处回到 1 级';

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

  @override
  String progressPercent(Object percent) {
    return '进度 $percent%';
  }

  @override
  String get noDueDate => '无截止日期';

  @override
  String get selectProject => '选择项目';

  @override
  String get done => '完成';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get overdue => '已逾期';

  @override
  String get viewMonth => '月视图';

  @override
  String get viewWeek => '周视图';

  @override
  String get prevMonth => '上个月';

  @override
  String get nextMonth => '下个月';

  @override
  String get newTag => '新建标签';

  @override
  String get editTag => '编辑标签';

  @override
  String get tagName => '标签名称';

  @override
  String get tagColor => '标签颜色';

  @override
  String get deleteTag => '删除标签';

  @override
  String deleteTagConfirm(Object name) {
    return '确定要删除标签「$name」吗？';
  }

  @override
  String get deleteTagWarning => '该标签将从所有任务中移除，任务本身不会被删除。';

  @override
  String get searchHint => '搜索标题、描述、备注…';

  @override
  String get filter => '筛选';

  @override
  String get filterStatus => '状态';

  @override
  String get filterAll => '全部';

  @override
  String get filterTag => '标签';

  @override
  String get filterTimeRange => '时间段';

  @override
  String get timeRangeAll => '全部时间';

  @override
  String get timeRangeToday => '今天';

  @override
  String get timeRangeThisWeek => '本周';

  @override
  String get timeRangeThisMonth => '本月';

  @override
  String get clearFilter => '清除筛选';

  @override
  String get tagNameDuplicate => '标签名已存在（不区分大小写）';

  @override
  String get moveTo => '移动到';

  @override
  String get searchProjects => '搜索项目';

  @override
  String get addProject => '添加项目';

  @override
  String get dateAndReminder => '日期与提醒';

  @override
  String get priority => '优先级';

  @override
  String get priorityHigh => '高';

  @override
  String get priorityMedium => '中';

  @override
  String get priorityLow => '低';

  @override
  String get priorityNone => '无';

  @override
  String get nextWeek => '下周';

  @override
  String get custom => '自定义';

  @override
  String get clear => '清除';

  @override
  String get collapse => '收起';

  @override
  String get expand => '展开';

  @override
  String get dragReorder => '拖拽排序';

  @override
  String get subtasks => '子任务';

  @override
  String get addSubtask => '添加子任务';

  @override
  String get subtaskHint => '子任务标题';

  @override
  String get noStartTime => '无开始时间';

  @override
  String get attachmentComingSoon => '附件功能即将推出';

  @override
  String get sync => '同步';

  @override
  String get syncSettings => '同步设置';

  @override
  String get syncType => '远端类型';

  @override
  String get syncTypeWebdav => 'WebDAV';

  @override
  String get syncTypeS3 => 'S3 兼容桶';

  @override
  String get syncEnabled => '启用同步';

  @override
  String get syncServerUrl => '服务器地址';

  @override
  String get syncServerUrlHint => '如 https://dav.example.com/todo/';

  @override
  String get syncEndpoint => 'Endpoint';

  @override
  String get syncEndpointHint => '如 https://<bucket>.r2.cloudflarestorage.com';

  @override
  String get syncUsername => '用户名';

  @override
  String get syncPassword => '密码';

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
  String get syncPrefixHint => '默认 todo/';

  @override
  String get syncAutoOnStart => '启动时自动同步';

  @override
  String get syncAutoOnEdit => '编辑后自动同步';

  @override
  String get syncWifiOnly => '仅 WiFi 时自动同步';

  @override
  String get syncWifiOnlyHint => '仅 WiFi 时自动同步，蜂窝网络下自动同步将被跳过';

  @override
  String get syncTestConnection => '测试连接';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncSave => '保存';

  @override
  String get syncStatusIdle => '未同步';

  @override
  String get syncStatusSyncing => '同步中…';

  @override
  String get syncStatusSuccess => '已同步';

  @override
  String get syncStatusError => '同步失败';

  @override
  String syncLastSyncedAt(Object time) {
    return '上次同步：$time';
  }

  @override
  String get syncTestOk => '连接成功';

  @override
  String syncTestFail(Object reason) {
    return '连接失败：$reason';
  }

  @override
  String get syncConfigIncomplete => '请填写完整的连接信息';

  @override
  String get syncClockSkewTitle => '时间偏差提醒';

  @override
  String get syncClockSkewBody => '远端时间与本地相差较大，是否继续同步？';

  @override
  String get syncCredsSaved => '已保存';

  @override
  String get syncSaveFail => '保存失败';

  @override
  String get syncNotConfigured => '尚未配置同步';

  @override
  String get syncRetryable => '将自动重试';

  @override
  String get syncErrSkippedRunning => '同步进行中，本次触发已跳过';

  @override
  String get syncErrClockSkew => '检测到设备时间偏差，请校准后重试';

  @override
  String get syncErrAuth => '认证失败，请检查账号与密码';

  @override
  String get syncErrNetwork => '网络连接失败或超时';

  @override
  String get syncErrRemote => '远端服务器错误，请稍后重试';

  @override
  String get syncErrConfig => '同步配置无效，请检查设置';

  @override
  String get syncErrSchemaMismatch => '远端数据版本不兼容，请升级应用';

  @override
  String get syncErrSnapshotCorrupt => '远端数据异常，已保留原文件';

  @override
  String get syncErrUnknown => '同步失败，请重试';
}
