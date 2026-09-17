#!/usr/bin/env bash
# ==============================================================================
# 安装 Git pre-commit hook
# 运行方式: bash tool/install_hooks.sh
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SRC="$REPO_ROOT/tool/verify.sh"
HOOK_DST="$REPO_ROOT/.git/hooks/pre-commit"

if [ ! -d "$REPO_ROOT/.git" ]; then
  echo "❌ 未检测到 .git 目录"
  exit 1
fi

cat << 'EOF' > "$HOOK_DST"
#!/usr/bin/env bash
# Git pre-commit hook: 自动执行令牌完整守卫与静态分析
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
bash "$REPO_ROOT/tool/verify.sh"
EOF

chmod +x "$HOOK_DST"
echo "✅ Git pre-commit hook 已成功安装至 $HOOK_DST"
echo "每次执行 git commit 时将自动运行令牌守卫与质量检查。"
