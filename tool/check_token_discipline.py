#!/usr/bin/env python3
"""
Token discipline check script for todo application.
Enforces design token consistency and prevents token drift across the codebase.
Implements the True Ratchet Pattern:
  - Base rules (monospace font, raw pill radius, hardcoded breakpoint) are zero tolerance across all files.
  - Extended rules (bare fontSize/size numbers, bare EdgeInsets numeric literals) enforce strict count budgets,
    preventing any new violation anywhere in the codebase (both legacy and new files).
    As legacy files are cleaned up, budgets must be ratcheted down.
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

# Directories/files excluded from token scans (single source of truth)
EXCLUDED_DIRS = ['lib/core/theme']
EXCLUDED_FILES = ['lib/core/utils/motion.dart']

# Strict Ratchet Budgets (count-based, non-increasing)
# Baseline as of 2026-10-01 (docs/98)
MAX_SIZE_BUDGET = 263
MAX_EDGE_BUDGET = 216

base_violations = []
size_hits = []
edge_hits = []

size_pattern = re.compile(r'\b(fontSize|size):\s*\d+(\.\d+)?\b')
edge_pattern = re.compile(r'EdgeInsets\.(all|symmetric|fromLTRB|only)\([^)]*\d')

def check_file(filepath):
    rel_path = os.path.relpath(filepath, REPO_ROOT).replace('\\', '/')
    filename = os.path.basename(filepath)
    is_token_file = filename in ALLOWED_TOKEN_FILES

    if any(rel_path.startswith(d) for d in EXCLUDED_DIRS) or rel_path in EXCLUDED_FILES:
        return

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception:
        return

    for idx, line in enumerate(lines, 1):
        raw = line.strip()
        if raw.startswith('//') or raw.startswith('/*') or raw.startswith('*'):
            continue

        # --- 1. Base Rules (Zero Tolerance) ---
        if not is_token_file:
            # 1.1 Monospace font
            if "fontFamily: 'monospace'" in line:
                base_violations.append(f"[{rel_path}:{idx}] Raw monospace font detected. Use AppTokens.fontMonoFamily or fontTabular.")

            # 1.2 Pill radius (999/100)
            if "circular(999)" in line or "circular(100)" in line:
                base_violations.append(f"[{rel_path}:{idx}] Raw pill radius detected (999/100). Use AppTokens.radiusPill.")

            # 1.3 Hardcoded MediaQuery breakpoint width comparisons
            if re.search(r'MediaQuery\.(?:of\(context\)\.)?size(?:Of\(context\))?\.width\s*[><=]+\s*\d+', line):
                base_violations.append(f"[{rel_path}:{idx}] Hardcoded MediaQuery width comparison. Use AppBreakpoints helper methods.")

        # --- 2. Extended Rules (Count Ratchet) ---
        if not is_token_file:
            if size_pattern.search(line):
                size_hits.append((rel_path, idx, raw))

            if edge_pattern.search(line):
                edge_hits.append((rel_path, idx, raw))

def main():
    print(f"Checking token discipline across lib/ (Ratchet Budgets: size<={MAX_SIZE_BUDGET}, EdgeInsets<={MAX_EDGE_BUDGET})...")
    for root, _, files in os.walk(LIB_DIR):
        for f in files:
            if f.endswith('.dart'):
                check_file(os.path.join(root, f))

    failed = False

    # 1. Check Base Zero-Tolerance Violations
    if base_violations:
        print(f"\n❌ [Base Rules] Found {len(base_violations)} zero-tolerance violations:")
        for v in base_violations:
            print(f"  - {v}")
        failed = True
    else:
        print("✅ Base rules passed: 0 violations for monospace, pill radius, and breakpoints.")

    # 2. Check Size Ratchet Budget
    current_size = len(size_hits)
    print(f"ℹ️  Bare size/fontSize count: {current_size} / {MAX_SIZE_BUDGET} max")
    if current_size > MAX_SIZE_BUDGET:
        print(f"\n❌ [Ratchet Exceeded] Bare size literals ({current_size}) exceeded budget ({MAX_SIZE_BUDGET})!")
        print("   Recent additions (first 5):")
        for p, idx, txt in size_hits[-5:]:
            print(f"   - {p}:{idx} -> {txt[:60]}")
        failed = True

    # 3. Check EdgeInsets Ratchet Budget
    current_edge = len(edge_hits)
    print(f"ℹ️  Bare EdgeInsets count: {current_edge} / {MAX_EDGE_BUDGET} max")
    if current_edge > MAX_EDGE_BUDGET:
        print(f"\n❌ [Ratchet Exceeded] Bare EdgeInsets literals ({current_edge}) exceeded budget ({MAX_EDGE_BUDGET})!")
        print("   Recent additions (first 5):")
        for p, idx, txt in edge_hits[-5:]:
            print(f"   - {p}:{idx} -> {txt[:60]}")
        failed = True

    if failed:
        sys.exit(1)
    else:
        print("\n🎉 All token discipline rules and ratchet budgets passed!")
        sys.exit(0)

if __name__ == '__main__':
    main()
