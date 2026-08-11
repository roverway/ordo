import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Preset color palette for projects.
const List<Color> kProjectColors = AppTokens.presetColors;

/// Create/edit project dialog.
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
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        isEditing ? l10n.editProject : l10n.newProject,
        style: theme.textTheme.titleLarge,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project name.
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.projectName),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.titleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppTokens.spaceMd),
            // Color picker.
            Text(l10n.projectColor, style: theme.textTheme.bodySmall),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.onSurface,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
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
