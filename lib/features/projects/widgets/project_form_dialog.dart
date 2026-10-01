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
  return showAppAdaptiveDialog<ProjectFormData>(
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

  Future<void> _pickColor() async {
    final picked = await showProjectColorPicker(
      context: context,
      current: _selectedColor,
    );
    if (picked != null && mounted) {
      setState(() => _selectedColor = picked);
    }
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(
        ProjectFormData(
          name: _nameController.text.trim(),
          color: _selectedColor.toARGB32(),
          description: _descriptionController.text.trim(),
        ),
      );
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
          // 标题
          Text(
            _isEditing ? l10n.editProject : l10n.newProject,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppTokens.textTitleWeight,
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // 项目名称（必填）
          TextFormField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.projectName),
            textInputAction: TextInputAction.next,
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) {
                return l10n.titleRequired;
              }
              if (val.length > 100) {
                return l10n.nameTooLong(100);
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // 颜色选项行（整行可点 → 打开底部颜色选择器）
          _ColorRow(color: _selectedColor, onTap: _pickColor),
          const SizedBox(height: AppTokens.spaceMd),

          // 项目描述（可选，多行）
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.projectDescription,

              alignLabelWithHint: true,
            ),
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: AppTokens.spaceLg),

          // 显式 取消/保存 按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              FilledButton(onPressed: _save, child: Text(l10n.save)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「颜色」选项行。
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: l10n.projectColor,
      child: Material(
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          child: Container(
            height: AppTokens.touchTarget,
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: isDark
                    ? AppTokens.borderSubtleDark
                    : AppTokens.borderSubtleLight,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // 左侧灰色调色盘图标
                Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                // 字段名
                Expanded(
                  child: Text(
                    l10n.projectColor,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                // 右侧当前颜色圆点
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                // 右侧指示箭头
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
