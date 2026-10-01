#!/usr/bin/env python3
"""
Token discipline check script for todo application.
Enforces design token consistency and prevents token drift across the codebase.
Implements the Ratchet Pattern:
  - Base rules (monospace font, raw pill radius, hardcoded breakpoint) are zero tolerance across all files.
  - Extended rules (bare fontSize/size numbers, bare EdgeInsets numeric literals) allow legacy baseline files,
    but zero tolerance for all newly created or migrated files.
"""

import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_DIR = os.path.join(REPO_ROOT, 'lib')

# Files allowed to declare base tokens / raw primitives
ALLOWED_TOKEN_FILES = {
    'app_tokens.dart',
    'app_breakpoints.dart',
}

# Legacy files allowed temporary exemption for bare fontSize/size until incremental cleanup
SIZE_LEGACY_FILES = {
    'lib/features/ai_copilot/views/ai_copilot_sheet.dart',
    'lib/features/ai_copilot/widgets/ai_shimmer_glow.dart',
    'lib/features/ai_copilot/widgets/ai_task_proposal_card.dart',
    'lib/features/ai_copilot/widgets/proposal_substep_tile.dart',
    'lib/features/calendar/calendar_page.dart',
    'lib/features/custom_views/presentation/custom_view_editor_page.dart',
    'lib/features/custom_views/presentation/custom_view_page.dart',
    'lib/features/custom_views/widgets/filter_criteria_sheet.dart',
    'lib/features/custom_views/widgets/icon_picker_dialog.dart',
    'lib/features/custom_views/widgets/panel_column.dart',
    'lib/features/projects/projects_page.dart',
    'lib/features/projects/widgets/create_list_folder_sheet.dart',
    'lib/features/projects/widgets/folder_name_dialog.dart',
    'lib/features/projects/widgets/project_card.dart',
    'lib/features/projects/widgets/project_color_picker_sheet.dart',
    'lib/features/projects/widgets/project_form_dialog.dart',
    'lib/features/quadrant/widgets/quadrant_card.dart',
    'lib/features/quadrant/widgets/quadrant_cards_view.dart',
    'lib/features/quadrant/widgets/quadrant_filter_bar.dart',
    'lib/features/quadrant/widgets/quadrant_focus_sheet.dart',
    'lib/features/quadrant/widgets/quadrant_list_view.dart',
    'lib/features/quadrant/widgets/quadrant_scope_filter_sheet.dart',
    'lib/features/quadrant/widgets/quadrant_task_tile.dart',
    'lib/features/search/search_page.dart',
    'lib/features/settings/settings_page.dart',
    'lib/features/settings/user_manual_page.dart',
    'lib/features/settings/views/ai_settings_page.dart',
    'lib/features/settings/widgets/ai_mcp_server_card.dart',
    'lib/features/settings/widgets/ai_ping_result_card.dart',
    'lib/features/settings/widgets/ai_provider_picker_sheet.dart',
    'lib/features/settings/widgets/backup_section.dart',
    'lib/features/settings/widgets/import_confirm_dialog.dart',
    'lib/features/settings/widgets/snapshot_history_sheet.dart',
    'lib/features/settings/widgets/wallpaper_picker_sheet.dart',
    'lib/features/sync_setup/sync_setup_page.dart',
    'lib/features/tags/tags_detail_page.dart',
    'lib/features/tags/tags_page.dart',
    'lib/features/tasks/task_edit_page.dart',
    'lib/features/tasks/task_list_page.dart',
    'lib/features/tasks/widgets/priority_picker.dart',
    'lib/features/tasks/widgets/quick_capture_bar.dart',
    'lib/features/tasks/widgets/task_create_sheet.dart',
    'lib/features/tasks/widgets/task_create_sheet_options.dart',
    'lib/features/tasks/widgets/task_create_subtasks_section.dart',
    'lib/features/tasks/widgets/task_editor.dart',
    'lib/features/tasks/widgets/task_editor/project_picker_sheet.dart',
    'lib/features/tasks/widgets/task_editor/subtask_list.dart',
    'lib/features/tasks/widgets/task_editor/subtask_row_tile.dart',
    'lib/features/tasks/widgets/task_editor/tag_picker_sheet.dart',
    'lib/features/tasks/widgets/task_editor/task_date_picker_dialogs.dart',
    'lib/features/tasks/widgets/task_editor/task_editor_toolbar.dart',
    'lib/features/tasks/widgets/task_row.dart',
    'lib/features/tasks/widgets/task_tree.dart',
    'lib/shared/widgets/adaptive_leading_navigation.dart',
    'lib/shared/widgets/app_background_wrapper.dart',
    'lib/shared/widgets/default_route_selector_sheet.dart',
    'lib/shared/widgets/filter_chips_bar.dart',
    'lib/shared/widgets/floating_minimal_dock.dart',
    'lib/shared/widgets/inline_search_bar.dart',
    'lib/shared/widgets/markdown_content_view.dart',
    'lib/shared/widgets/modern_segmented_control.dart',
    'lib/shared/widgets/page_hero_header.dart',
    'lib/shared/widgets/scope_nav_content.dart',
    'lib/shared/widgets/scope_switcher_sheet.dart',
    'lib/shared/widgets/simple_task_tile.dart',
    'lib/shared/widgets/swipe_actions.dart',
    'lib/shared/widgets/task_filter_bar.dart',
    'lib/shared/widgets/unified_hierarchical_folder_selector.dart',
}

