import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// 预设色板（MIUI 风格鲜艳色彩）。
const List<Color> kProjectColors = [
  Color(0xFF3482FF), // 蓝
  Color(0xFF4CAF50), // 绿
  Color(0xFFFF9800), // 橙
  Color(0xFFF44336), // 红
  Color(0xFF9C27B0), // 紫
  Color(0xFF00BCD4), // 青
  Color(0xFFE91E63), // 粉
  Color(0xFF607D8B), // 蓝灰
];

/// 新建/编辑项目对话框。
Future<ProjectFormData?> showProjectFormDialog({
  required BuildContext context,
  String? initialName,
  int? initialColor,
}) async {
  return showDialog<ProjectFormData>(
    context: context,
    builder: (context) => _ProjectFormDialog(
      initialName: initialName,
      initialColor: initialColor,
    ),
  );
}

class ProjectFormData {
  ProjectFormData({required this.name, required this.color});

  final String name;
  final int color;
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({this.initialName, this.initialColor});

  final String? initialName;
  final int? initialColor;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final TextEditingController _nameController;
  late Color _selectedColor;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedColor = Color(
      widget.initialColor ?? kProjectColors.first.toARGB32(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.initialName != null;

    return AlertDialog(
      title: Text(isEditing ? l10n.editProject : l10n.newProject),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 项目名称。
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.projectName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.titleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.spaceMd),
            // 颜色选择。
            Text(
              l10n.projectColor,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Wrap(
              spacing: AppTokens.spaceXs,
              runSpacing: AppTokens.spaceXs,
              children: kProjectColors.map((color) {
                final isSelected =
                    color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: AppTokens.motionFast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(
                ProjectFormData(
                  name: _nameController.text.trim(),
                  color: _selectedColor.toARGB32(),
                ),
              );
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
