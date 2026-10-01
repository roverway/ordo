// 新建任务底部弹窗（高保真还原设计稿 screens_create.html + 补齐结束时间设置按钮）。
//
// 包含：
// 1. 顶部抓手 + 标题栏（关闭 X / 居中标题 / 保存按钮）
// 2. 标题输入（带空标题校验摇晃动画与错误提示） + 备注输入
// 3. 选项胶囊栏（项目选择器 + 开始时间设置 + 结束时间/截止时间设置）
// 4. 优先级分段选择（无/低/中/高 带彩色圆点）
// 5. 标签选择行 + 内联新建标签输入
// 6. 子任务列表（带复选框、删除按钮；多行输入与编辑页一致，回车=行内换行，新增行经底部「添加子任务」按钮）
// 7. 底部信息栏（关闭时自动保存开关 + 当前配置摘要）

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../projects/project_providers.dart';
import '../task_providers.dart';
import 'task_create_sheet_options.dart';
import 'task_create_subtasks_section.dart';

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

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: motionSlow(context),
        reverseDuration: motionSlow(context),
      ),
      builder: (sheetContext) {
        return KeyboardInsetBuilder(
          builder: (context, keyboardHeight, bottomInset, child) => Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: TaskCreateSheet(
              projectId: projectId,
              parentId: parentId,
              initialStartAt: initialStartAt,
              initialEndAt: initialEndAt,
              initialPriority: initialPriority,
              initialTagIds: initialTagIds,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final List<SubtaskDraftRow> _subtaskRows = [];

  bool _isSaving = false;
  bool _allowPop = false;
  bool _autoSaveOnClose = true;
  String? _titleError;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: AppTokens.motionNormal,
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
      _subtaskRows.add(SubtaskDraftRow(controller: ctrl, focusNode: focusNode));
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
    final projectId = ref.watch(taskFormProvider.select((s) => s.projectId));
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final currentProject = projects.where((p) => p.id == projectId).firstOrNull;

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    final isFocused =
        _titleFocusNode.hasFocus ||
        _descriptionFocusNode.hasFocus ||
        _subtaskRows.any((r) => r.focusNode.hasFocus);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final targetMaxHeight = screenHeight;

    final rawTopInset = MediaQuery.viewPaddingOf(context).top;
    final view = View.maybeOf(context);
    final engineTopInset = view != null
        ? (view.viewPadding.top / view.devicePixelRatio)
        : 0.0;
    final physicalTopInset = rawTopInset > 0 ? rawTopInset : engineTopInset;
    final isMobile =
        theme.platform == TargetPlatform.android ||
        theme.platform == TargetPlatform.iOS;
    final effectiveStatusBarHeight = physicalTopInset > 0
        ? physicalTopInset
        : (isMobile ? 36.0 : 0.0);

    final topClearance = isFocused ? (effectiveStatusBarHeight + 10.0) : 0.0;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(maxHeight: targetMaxHeight),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.surfaceDark : AppTokens.surfaceCardLight,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isFocused ? 16 : 24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: AppTokens.alphaBorderEmphasis,
              ),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 顶部状态栏安全距离（聚焦全屏时生效） ──
            if (isFocused)
              SizedBox(height: topClearance)
            else
              // ── 拖拽手柄（非全屏时显示） ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTokens.alphaContentDisabled,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
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
                      fontSize: AppTokens.textBodySize,
                    ),
                  ),
                  TextButton(
                    onPressed: _saveAndCloseExplicit,
                    child: Text(
                      l10n.save,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: AppTokens.textBodySize,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: borderColor),

            // ── 可滚动主体内容 ──
            Flexible(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. 标题输入框
                      Container(
                        padding: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? AppTokens.surfaceSubtleDark
                                  : AppTokens.borderSubtleNeutralLight,
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            final offset =
                                math.sin(_shakeAnimation.value * math.pi * 4) *
                                6;
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
                              fontSize: AppTokens.textTitleSize,
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
                                fontSize: AppTokens.textTitleSize,
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                            ),
                            onChanged: (v) {
                              if (_titleError != null) {
                                setState(() => _titleError = null);
                              }
                              ref
                                  .read(taskFormProvider.notifier)
                                  .updateTitle(v);
                            },
                          ),
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
                                  fontSize: AppTokens.textCaptionSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 2. 备注/描述输入框
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        maxLines: 3,
                        minLines: 1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: AppTokens.textSecondarySize,
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.notesHint,
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.45,
                            ),
                            fontSize: AppTokens.textSecondarySize,
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                        ),
                        onChanged: (v) => ref
                            .read(taskFormProvider.notifier)
                            .updateDescription(v),
                      ),

                      const SizedBox(height: 16),

                      // 3. 胶囊选项栏（项目 + 开始时间 + 结束时间）
                      const TaskCreatePillRow(),

                      const SizedBox(height: 14),

                      Divider(height: 1, color: borderColor),

                      // 4. 优先级选择行
                      const TaskCreatePriorityRow(),

                      Divider(height: 1, color: borderColor),

                      // 5. 标签行
                      TaskCreateTagRow(borderColor: borderColor),

                      Divider(height: 1, color: borderColor),

                      // 6. 子任务区
                      if (widget.parentId == null) ...[
                        TaskCreateSubtasksSection(
                          subtaskRows: _subtaskRows,
                          borderColor: borderColor,
                          onToggleDone: (i) {
                            setState(() {
                              _subtaskRows[i].isDone = !_subtaskRows[i].isDone;
                            });
                          },
                          onRemove: (i) {
                            setState(() {
                              _subtaskRows[i].focusNode.removeListener(
                                _onFocusChange,
                              );
                              _subtaskRows[i].controller.dispose();
                              _subtaskRows[i].focusNode.dispose();
                              _subtaskRows.removeAt(i);
                            });
                          },
                          onAddSubtask: _addSubtaskAndFocus,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Divider(height: 1, color: borderColor),

            // ── 7. 底部信息栏（自动保存开关 + 配置摘要） ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    l10n.autoSaveOnClose,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: AppTokens.textCaptionSize,
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
                      _buildSummaryText(
                        currentProject?.name,
                        startAt,
                        endAt,
                        l10n,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: AppTokens.textMicroSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSummaryText(
    String? projectName,
    int? startAt,
    int? endAt,
    AppLocalizations l10n,
  ) {
    final parts = <String>[];
    if (startAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        startAt,
        isUtc: true,
      ).toLocal();
      parts.add(
        l10n.startPrefix(
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
    if (endAt != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        endAt,
        isUtc: true,
      ).toLocal();
      parts.add(
        l10n.duePrefix(
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        ),
      );
    }
    if (parts.isEmpty) return l10n.noTimeSet;
    return parts.join(' · ');
  }

  Future<void> _saveAndCloseExplicit() => _performSave(isExplicit: true);

  Future<void> _saveAndClose() => _performSave(isExplicit: false);

  Future<void> _performSave({required bool isExplicit}) async {
    if (_isSaving) return;
    if (!mounted) return;
    final formState = ref.read(taskFormProvider);
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : formState.title.trim();

    final l10n = AppLocalizations.of(context);
    if (title.isEmpty) {
      if (!isExplicit) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
        return;
      }
      setState(() => _titleError = l10n.titleCannotBeEmpty);
      _triggerShake();
      _titleFocusNode.requestFocus();
      return;
    }

    if (!isExplicit && !_autoSaveOnClose) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(taskFormProvider.notifier);
    notifier.updateTitle(title);
    notifier.updateDescription(_descriptionController.text.trim());

    try {
      final errorKey = await notifier.save();
      if (!mounted) return;
      if (errorKey != null) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveTaskFailed(e.toString()))),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    if (parentId == null || _subtaskRows.isEmpty) return;

    final items = <({String? id, String title, TaskStatus? status})>[];
    for (final st in _subtaskRows) {
      final title = st.controller.text.trim();
      if (title.isNotEmpty) {
        items.add((
          id: null,
          title: title,
          status: st.isDone ? TaskStatus.done : TaskStatus.todo,
        ));
      }
    }
    if (items.isNotEmpty) {
      await repo.syncSubtasks(
        parentId: parentId,
        deleteSubtaskIds: const [],
        items: items,
      );
    }
  }
}
