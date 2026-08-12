// 新建项目 / 项目编辑表单（58-project-form-redesign.md 定稿重写）。
//
// 形态（D1/D5）：
// - 移动端（<600dp）：底部弹窗，默认约 0.6 屏高，可上拉扩展至全屏
//   （DraggableScrollableSheet，snap 0.4 / 0.6 / 1.0）；全屏态顶部出现收起按钮。
// - 桌面端（≥600dp）：居中对话框，宽度约束 440dp。
// 字段（D2/D3/D4）：名称（必填）、颜色（选项行 → 底部颜色选择器）、描述（可选多行）；
// 底部显式 取消/保存。
//
// 选项行视觉（ticktick-task-editor-analysis.md §3）：[图标/色点] 字段名 …… 右侧值/箭头，
// 行高 48–56dp 整行可点，图标灰色线性，字段名灰 14–16sp。
//
// 注意：本组件只收集并返回 [ProjectFormData]（含 description），不调用 repository
// （接线由编排者统一处理）。

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/app_breakpoints.dart';
import 'project_color_picker_sheet.dart';

// 兼容旧引用：kProjectColors 现定义在颜色选择器文件（避免循环依赖）。
export 'project_color_picker_sheet.dart' show kProjectColors;

/// 打开新建/编辑项目表单。
///
/// - [initialName] / [initialColor] / [initialDescription] 非空 = 编辑模式（预填）。
/// - 返回 [ProjectFormData]；取消（取消按钮 / 遮罩 / 返回键）返回 null。
Future<ProjectFormData?> showProjectFormDialog({
  required BuildContext context,
  String? initialName,
  int? initialColor,
  String? initialDescription,
}) {
  // D5：宽屏（≥600dp）居中对话框；窄屏走可上拉底部弹窗（D1）。
  if (AppBreakpoints.isWide(context)) {
    return showDialog<ProjectFormData>(
      context: context,
      builder: (dialogContext) => _ProjectFormDialog(
        initialName: initialName,
        initialColor: initialColor,
        initialDescription: initialDescription,
      ),
    );
  }
  return _showProjectFormSheet(
    context,
    initialName: initialName,
    initialColor: initialColor,
    initialDescription: initialDescription,
  );
}

/// 表单返回数据（字段仅供调用方接线，本文件不落库）。
class ProjectFormData {
  ProjectFormData({
    required this.name,
    required this.color,
    this.description = '',
  });

  final String name;
  final int color;
  final String description;
}

/// 移动端：底部弹窗 + 可上拉全屏（D1）。
///
/// - showModalBottomSheet：isScrollControlled + useSafeArea + 顶部圆角 radiusDialog；
/// - 外层 enableDrag: false，拖拽交由内部 DraggableScrollableSheet 接管（避免手势冲突）；
/// - viewInsets padding 适配键盘（对齐 TaskCreateSheet.show）；
/// - 键盘弹出时自动扩展至全屏，收起键盘回落到默认部分高度。
Future<ProjectFormData?> _showProjectFormSheet(
  BuildContext context, {
  String? initialName,
  int? initialColor,
  String? initialDescription,
}) {
  return showModalBottomSheet<ProjectFormData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _ProjectFormSheet(
        initialName: initialName,
        initialColor: initialColor,
        initialDescription: initialDescription,
      ),
    ),
  );
}

/// 弹窗体：DraggableScrollableSheet 负责 0.4 → 1.0 的高度拖拽与键盘适配。
class _ProjectFormSheet extends StatefulWidget {
  const _ProjectFormSheet({
    this.initialName,
    this.initialColor,
    this.initialDescription,
  });

  final String? initialName;
  final int? initialColor;
  final String? initialDescription;

  @override
  State<_ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends State<_ProjectFormSheet> {
  /// 默认部分高度（约 60% 屏高，对齐参考图 60–70%）。
  static const double _initialFraction = 0.6;

  /// 最小高度。
  static const double _minFraction = 0.4;

  /// 判定全屏的阈值（snap 到 1.0 时展示顶部收起按钮）。
  static const double _fullscreenThreshold = 0.99;

  late final DraggableScrollableController _sheetController;

  /// 键盘弹出导致的自动全屏标记：键盘收起后回落到默认高度。
  bool _expandedByKeyboard = false;

  /// 当前是否全屏（控制顶部收起按钮显隐）。
  bool _isFullscreen = false;

  double _lastViewInsets = 0;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetSizeChanged);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _onSheetSizeChanged() {
    final isFull = _sheetController.size >= _fullscreenThreshold;
    if (isFull != _isFullscreen && mounted) {
      setState(() => _isFullscreen = isFull);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    if (insets > 0 && _lastViewInsets == 0) {
      // 键盘弹出：扩展至全屏，保证输入框与操作区可见。
      _expandedByKeyboard = !_isFullscreen;
      _animateTo(1.0);
    } else if (insets == 0 && _lastViewInsets > 0 && _expandedByKeyboard) {
      // 键盘收起：回落到默认部分高度（用户手动拖到全屏的保持全屏）。
      _expandedByKeyboard = false;
      _animateTo(_initialFraction);
    }
    _lastViewInsets = insets;
  }

  void _animateTo(double fraction) {
    // 首帧 controller 可能尚未 attach，延后到帧后执行。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sheetController.isAttached) {
        _sheetController.animateTo(
          fraction,
          duration: AppTokens.motionSlow,
          curve: AppTokens.motionSpring,
        );
      }
    });
  }

  /// 全屏态顶部「返回」：收起回默认部分高度。
  void _collapse() => _animateTo(_initialFraction);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _initialFraction,
      minChildSize: _minFraction,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [_minFraction, _initialFraction, 1.0],
      controller: _sheetController,
      builder: (context, scrollController) => _ProjectForm(
        initialName: widget.initialName,
        initialColor: widget.initialColor,
        initialDescription: widget.initialDescription,
        scrollController: scrollController,
        isFullscreen: _isFullscreen,
        onCollapse: _collapse,
      ),
    );
  }
}

