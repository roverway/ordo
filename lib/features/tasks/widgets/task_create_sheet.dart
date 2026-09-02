// 新建任务底部弹窗（高保真还原设计稿 screens_create.html + 补齐结束时间设置按钮）。
//
// 包含：
// 1. 顶部抓手 + 标题栏（关闭 X / 居中标题 / 保存按钮）
// 2. 标题输入（带空标题校验摇晃动画与错误提示） + 备注输入
// 3. 选项胶囊栏（项目选择器 + 开始时间设置 + 结束时间/截止时间设置）
// 4. 优先级分段选择（无/低/中/高 带彩色圆点）
// 5. 标签选择行 + 内联新建标签输入
// 6. 子任务列表（带复选框、删除按钮及回车即添加新行）
// 7. 底部信息栏（关闭时自动保存开关 + 当前配置摘要）

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/motion.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';
import '../task_providers.dart';
import 'task_editor/project_picker_sheet.dart';
import 'task_editor/task_date_picker_dialogs.dart';

/// 新建任务底部弹窗。
class TaskCreateSheet extends ConsumerStatefulWidget {
  const TaskCreateSheet({
    super.key,
    this.projectId,
    this.parentId,
    this.initialStartAt,
    this.initialEndAt,
    this.initialPriority,
    this.initialTagIds,
  });

  final String? projectId;
  final String? parentId;

  /// 预填开始/截止时间（UTC 毫秒，日历「点日期新建」传入）。
  final int? initialStartAt;
  final int? initialEndAt;

  /// 预填优先级（看板/筛选列「按优先级筛选」传入）。
  final TaskPriority? initialPriority;

  /// 预填关联标签（看板/筛选列「按标签筛选」传入）。
  final List<String>? initialTagIds;

