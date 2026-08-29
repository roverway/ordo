// 新建任务底部弹窗（59-task-editor-optimization.md §5.2 定稿）。
//
// 弹出式容器：保持底部弹窗形态（60–65% 高、顶部圆角、遮罩、键盘 viewInsets 上移、
// enableDrag:false 避免拖拽下滑与 PopScope 拦截冲突），内容区换用共享编辑器
// [TaskEditor]（顶部栏/选项行/子任务 UI 全部由编辑器提供）。
//
// - 保存：自动保存（关闭时复用 taskFormProvider.save；内容全空直接关闭不落库；
//   有内容但标题为空 → 提示并停留；保存成功后批量创建非空子任务）。
// - 缺省收件箱逻辑（inboxProjectId / inboxProjectProvider）保留。
// - 子任务区仅 1 级任务展示（parentId 为空时）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/todo_repository.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/motion.dart';
import '../../projects/project_providers.dart';
import '../task_providers.dart';
import 'task_editor.dart';

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

  /// 打开新建任务底部弹窗（滴答式，原生逐帧键盘桥接适配）。
  ///
  /// 入场转场（docs/63-motion-polish.md §5 G）：slide-up + `motionCurve`
  /// （easeOutCubic，无过冲）+ `motionSlow`（350ms），遮罩随同一动画同步淡入
  /// （showGeneralDialog 的 barrier 用默认 linear curve 淡入）。
  /// reduced motion 自动降级：时长为零（瞬时到位）。
  ///
  /// - [projectId] 缺省时默认落入内置收件箱（产品决策 #3）；
  /// - [parentId] 非空 = 创建子任务（此时不展示子任务区，层级受 3 级上限约束）。
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
          builder: (context, effectiveInset, bottomGap, _) {
            return Padding(
              padding: EdgeInsets.only(bottom: effectiveInset + bottomGap),
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
            );
          },
        );
      },
    );
  }

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet> {
  final _editorController = TaskEditorController(mode: TaskEditorMode.create);
  bool _isSaving = false;
  bool _initialized = false;

  /// 自动保存完成后置 true，放行 PopScope 的 pop（canPop 由状态驱动）。
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    // 首帧后初始化表单（Riverpod 禁止在 initState 中写 provider，
    // 与 task_edit_page._loadData 的 addPostFrameCallback 模式一致）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  /// 初始化表单：同步复位 + 解析项目（缺省收件箱，幂等 ensure，产品决策 #3）。
  Future<void> _initForm() async {
    if (_initialized) return;
    _initialized = true;
    final notifier = ref.read(taskFormProvider.notifier);

    // 1. 同步复位（可立即输入）：缺省项目用收件箱固定 id，幂等语义不变。
    final initialProjectId = widget.projectId ?? inboxProjectId;
    notifier.resetForNew(initialProjectId, widget.parentId);
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

    // 2. 缺省项目时确保收件箱行存在（幂等），解析完成后仅校正项目字段。
    if (widget.projectId == null) {
      try {
        final inbox = await ref.read(inboxProjectProvider.future);
        final currentState = ref.read(taskFormProvider);
        if (currentState.projectId != inbox.id) {
          notifier.setProjectAndParent(inbox.id, widget.parentId);
        }
      } catch (_) {
        // ensure 失败极罕见（SQLite 本地库）：表单已按收件箱 id 初始化，
        // 保存时若行缺失会经 RepositoryException 走 SnackBar，不静默丢数据。
      }
    }
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 拦截系统返回/遮罩点击 → 自动保存后关闭；校验失败则留在弹窗。
      // 保存成功后通过 _allowPop 放行（否则 Navigator.pop 会被自身拦截，弹窗无法关闭）。
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.spaceMd,
          AppTokens.spaceSm,
          AppTokens.spaceMd,
          0,
        ),
        child: TaskEditor(
          controller: _editorController,
          autofocus: true,
          // 子任务区仅 1 级任务展示（新建子任务时隐藏）。
          showSubtasks: widget.parentId == null,
        ),
      ),
    );
  }

  // ── 自动保存 ─────────────────────────────────────────────────────

  /// 关闭时自动保存（复用 taskFormProvider.save）。
  ///
  /// - 内容全空（标题/描述/备注/时间/优先级/标签/子任务均无）→ 直接关闭不落库；
  /// - 有内容但标题为空 → SnackBar 提示（与编辑页校验一致），留在弹窗；
  /// - 保存成功后批量创建子任务，再关闭。
  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context);
    // 首帧后初始化尚未完成时，先完成初始化再校验/保存（幂等）。
    await _initForm();
    if (!mounted) return;
    final notifier = ref.read(taskFormProvider.notifier);
    final formState = ref.read(taskFormProvider);

    if (formState.title.trim().isEmpty) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _isSaving = true);
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
  }

  /// 保存成功后批量创建非空子任务（复用 repo.createTask，parentId 指向新任务）。
  Future<void> _createSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    if (parentId == null) return;
    try {
      for (final title in _editorController.newSubtaskTitles) {
        await repo.createTask(
          projectId: formState.projectId,
          parentId: parentId,
          title: title,
        );
      }
    } on RepositoryException catch (e) {
      // 父任务已保存，子任务失败仅提示（与编辑页兜底行为一致）。
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
