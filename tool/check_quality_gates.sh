#!/usr/bin/env bash
# ==============================================================================
# 代码质量与架构边界自动化检查闸门 (tool/check_quality_gates.sh)
# 
# 包含 3 道守卫：
# 1. 架构分层守卫：禁止 core 层反向依赖 features 层，禁止 db 层反向依赖 sync 层
# 2. 代码格式守卫：强制 dart format 校验
# 3. 巨型文件守卫：棘轮硬阻断 > 800 行的 UI/逻辑单文件（当前基线 15 个，只减不增）
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================="
echo "🛡️  [Quality Gate 1/3] 架构分层完整性守卫..."
echo "=========================================="

# 零容忍严格守卫：没有任何 core 文件允许反向依赖 features
python3 - << 'EOF'
import os
import sys

repo_root = '.'
violations = []

# 1. 检查 core -> features 反向依赖（严格零容忍）
core_dir = os.path.join(repo_root, 'lib', 'core')
for root, _, files in os.walk(core_dir):
    for f in files:
        if f.endswith('.dart'):
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, repo_root)
            if rel_path.startswith('./'):
                rel_path = rel_path[2:]
            
            with open(full_path, 'r', encoding='utf-8') as fp:
                for idx, line in enumerate(fp, 1):
                    line_s = line.strip()
                    if line_s.startswith('import ') and ('package:ordo/features/' in line_s or 'features/' in line_s):
                        violations.append((rel_path, idx, line_s, 'core -> features 反向导入违规'))

# 2. 检查 db -> sync 反向依赖
db_dir = os.path.join(repo_root, 'lib', 'core', 'db')
for root, _, files in os.walk(db_dir):
    for f in files:
        if f.endswith('.dart'):
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, repo_root)
            with open(full_path, 'r', encoding='utf-8') as fp:
                for idx, line in enumerate(fp, 1):
                    line_s = line.strip()
                    if line_s.startswith('import ') and ('core/sync' in line_s or 'sync/' in line_s):
                        violations.append((rel_path, idx, line_s, 'db -> sync 反向导入违规'))

if violations:
    print(f"❌ 发现 {len(violations)} 处架构分层越界违规：")
    for file, line, content, reason in violations:
        print(f"   {file}:{line} [{reason}]: {content}")
    sys.exit(1)
else:
    print("✅ 架构分层守卫通过：lib/core 与 lib/core/db 实现 100% 绝对纯净单向依赖，零过渡白名单！")
EOF

echo ""
echo "=========================================="
echo "🛡️  [Quality Gate 2/3] Dart 代码格式守卫..."
echo "=========================================="
if ! dart format --output=none --set-exit-if-changed lib/ test/ tool/; then
  echo "❌ Dart 代码格式校验未通过！请在本地运行 dart format . 并提交："
  dart format --output=summary lib/ test/ tool/
  exit 1
fi
echo "✅ Dart 格式规范检查通过！"

echo ""
echo "=========================================="
echo "🛡️  [Quality Gate 3/3] 巨型文件健康度巡检（棘轮守卫）..."
echo "=========================================="
python3 - << 'EOF'
import os
import sys

repo_root = '.'
# 忽略生成的本地化代码和用户手册长文本
IGNORE_PATHS = {
    'lib/core/l10n/app_localizations.dart',
    'lib/core/l10n/app_localizations_en.dart',
    'lib/core/l10n/app_localizations_zh.dart',
    'lib/features/settings/user_manual_page.dart',
}

# 棘轮上限：当前基线 15 个，后续重构治理只许减少不许增加
MAX_ALLOWED = 15

large_files = []
for root, _, files in os.walk(os.path.join(repo_root, 'lib')):
    for f in files:
        if f.endswith('.dart') and not f.endswith('.g.dart'):
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, repo_root)
            if rel_path.startswith('./'):
                rel_path = rel_path[2:]
            if rel_path in IGNORE_PATHS:
                continue
            with open(full_path, 'r', encoding='utf-8') as fp:
                line_count = len(fp.readlines())
                if line_count > 800:
                    large_files.append((rel_path, line_count))

large_files.sort(key=lambda x: x[1], reverse=True)
print(f"ℹ️  当前 lib/ 下超过 800 行的业务/UI 文件共 {len(large_files)} 个（棘轮基准上限: {MAX_ALLOWED}）：")
for p, l in large_files[:10]:
    print(f"   - {p} ({l} 行)")
if len(large_files) > 10:
    print(f"   ... 及其余 {len(large_files) - 10} 个文件")

if len(large_files) > MAX_ALLOWED:
    print(f"\n❌ [棘轮违规] 巨型文件数量 ({len(large_files)}) 超过允许上限 ({MAX_ALLOWED})！")
    print(f"   严禁新增 >800 行单文件。请拆分子组件或下沉业务逻辑至独立模块。")
    sys.exit(1)

print(f"✅ 巨型文件棘轮守卫通过：当前 {len(large_files)}/{MAX_ALLOWED}，未发生破窗增长。")
EOF

echo ""
echo "=========================================="
echo "🎉 质量与架构闸门全部通过！"
echo "=========================================="
