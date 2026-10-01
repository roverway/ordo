import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/motion.dart';
import '../../../shared/widgets/app_frosted_container.dart';
import '../../../shared/widgets/app_modal_sheet.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';
import 'task_create_sheet.dart';

/// 移动端键盘吸顶双阶快速新建输入条（Two-Stage Inline Quick Capture Bar）。
///
/// 遵循乔布斯极致交互哲学：
/// - Stage 1 极速捕捉：紧贴软键盘，支持连续回车发送，无需反复打开/关闭页面；
/// - Stage 2 语法分词：输入文字时实时解析时间（明天/后天）、标签（#工作）、优先级（!高/!1），以微型胶囊 Chip 呈现实时反馈。
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key, this.initialProjectId, this.initialDate});

  final String? initialProjectId;
  final DateTime? initialDate;

  /// 唤起吸顶快速录入栏
  static Future<void> show(
    BuildContext context, {
    String? initialProjectId,
    DateTime? initialDate,
  }) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => KeyboardInsetBuilder(
        builder: (context, keyboardHeight, bottomInset, child) => Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: QuickCaptureBar(
            initialProjectId: initialProjectId,
            initialDate: initialDate,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // 选定清单与解析元数据
  String? _targetProjectId;
  DateTime? _parsedDate;
  String? _parsedTagName;
  TaskPriority? _parsedPriority;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _targetProjectId = widget.initialProjectId;
    if (widget.initialDate != null) {
      _parsedDate = widget.initialDate;
    }
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    _parseInput(text);
  }

  void _parseInput(String input) {
    if (input.isEmpty) {
      if (_parsedDate != widget.initialDate ||
          _parsedTagName != null ||
          _parsedPriority != null) {
        setState(() {
          _parsedDate = widget.initialDate;
          _parsedTagName = null;
          _parsedPriority = null;
        });
      }
      return;
    }

    DateTime? date = widget.initialDate;
    String? tag;
    TaskPriority? priority;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);

    // 1. 日期解析
    if (input.contains('今天')) {
      date = today;
    } else if (input.contains('明天')) {
      date = today.add(const Duration(days: 1));
    } else if (input.contains('后天')) {
      date = today.add(const Duration(days: 2));
    } else if (input.contains('大后天')) {
      date = today.add(const Duration(days: 3));
    } else {
      // 匹配周一至周日
      final weekMatch = RegExp(r'(?:周|星期)([一二三四五六日天1-7])').firstMatch(input);
      if (weekMatch != null) {
        final wStr = weekMatch.group(1)!;
        final targetWeekday = _parseWeekday(wStr);
        if (targetWeekday != null) {
          int diff = targetWeekday - now.weekday;
          if (diff <= 0) diff += 7;
          date = today.add(Duration(days: diff));
        }
      }
    }

    // 2. 标签解析 (#tag)
    final tagMatch = RegExp(r'#([^\s#]+)').firstMatch(input);
    if (tagMatch != null) {
      tag = tagMatch.group(1);
    }

    // 3. 优先级解析 (!高, !中, !低, !1, !2, !3)
    final priorityMatch = RegExp(
      r'!(高|中|低|1|2|3|high|med|low)',
    ).firstMatch(input);
    if (priorityMatch != null) {
      final pStr = priorityMatch.group(1)!.toLowerCase();
      if (pStr == '高' || pStr == '1' || pStr == 'high') {
        priority = TaskPriority.high;
      } else if (pStr == '中' || pStr == '2' || pStr == 'med') {
        priority = TaskPriority.medium;
      } else if (pStr == '低' || pStr == '3' || pStr == 'low') {
        priority = TaskPriority.low;
      }
    }

    if (date != _parsedDate ||
        tag != _parsedTagName ||
        priority != _parsedPriority) {
      setState(() {
        _parsedDate = date;
        _parsedTagName = tag;
        _parsedPriority = priority;
      });
    }
  }

  int? _parseWeekday(String str) {
    switch (str) {
      case '一':
      case '1':
        return DateTime.monday;
      case '二':
      case '2':
        return DateTime.tuesday;
      case '三':
      case '3':
        return DateTime.wednesday;
      case '四':
      case '4':
        return DateTime.thursday;
      case '五':
      case '5':
        return DateTime.friday;
      case '六':
      case '6':
        return DateTime.saturday;
      case '日':
      case '天':
      case '7':
        return DateTime.sunday;
    }
    return null;
  }

  String _cleanTitle(String raw) {
    var title = raw;
    // 移除识别到的语法关键字
    title = title
        .replaceAll('大后天', '')
        .replaceAll('后天', '')
        .replaceAll('明天', '')
        .replaceAll('今天', '');
    title = title.replaceAll(RegExp(r'(?:周|星期)[一二三四五六日天1-7]'), '');
    if (_parsedTagName != null) {
      title = title.replaceAll('#$_parsedTagName', '');
    }
    title = title.replaceAll(RegExp(r'!(?:高|中|低|1|2|3|high|med|low)'), '');
    title = title.trim();
    return title.isEmpty ? raw.trim() : title;
  }

  Future<void> _submitTask() async {
    if (_isSubmitting) return;
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    _isSubmitting = true;
    try {
      final title = _cleanTitle(rawText);
      final repo = ref.read(todoRepositoryProvider);
      final targetProjectId =
          _targetProjectId ?? widget.initialProjectId ?? inboxProjectId;

      // 解析标签 ID（若存在对应名称的标签）
      List<String>? tagIds;
      if (_parsedTagName != null) {
        final tagsAsync = ref.read(tagsStreamProvider);
        final existingTag = tagsAsync.value
            ?.where(
              (t) => t.name.toLowerCase() == _parsedTagName!.toLowerCase(),
            )
            .firstOrNull;
        if (existingTag != null) {
          tagIds = [existingTag.id];
        }
      }

      final startAtMs =
          (_parsedDate ?? widget.initialDate)?.millisecondsSinceEpoch;

      final createdTask = await repo.createTask(
        title: title,
        projectId: targetProjectId,
        priority: _parsedPriority ?? TaskPriority.none,
        startAt: startAtMs,
      );

      if (tagIds != null && tagIds.isNotEmpty) {
        await repo.tags.setTaskTags(createdTask.id, tagIds);
      }

      // 震感反馈：干脆利落的轻震
      HapticFeedback.mediumImpact();

      // 清空输入框留在原地，准备连续录入下一条
      _textController.clear();
      if (mounted) {
        setState(() {
          _parsedDate = widget.initialDate;
          _parsedTagName = null;
          _parsedPriority = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isSubmitting = false;
    }
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickProject(
    BuildContext context,
    List<Project> projects,
    AppLocalizations l10n,
  ) async {
    HapticFeedback.selectionClick();
    final chosen = await showAppModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return AppModalSheet(
          title: l10n.selectProject,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(l10n.inbox),
                trailing:
                    (_targetProjectId == null ||
                        _targetProjectId == inboxProjectId)
                    ? Icon(Icons.check, color: cs.primary)
                    : null,
                onTap: () => Navigator.of(ctx).pop(inboxProjectId),
              ),
              for (final p in projects)
                ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(p.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(p.name),
                  trailing: _targetProjectId == p.id
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(p.id),
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      setState(() => _targetProjectId = chosen);
    }
  }

  Widget _buildQuickCapsule({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    Color? activeColor,
    required ColorScheme colorScheme,
  }) {
    final color = isActive
        ? (activeColor ?? colorScheme.primary)
        : colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: AppTokens.alphaTintSoft)
              : colorScheme.surfaceContainerHighest.withValues(
                  alpha: AppTokens.alphaTintFaint,
                ),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: AppTokens.alphaBorderEmphasis)
                : colorScheme.outlineVariant.withValues(
                    alpha: AppTokens.alphaBorderSubtle,
                  ),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _expandToFullSheet() {
    Navigator.of(context).pop();
    TaskCreateSheet.show(
      context,
      projectId: _targetProjectId ?? widget.initialProjectId,
      initialPriority: _parsedPriority,
      initialStartAt:
          (_parsedDate ?? widget.initialDate)?.millisecondsSinceEpoch,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9);
    final tomorrow = today.add(const Duration(days: 1));

    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final selectedProject = projects
        .where(
          (p) =>
              p.id ==
              (_targetProjectId ?? widget.initialProjectId ?? inboxProjectId),
        )
        .firstOrNull;
    final selectedProjectName = selectedProject?.name ?? l10n.inbox;

    final hint = l10n.localeName == 'zh'
        ? '添加任务，输入「明天」「#清单」「!高」试试...'
        : 'Add task, try "tomorrow", "#list", "!high"...';

    return AppFrostedContainer(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusSheet),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部抓手与展开全屏按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Container(
                    width: AppTokens.sheetGrabberMiniWidth,
                    height: AppTokens.sheetGrabberMiniHeight,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(
                        alpha: AppTokens.alphaTintStrong,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                    tooltip: l10n.expand,
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: _expandToFullSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: l10n.cancel,
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 4个单手快捷常驻胶囊（今天、明天、优先级、所属清单）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_parsedDate != null &&
                        !_isSameDay(_parsedDate, today) &&
                        !_isSameDay(_parsedDate, tomorrow)) ...[
                      _buildQuickCapsule(
                        icon: Icons.event_available_outlined,
                        label: _formatParsedDate(_parsedDate!, l10n),
                        isActive: true,
                        activeColor: AppTokens.colorNavToday,
                        colorScheme: colorScheme,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _parsedDate = null;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildQuickCapsule(
                      icon: Icons.today_outlined,
                      label: l10n.today,
                      isActive: _isSameDay(_parsedDate, today),
                      activeColor: AppTokens.colorNavToday,
                      colorScheme: colorScheme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_isSameDay(_parsedDate, today)) {
                            _parsedDate = null;
                          } else {
                            _parsedDate = today;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickCapsule(
                      icon: Icons.wb_sunny_outlined,
                      label: l10n.tomorrow,
                      isActive: _isSameDay(_parsedDate, tomorrow),
                      activeColor: AppTokens.colorNavToday,
                      colorScheme: colorScheme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (_isSameDay(_parsedDate, tomorrow)) {
                            _parsedDate = null;
                          } else {
                            _parsedDate = tomorrow;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickCapsule(
                      icon: Icons.flag_outlined,
                      label: _parsedPriority != null
                          ? _priorityLabel(_parsedPriority!, l10n)
                          : l10n.priority,
                      isActive: _parsedPriority != null,
                      activeColor: _parsedPriority != null
                          ? priorityColor(_parsedPriority!)
                          : null,
                      colorScheme: colorScheme,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _parsedPriority = switch (_parsedPriority) {
                            null => TaskPriority.high,
                            TaskPriority.none => TaskPriority.high,
                            TaskPriority.high => TaskPriority.medium,
                            TaskPriority.medium => TaskPriority.low,
                            TaskPriority.low => null,
                          };
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildQuickCapsule(
                      icon: Icons.folder_outlined,
                      label: selectedProjectName,
                      isActive:
                          _targetProjectId != null &&
                          _targetProjectId != inboxProjectId,
                      activeColor: colorScheme.primary,
                      colorScheme: colorScheme,
                      onTap: () => _pickProject(context, projects, l10n),
                    ),
                    if (_parsedTagName != null) ...[
                      const SizedBox(width: 8),
                      _buildQuickCapsule(
                        icon: Icons.tag_rounded,
                        label: '#$_parsedTagName',
                        isActive: true,
                        activeColor: AppTokens.colorNavTags,
                        colorScheme: colorScheme,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _parsedTagName = null;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 输入框与提交操作行
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: TextStyle(
                        fontSize: AppTokens.textBodySize,
                        color: colorScheme.onSurface,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitTask(),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          fontSize: AppTokens.textBodySize,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: AppTokens.alphaScrim,
                          ),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textController,
                    builder: (context, val, _) {
                      final hasText = val.text.trim().isNotEmpty;
                      return AnimatedScale(
                        scale: hasText ? 1.0 : 0.85,
                        duration: motionFast(context),
                        child: IconButton.filled(
                          onPressed: hasText ? _submitTask : null,
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                          ),
                          tooltip: l10n.save,
                          style: IconButton.styleFrom(
                            backgroundColor: hasText
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: hasText
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.all(8),
                            minimumSize: const Size(36, 36),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatParsedDate(DateTime date, AppLocalizations l10n) {
    if (l10n.localeName == 'zh') {
      return '${date.month}月${date.day}日';
    }
    return '${date.month}/${date.day}';
  }

  String _priorityLabel(TaskPriority priority, AppLocalizations l10n) {
    return switch (priority) {
      TaskPriority.high => l10n.priorityHigh,
      TaskPriority.medium => l10n.priorityMedium,
      TaskPriority.low => l10n.priorityLow,
      TaskPriority.none => l10n.priorityNone,
    };
  }
}