  /// 打开新建任务底部弹窗。
  static Future<void> show(
    BuildContext context, {
    String? projectId,
    String? parentId,
    int? initialStartAt,
    int? initialEndAt,
    TaskPriority? initialPriority,
    List<String>? initialTagIds,
  }) {
    final notifier = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(taskFormProvider.notifier);
    notifier.resetForNew(projectId ?? inboxProjectId, parentId);
    if (initialStartAt != null) notifier.updateStartAt(initialStartAt);
    if (initialEndAt != null) notifier.updateEndAt(initialEndAt);
    if (initialPriority != null) notifier.updatePriority(initialPriority);
    if (initialTagIds != null && initialTagIds.isNotEmpty) {
      notifier.setSelectedTags(initialTagIds);
    }

    final sheetTheme = Theme.of(context).bottomSheetTheme;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      sheetAnimationStyle: AnimationStyle(
        duration: motionSlow(context),
        reverseDuration: motionSlow(context),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation:
          sheetTheme.modalElevation ??
          sheetTheme.elevation ??
          AppTokens.elevationCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        return KeyboardInsetBuilder(
          child: RepaintBoundary(
            child: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: sheetContext,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: TaskCreateSheet(
                  projectId: projectId,
                  parentId: parentId,
                  initialStartAt: initialStartAt,
                  initialEndAt: initialEndAt,
                  initialPriority: initialPriority,
                  initialTagIds: initialTagIds,
                ),
              ),
            ),
          ),
          builder: (context, effectiveInset, bottomGap, sheetChild) {
            return Padding(
              padding: EdgeInsets.only(bottom: effectiveInset + bottomGap),
              child: sheetChild!,
            );
          },
        );
      },
    );
  }

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _SubtaskItem {
  _SubtaskItem({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;
  bool isDone = false;
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _newTagController = TextEditingController();
  final _newTagFocusNode = FocusNode();
  final List<_SubtaskItem> _subtaskRows = [];

  bool _isSaving = false;
  bool _allowPop = false;
  bool _autoSaveOnClose = true;
  String? _titleError;

  // 内联创建新标签状态
  bool _showInlineTagCreator = false;
  int _selectedTagColor = 0xFF4A6CF7;
  final List<int> _presetTagColors = const [
    0xFF4A6CF7,
    0xFF10B981,
    0xFF8B5CF6,
    0xFFF59E0B,
    0xFFEF4444,
  ];

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _titleFocusNode.addListener(_onFocusChange);
    _descriptionFocusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initForm();
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  void _addSubtaskAndFocus() {
    setState(() {
      final ctrl = TextEditingController();
      final focusNode = FocusNode()..addListener(_onFocusChange);
      _subtaskRows.add(_SubtaskItem(controller: ctrl, focusNode: focusNode));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusNode.requestFocus();
      });
    });
  }

  void _initForm() {
    final notifier = ref.read(taskFormProvider.notifier);
    notifier.resetForNew(widget.projectId ?? 'inbox', widget.parentId);
    if (widget.initialStartAt != null) {
      notifier.updateStartAt(widget.initialStartAt);
    }
    if (widget.initialEndAt != null) {
      notifier.updateEndAt(widget.initialEndAt);
    }
    if (widget.initialPriority != null) {
      notifier.updatePriority(widget.initialPriority!);
    }
    if (widget.initialTagIds != null && widget.initialTagIds!.isNotEmpty) {
      notifier.setSelectedTags(widget.initialTagIds!);
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onFocusChange);
    _descriptionFocusNode.removeListener(_onFocusChange);
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _newTagController.dispose();
    _newTagFocusNode.dispose();
    _shakeController.dispose();
    for (final row in _subtaskRows) {
      row.focusNode.removeListener(_onFocusChange);
      row.controller.dispose();
      row.focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final startAt = ref.watch(taskFormProvider.select((s) => s.startAt));
    final endAt = ref.watch(taskFormProvider.select((s) => s.endAt));
    final priority = ref.watch(taskFormProvider.select((s) => s.priority));
    final selectedTagIds = ref.watch(
      taskFormProvider.select((s) => s.selectedTagIds),
    );
    final projectId = ref.watch(taskFormProvider.select((s) => s.projectId));
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final currentProject = projects.where((p) => p.id == projectId).firstOrNull;
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 顶部拖拽手柄 ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── 顶部栏：关闭 X / 标题 / 保存 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _saveAndClose,
                ),
                Text(
                  l10n.newTask,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                TextButton(
                  onPressed: _saveAndCloseExplicit,
                  child: Text(
                    l10n.save,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ── 可滚动主体内容 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 标题输入框（无边框无背景，按需编辑）
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final offset =
                        math.sin(_shakeAnimation.value * math.pi * 4) * 6;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: true,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.taskTitle,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    onChanged: (v) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                      ref.read(taskFormProvider.notifier).updateTitle(v);
                    },
                  ),
                ),

                if (_titleError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _titleError!,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. 备注/描述输入框（无边框无背景）
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocusNode,
                  maxLines: 3,
                  minLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.5,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: '添加备注…',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.45,
                      ),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (v) =>
                      ref.read(taskFormProvider.notifier).updateDescription(v),
                ),

                const SizedBox(height: 16),

                // 3. 胶囊选项栏（项目 + 开始时间 + 结束时间）
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 项目 Pill
                      _buildPillButton(
                        onTap: () => showTaskProjectPicker(context, ref),
                        leading: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: currentProject != null
                                ? Color(currentProject.color)
                                : AppTokens.colorCancelled,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: currentProject?.name ?? l10n.inbox,
                        hasValue: currentProject != null,
                      ),

                      const SizedBox(width: 8),

                      // 开始时间 Pill (带有 Calendar 图标)
                      _buildTimePillWithMenu(
                        isStart: true,
                        currentValue: startAt,
                        label: startAt != null
                            ? '开始 ${formatTaskTimeDisplay(startAt, null, l10n)}'
                            : '开始时间',
                        icon: Icons.calendar_today_outlined,
                      ),

                      const SizedBox(width: 8),

                      // 结束时间 / 截止时间 Pill（补齐设计稿遗漏的结束时间按钮）
                      _buildTimePillWithMenu(
                        isStart: false,
                        currentValue: endAt,
                        label: endAt != null
                            ? '截止 ${formatTaskTimeDisplay(null, endAt, l10n)}'
                            : '结束时间',
                        icon: Icons.flag_outlined,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. 优先级选择（文字与分段控制同一行）
                Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        l10n.priority,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colorScheme.onSurface.withValues(alpha: 0.06)
                              : const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            for (final p in TaskPriority.values)
                              Expanded(
                                child: _buildPrioritySegmentItem(
                                  priority: p,
                                  isSelected: priority == p,
                                  onTap: () => ref
                                      .read(taskFormProvider.notifier)
                                      .updatePriority(p),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 5. 标签行 + 内联新建标签（文字与标签在同一行）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: 52,
                        child: Text(
                          l10n.taskTags,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final tag in tags)
                            _buildTagPill(
                              tag: tag,
                              isSelected: selectedTagIds.contains(tag.id),
                              onTap: () {
                                final current = [...selectedTagIds];
                                if (current.contains(tag.id)) {
                                  current.remove(tag.id);
                                } else {
                                  current.add(tag.id);
                                }
                                ref
                                    .read(taskFormProvider.notifier)
                                    .setSelectedTags(current);
                              },
                            ),

                          // + 新建标签 按钮
                          GestureDetector(
                            onTap: () => setState(
                              () => _showInlineTagCreator =
                                  !_showInlineTagCreator,
                            ),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '新建标签',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 内联新建标签展开区
                if (_showInlineTagCreator) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            )
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTagController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: '标签名',
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _createInlineTag(),
                          ),
                        ),
                        // 预设颜色圆点
                        for (final c in _presetTagColors)
                          GestureDetector(
                            onTap: () => setState(() => _selectedTagColor = c),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedTagColor == c
                                      ? colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _createInlineTag,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '添加',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 6. 子任务区（精确复刻 create.html）
                if (widget.parentId == null) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 18, bottom: 4),
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: borderColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          l10n.subtasks,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        if (_subtaskRows.isNotEmpty)
                          Text(
                            '${_subtaskRows.length} 项',
                            style: TextStyle(
                              fontSize: 11,
                              fontFeatures: AppTokens.fontTabular,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 已添加的子任务列表
                  for (var i = 0; i < _subtaskRows.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: borderColor.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() {
                              _subtaskRows[i].isDone = !_subtaskRows[i].isDone;
                            }),
                            child: Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: _subtaskRows[i].isDone
                                    ? colorScheme.onSurface
                                    : colorScheme.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _subtaskRows[i].isDone
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface.withValues(
                                          alpha: 0.34,
                                        ),
                                  width: 1.5,
                                ),
                              ),
                              child: _subtaskRows[i].isDone
                                  ? Icon(
                                      Icons.check,
                                      size: 11,
                                      color: colorScheme.surface,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child:
                                _subtaskRows[i].controller.text.isNotEmpty &&
                                    !_subtaskRows[i].focusNode.hasFocus
                                ? GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      _subtaskRows[i].focusNode.requestFocus();
                                    },
                                    child: Text(
                                      _subtaskRows[i].controller.text,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                        decoration: _subtaskRows[i].isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: _subtaskRows[i].isDone
                                            ? colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.6)
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  )
                                : TextField(
                                    controller: _subtaskRows[i].controller,
                                    focusNode: _subtaskRows[i].focusNode,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                      decoration: _subtaskRows[i].isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: _subtaskRows[i].isDone
                                          ? colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.6)
                                          : colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '子任务标题',
                                      hintStyle: TextStyle(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.45),
                                        fontSize: 14.5,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _addSubtaskAndFocus(),
                                  ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => setState(() {
                              _subtaskRows[i].focusNode.removeListener(
                                _onFocusChange,
                              );
                              _subtaskRows[i].controller.dispose();
                              _subtaskRows[i].focusNode.dispose();
                              _subtaskRows.removeAt(i);
                            }),
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 添加子任务按钮 / 行（精确复刻 create.html 的 .sub-add）
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _addSubtaskAndFocus,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 12,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '添加子任务，回车确认',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // ── 7. 底部信息栏（自动保存开关 + 配置摘要） ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  '关闭时自动保存',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: _autoSaveOnClose,
                    onChanged: (v) => setState(() => _autoSaveOnClose = v),
                  ),
                ),
                const Spacer(),
                // 当前摘要信息
                Flexible(
                  child: Text(
                    _buildSummaryText(currentProject?.name, startAt, endAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildSummaryText(String? projectName, int? startAt, int? endAt) {
    final parts = <String>[];
    if (startAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        startAt,
        isUtc: true,
      ).toLocal();
      parts.add(
        '开始 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      );
    }
    if (endAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        endAt,
        isUtc: true,
      ).toLocal();
      parts.add(
        '截止 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      );
    }
    if (parts.isEmpty) return '未设置时间';
    return parts.join(' · ');
  }

  Widget _buildPillButton({
    required VoidCallback onTap,
    required Widget leading,
    required String label,
    required bool hasValue,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
              : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePillWithMenu({
    required bool isStart,
    required int? currentValue,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasValue = currentValue != null;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return GestureDetector(
      onTap: () => showTaskDatePicker(context, ref),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: hasValue
              ? colorScheme.primary.withValues(alpha: 0.1)
              : (isDark
                    ? colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.25,
                      )
                    : const Color(0xFFF1F3F5)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: hasValue
                ? colorScheme.primary.withValues(alpha: 0.35)
                : borderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: hasValue
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                color: hasValue ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySegmentItem({
    required TaskPriority priority,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dotColor = switch (priority) {
      TaskPriority.high => AppTokens.colorPriorityHigh,
      TaskPriority.medium => AppTokens.colorPriorityMedium,
      TaskPriority.low => AppTokens.colorPriorityLow,
      TaskPriority.none => AppTokens.colorCancelled,
    };

    final label = switch (priority) {
      TaskPriority.high => '高',
      TaskPriority.medium => '中',
      TaskPriority.low => '低',
      TaskPriority.none => '无',
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colorScheme.surfaceContainerHighest : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPill({
    required Tag tag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = Color(tag.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? Colors.white10 : const Color(0xFFF1F3F5)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInlineTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(todoRepositoryProvider);
    try {
      final tag = await repo.createTag(name: name, color: _selectedTagColor);
      final current = [...ref.read(taskFormProvider).selectedTagIds, tag.id];
      ref.read(taskFormProvider.notifier).setSelectedTags(current);
      _newTagController.clear();
      setState(() => _showInlineTagCreator = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _saveAndCloseExplicit() async {
    if (_isSaving) return;
    final formState = ref.read(taskFormProvider);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : formState.title.trim();

    if (title.isEmpty) {
      setState(() => _titleError = '标题不能为空');
      _triggerShake();
      _titleFocusNode.requestFocus();
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(taskFormProvider.notifier);
    notifier.updateTitle(title);
    notifier.updateDescription(_descriptionController.text.trim());

    final errorKey = await notifier.save();
    if (!mounted) return;
    if (errorKey != null) {
      final l10n = AppLocalizations.of(context);
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isSaving = false);
      return;
    }

    await _createSubtasks();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    if (!mounted) return;
    final formState = ref.read(taskFormProvider);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : formState.title.trim();

    if (!_autoSaveOnClose || title.isEmpty) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(taskFormProvider.notifier);
    notifier.updateTitle(title);
    notifier.updateDescription(_descriptionController.text.trim());

    final errorKey = await notifier.save();
    if (!mounted) return;
    if (errorKey != null) {
      final l10n = AppLocalizations.of(context);
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _isSaving = false);
      return;
    }

    await _createSubtasks();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _createSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    if (parentId == null) return;
    try {
      for (final st in _subtaskRows) {
        final title = st.controller.text.trim();
        if (title.isNotEmpty) {
          await repo.createTask(
            projectId: formState.projectId,
            parentId: parentId,
            title: title,
            status: st.isDone ? TaskStatus.done : TaskStatus.todo,
          );
        }
      }
    } catch (_) {}
  }
}
