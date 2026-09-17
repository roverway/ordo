// 新建项目 / 项目编辑表单（58-project-form-redesign.md 定稿重写）。
//
// 形态（D1/D5）：全平台统一居中对话框，宽度约束 440dp（[AppTokens.dialogMaxWidth]）。
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
import '../../../shared/widgets/app_adaptive_dialog.dart';
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
  return showDialog<ProjectFormData>(
    context: context,
    builder: (dialogContext) => _ProjectFormDialog(
      initialName: initialName,
      initialColor: initialColor,
      initialDescription: initialDescription,
    ),
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

/// 居中对话框，宽度约束 440dp。
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
    return AppAdaptiveDialog(
      maxWidth: AppTokens.dialogMaxWidth,
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
    );
  }
}

/// 表单主体。
class _ProjectForm extends StatefulWidget {
  const _ProjectForm({
    this.initialName,
    this.initialColor,
    this.initialDescription,
  });

  final String? initialName;
  final int? initialColor;
  final String? initialDescription;

  @override
  State<_ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<_ProjectForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _selectedColor;
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialName != null;

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

  /// 顶栏：标题（新建/编辑）。
  Widget _buildHeader(AppLocalizations l10n, ThemeData theme) {
    final title = _isEditing ? l10n.editProject : l10n.newProject;
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleLarge,
    );
  }

  /// 字段区（选项行结构，行高 48–56dp）。
  Widget _buildFields(AppLocalizations l10n, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 名称（必填）：无背景，仅保留浅色下边距横线 ──
        Container(
          padding: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTokens.surfaceSubtleDark
                    : AppTokens.borderSubtleNeutralLight,
                width: 1.0,
              ),
            ),
          ),
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
                  maxLength: _nameMaxLength,
                  // 紧凑行内不展示字符计数器（评审 #2）。
                  buildCounter: _hideCounter,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.projectName,
                    border: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return l10n.titleRequired;
                    // 防御：maxLength 已拦截输入，但预填/程序赋值仍可能超长，
                    // 避免落库时抛未捕获 RepositoryException（tables.dart max 100）。
                    if (v.length > _nameMaxLength) {
                      return l10n.nameTooLong(_nameMaxLength);
                    }
                    return null;
                  },
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
                  maxLength: _descriptionMaxLength,
                  // 紧凑行内不展示字符计数器（评审 #2）。
                  buildCounter: _hideCounter,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.projectDescription,
                    border: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }

  /// 隐藏字段右下角字符计数器（紧凑表单内嵌计数器会挤占空间，评审 #2）。
  static Widget? _hideCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

/// 项目名称长度上限（与 tables.dart name 列 `withLength(min: 1, max: 100)` 对齐）。
const int _nameMaxLength = 100;

/// 描述长度上限（DB 无约束，纯 UI 层防护）。
const int _descriptionMaxLength = 500;

/// 选项行图标尺寸（分析报告 §3：灰色线性 ~24px，配合 56dp 行高取 22）。
const double _optionIconSize = 22;
