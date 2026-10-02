#!/usr/bin/env bash
# ==============================================================================
# 代码质量与架构边界自动化检查闸门 (tool/check_quality_gates.sh)
# 
# 包含 6 道守卫：
# 1. 架构分层守卫：禁止 core 层反向依赖 features 层，禁止 db 层反向依赖 sync 层
# 2. 代码格式守卫：强制 dart format 校验
# 3. 巨型文件守卫：棘轮硬阻断 > 800 行的 UI/逻辑单文件（当前基线 14 个，只减不增）
# 4. 循环依赖守卫：棘轮硬阻断 features 间有向图环（当前基线 9 条，只减不增）
# 5. 代码洁净与工作区守卫：全库 TODO/FIXME/HACK 零破窗；禁止跟踪 build/缓存
# 6. 双语国际化守卫：ARB 双向键对称与非空校验、核心 UI 模块零硬编码中文、全库 UI 模块硬编码中文字符串棘轮守卫
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================="
echo "🛡️  [Quality Gate 1/6] 架构分层完整性守卫..."
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
echo "🛡️  [Quality Gate 2/6] Dart 代码格式守卫..."
echo "=========================================="
if ! dart format --output=none --set-exit-if-changed lib/ test/ tool/; then
  echo "❌ Dart 代码格式校验未通过！请在本地运行 dart format . 并提交："
  dart format --output=none lib/ test/ tool/
  exit 1
fi
echo "✅ Dart 格式规范检查通过！"

echo ""
echo "=========================================="
echo "🛡️  [Quality Gate 3/6] 巨型文件健康度巡检（棘轮守卫）..."
echo "=========================================="
python3 - << 'EOF'
import os
import sys

repo_root = '.'
# 忽略生成的本地化代码、设计令牌总线和用户手册长文本
IGNORE_PATHS = {
    'lib/core/l10n/app_localizations.dart',
    'lib/core/l10n/app_localizations_en.dart',
    'lib/core/l10n/app_localizations_zh.dart',
    'lib/core/theme/app_tokens.dart',
    'lib/features/settings/user_manual_page.dart',
}

# 棘轮上限：当前基线 14 个，后续重构治理只许减少不许增加
MAX_ALLOWED = 14

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
echo "🛡️  [Quality Gate 4/6] Feature 循环依赖棘轮守卫..."
echo "=========================================="
python3 - << 'EOF'
import collections
import os
import re
import sys

def resolve(importer, rel):
    t = os.path.normpath(os.path.join(os.path.dirname(importer), rel))
    m = re.match(r'lib/features/([^/]+)/', t)
    return m.group(1) if m else None

g = collections.defaultdict(set)
for root, _, files in os.walk('lib/features'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f)
        m_src = re.match(r'lib/features/([^/]+)/', p)
        if not m_src:
            continue
        src = m_src.group(1)
        for line in open(p, encoding='utf-8'):
            m = re.match(r"\s*import\s+'([^']+)'", line)
            if not m:
                continue
            imp = m.group(1)
            if imp.startswith('package:ordo/features/'):
                dst = imp[len('package:ordo/features/'):].split('/')[0]
            elif imp.startswith('package:'):
                continue
            else:
                dst = resolve(p, imp)
            if dst and dst != src:
                g[src].add(dst)

cycles = set()
def dfs(start, node, path, seen):
    for nxt in sorted(g.get(node, ())):
        if nxt == start:
            c = path[:]
            if c[0] != min(c):
                idx = c.index(min(c))
                c = c[idx:] + c[:idx]
            cycles.add(tuple(c))
        elif nxt not in path and nxt not in seen and nxt >= start:
            dfs(start, nxt, path + [nxt], seen | {nxt})

for n in sorted(g):
    dfs(n, n, [n], set())

MAX_CYCLES = 9  # 循环依赖棘轮基线（当前 9 条，随重构只减不增）
print(f"ℹ️  Feature 间循环依赖: {len(cycles)} 条（棘轮基准上限: {MAX_CYCLES}）")
for c in sorted(cycles, key=lambda x: (len(x), x)):
    print(f"   ({len(c)}) " + " -> ".join(c) + f" -> {c[0]}")

if len(cycles) > MAX_CYCLES:
    print(f"\n❌ [棘轮违规] Feature 循环依赖条数 ({len(cycles)}) 超过上限 ({MAX_CYCLES})！禁止新增循环引用。")
    sys.exit(1)

print(f"✅ 循环依赖棘轮守卫通过：当前 {len(cycles)}/{MAX_CYCLES}，未发生破窗增长。")
EOF

echo ""
echo "=========================================="
echo "🛡️  [Quality Gate 5/6] 代码洁净与工作区防污染守卫..."
echo "=========================================="
python3 - << 'EOF'
import os
import re
import subprocess
import sys

# 1. 零 TODO/FIXME/HACK 破窗守卫
pattern = re.compile(r'\b(TODO|FIXME|HACK)\b')
violations = []
for root, _, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            p = os.path.join(root, f)
            with open(p, 'r', encoding='utf-8') as fp:
                for idx, line in enumerate(fp, 1):
                    if pattern.search(line):
                        violations.append(f"{p}:{idx}: {line.strip()}")

if violations:
    print(f"❌ [代码洁净守卫] 发现 {len(violations)} 处 TODO/FIXME/HACK 遗留：")
    for v in violations[:10]:
        print(f"   {v}")
    sys.exit(1)
print("✅ 代码洁净守卫通过：全库 0 处 TODO/FIXME/HACK 遗留。")

# 2. 工作区构建产物防误跟踪守卫
try:
    tracked = subprocess.check_output(['git', 'ls-files'], text=True).splitlines()
    dirty = [f for f in tracked if re.search(r'(^|/)(__pycache__/|\.pyc$|\.DS_Store$|build/)', f)]
    if dirty:
        print(f"❌ [工作区防污染守卫] 发现构建临时文件被 git 跟踪：")
        for d in dirty:
            print(f"   - {d}")
        sys.exit(1)
    print("✅ 工作区防污染守卫通过：零构建产物/临时缓存被跟踪。")
except Exception as e:
    print(f"⚠️  跳过 git 跟踪状态检查: {e}")
EOF

echo ""
echo "=========================================="
echo "🛡️  [Quality Gate 6/6] 双语国际化与文本硬编码守卫..."
echo "=========================================="
python3 tool/check_i18n.py

echo ""
echo "=========================================="
echo "🎉 6 道质量与架构闸门全部通过！"
echo "=========================================="
