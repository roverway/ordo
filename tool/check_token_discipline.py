#!/usr/bin/env python3
"""
Token discipline check script for todo application.
Enforces design token consistency and prevents token drift across the codebase.
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

violations = []

def check_file(filepath):
    rel_path = os.path.relpath(filepath, REPO_ROOT)
    filename = os.path.basename(filepath)
    is_token_file = filename in ALLOWED_TOKEN_FILES

    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for idx, line in enumerate(lines, 1):
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

def main():
    print("Checking token discipline across lib/...")
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