/// 桌面端：居中对话框（D5），宽度约束 400–480dp。
class _ProjectFormDialog extends StatelessWidget {
  const _ProjectFormDialog({
    this.initialName,
    this.initialColor,
    this.initialDescription,
  });

  final String? initialName;
  final int? initialColor;
  final String? initialDescription;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceXl,
            AppTokens.spaceLg,
            AppTokens.spaceXl,
            AppTokens.spaceMd,
          ),
          child: _ProjectForm(
            initialName: initialName,
            initialColor: initialColor,
            initialDescription: initialDescription,
          ),
        ),
      ),
    );
  }
}

/// 对话框宽度上限（400–480dp 区间取值）。
const double _dialogMaxWidth = 440;

/// 表单主体：弹窗与对话框共用。
///
/// - 弹窗模式（[scrollController] 非空）：拖拽把手 + 滚动字段区 + 固定底部操作区；
/// - 对话框模式：普通 Column 排布，底部 取消/保存。
class _ProjectForm extends StatefulWidget {
  const _ProjectForm({
    this.initialName,
    this.initialColor,
    this.initialDescription,
    this.scrollController,
    this.isFullscreen = false,
    this.onCollapse,
  });

  final String? initialName;
  final int? initialColor;
  final String? initialDescription;

  /// 非空 = 移动端弹窗模式（内容滚动、底部操作区固定、可拖拽）。
  final ScrollController? scrollController;

  /// 全屏态（snap 到 1.0）——展示顶部收起按钮。
  final bool isFullscreen;

  /// 收起回调（全屏 → 默认部分高度）。
  final VoidCallback? onCollapse;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _selectedColor;
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialName != null;
  bool get _isSheet => widget.scrollController != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
    _selectedColor = Color(
      widget.initialColor ?? kProjectColors.first.toARGB32(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ProjectFormData(
        name: _nameController.text.trim(),
        color: _selectedColor.toARGB32(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  /// 颜色选项行 → 底部颜色选择器。
  Future<void> _pickColor() async {
    final picked = await showProjectColorPicker(
      context: context,
      current: _selectedColor,
    );
    if (picked != null && mounted) {
      setState(() => _selectedColor = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isSheet) {
      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildDragHandle(theme),
          Flexible(
            child: Form(
              key: _formKey,
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  AppTokens.spaceXxs,
                  AppTokens.spaceMd,
                  AppTokens.spaceSm,
                ),
                children: [
                  _buildHeader(l10n, theme),
                  const SizedBox(height: AppTokens.spaceXs),
                  _buildFields(l10n, theme),
                ],
              ),
            ),
          ),
          _buildActions(l10n),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(l10n, theme),
          const SizedBox(height: AppTokens.spaceLg),
          _buildFields(l10n, theme),
          const SizedBox(height: AppTokens.spaceLg),
          _buildActions(l10n),
        ],
      ),
    );
  }

  /// 拖拽把手（弹窗顶部小药丸，提示可上下拖拽）。
  Widget _buildDragHandle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppTokens.spaceSm,
        bottom: AppTokens.spaceXxs,
      ),
      child: Center(
        child: Container(
          width: _handleWidth,
          height: _handleHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(_handleRadius),
          ),
        ),
      ),
    );
  }

  /// 顶栏：标题（新建/编辑）+ 全屏态收起按钮。
  Widget _buildHeader(AppLocalizations l10n, ThemeData theme) {
    final title = _isEditing ? l10n.editProject : l10n.newProject;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _isSheet
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTokens.textTitleWeight,
                  )
                : theme.textTheme.titleLarge,
          ),
        ),
        if (widget.isFullscreen && widget.onCollapse != null)
          IconButton(
            tooltip: l10n.collapse,
            onPressed: widget.onCollapse,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
      ],
    );
  }

  /// 字段区（选项行结构，行高 48–56dp）。
  Widget _buildFields(AppLocalizations l10n, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 名称（必填）：[图标] 行内无边框输入，hint 即字段名 ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: _optionIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.projectName,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.titleRequired
                      : null,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 颜色：整行可点 → 底部颜色选择器（D3）──
        InkWell(
          onTap: _pickColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
            child: Row(
              children: [
                // 行首色点即当前颜色（作为该行的「图标」）。
                Container(
                  width: _optionIconSize,
                  height: _optionIconSize,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    l10n.projectColor,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── 描述（可选，多行 2–3 行）：[图标] 行内无边框输入 ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceXs),
                child: Icon(
                  Icons.notes_outlined,
                  size: _optionIconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.projectDescription,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 底部操作区：取消 + 保存（D4 显式保存）。
  Widget _buildActions(AppLocalizations l10n) {
    return Padding(
      padding: _isSheet
          ? const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              AppTokens.spaceXs,
              AppTokens.spaceMd,
              AppTokens.spaceSm,
            )
          : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: AppTokens.spaceXs),
          FilledButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
    );
  }
}

/// 选项行图标尺寸（分析报告 §3：灰色线性 ~24px，配合 56dp 行高取 22）。
const double _optionIconSize = 22;

/// 拖拽把手宽度。
const double _handleWidth = 36;

/// 拖拽把手高度。
const double _handleHeight = 4;

/// 拖拽把手圆角。
const double _handleRadius = 2;