# Legacy files allowed temporary exemption for bare EdgeInsets numeric literals until incremental cleanup
EDGE_INSETS_LEGACY_FILES = {
    'lib/features/ai_copilot/widgets/ai_task_proposal_card.dart',
    'lib/features/ai_copilot/widgets/proposal_substep_tile.dart',
    'lib/features/calendar/calendar_page.dart',
    'lib/features/custom_views/presentation/custom_view_editor_page.dart',
    'lib/features/custom_views/presentation/custom_view_page.dart',
    'lib/features/custom_views/widgets/filter_criteria_sheet.dart',
    'lib/features/custom_views/widgets/panel_column.dart',
    'lib/features/home/widgets/home_fab.dart',
    'lib/features/projects/projects_page.dart',
    'lib/features/projects/widgets/create_list_folder_sheet.dart',
    'lib/features/projects/widgets/folder_name_dialog.dart',
    'lib/features/projects/widgets/project_form_dialog.dart',
    'lib/features/quadrant/widgets/quadrant_filter_bar.dart',
    'lib/features/quadrant/widgets/quadrant_scope_filter_sheet.dart',
    'lib/features/settings/settings_page.dart',
    'lib/features/settings/user_manual_page.dart',
    'lib/features/settings/widgets/backup_section.dart',
    'lib/features/settings/widgets/import_confirm_dialog.dart',
    'lib/features/settings/widgets/snapshot_history_sheet.dart',
    'lib/features/tasks/task_list_page.dart',
    'lib/features/tasks/widgets/quick_capture_bar.dart',
    'lib/features/tasks/widgets/task_create_sheet.dart',
    'lib/features/tasks/widgets/task_create_sheet_options.dart',
    'lib/features/tasks/widgets/task_create_subtasks_section.dart',
    'lib/features/tasks/widgets/task_editor.dart',
    'lib/features/tasks/widgets/task_editor/project_picker_sheet.dart',
    'lib/features/tasks/widgets/task_editor/subtask_list.dart',
    'lib/features/tasks/widgets/task_editor/subtask_row_tile.dart',
    'lib/features/tasks/widgets/task_editor/task_date_picker_dialogs.dart',
    'lib/features/tasks/widgets/task_row.dart',
    'lib/features/tasks/widgets/task_tree.dart',
    'lib/shared/widgets/app_background_wrapper.dart',
    'lib/shared/widgets/default_route_selector_sheet.dart',
    'lib/shared/widgets/filter_chips_bar.dart',
    'lib/shared/widgets/floating_minimal_dock.dart',
    'lib/shared/widgets/inline_search_bar.dart',
    'lib/shared/widgets/markdown_content_view.dart',
    'lib/shared/widgets/modern_segmented_control.dart',
    'lib/shared/widgets/page_hero_header.dart',
    'lib/shared/widgets/scope_nav_content.dart',
    'lib/shared/widgets/scope_switcher_sheet.dart',
    'lib/shared/widgets/simple_task_tile.dart',
    'lib/shared/widgets/unified_hierarchical_folder_selector.dart',
}

violations = []

def check_file(filepath):
    rel_path = os.path.relpath(filepath, REPO_ROOT)
    filename = os.path.basename(filepath)
    is_token_file = filename in ALLOWED_TOKEN_FILES

    if 'lib/core/theme' in rel_path or 'lib/core/utils/motion.dart' in rel_path:
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for idx, line in enumerate(lines, 1):
        raw = line.strip()
        if raw.startswith('//') or raw.startswith('/*') or raw.startswith('*'):
            continue

        # 1. Check for raw monospace font family (must use AppTokens.fontMonoFamily / fontMonoFallback)
        if not is_token_file and "fontFamily: 'monospace'" in line:
            violations.append(f"[{rel_path}:{idx}] Raw monospace font detected. Use AppTokens.fontMonoFamily or fontTabular.")

        # 2. Check for raw circular(999) or circular(100) (must use AppTokens.radiusPill)
        if not is_token_file and ("circular(999)" in line or "circular(100)" in line):
            violations.append(f"[{rel_path}:{idx}] Raw pill radius detected (999/100). Use AppTokens.radiusPill.")

        # 3. Check for hardcoded breakpoint width comparisons bypassing AppBreakpoints
        if not is_token_file:
            if re.search(r'MediaQuery\.(?:of\(context\)\.)?size(?:Of\(context\))?\.width\s*[><=]+\s*\d+', line):
                violations.append(f"[{rel_path}:{idx}] Hardcoded MediaQuery width comparison. Use AppBreakpoints helper methods.")

        # 4. Check for bare size / fontSize literal on newly created/migrated files
        if not is_token_file and rel_path not in SIZE_LEGACY_FILES:
            if re.search(r'\b(fontSize|size):\s*\d+(\.\d+)?\b', line):
                violations.append(f"[{rel_path}:{idx}] Bare size literal detected outside legacy whitelist. Use AppTokens typography/icon size tokens.")

        # 5. Check for bare EdgeInsets literal on newly created/migrated files
        if not is_token_file and rel_path not in EDGE_INSETS_LEGACY_FILES:
            if re.search(r'EdgeInsets\.(all|symmetric|fromLTRB|only)\([^)]*\d', line):
                violations.append(f"[{rel_path}:{idx}] Bare EdgeInsets numeric literal detected outside legacy whitelist. Use AppTokens spacing tokens.")

def main():
    print("Checking token discipline across lib/ (Ratchet mode: zero tolerance on new files)...")
    for root, _, files in os.walk(LIB_DIR):
        for f in files:
            if f.endswith('.dart'):
                check_file(os.path.join(root, f))

    if violations:
        print(f"FAILED: Found {len(violations)} token discipline violations:")
        for v in violations:
            print(f"  - {v}")
        sys.exit(1)
    else:
        print("PASSED: No token discipline violations found!")
        sys.exit(0)

if __name__ == '__main__':
    main()
