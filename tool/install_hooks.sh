#!/usr/bin/env bash
# ==============================================================================
# 配置仓库版本化 Git Hooks (core.hooksPath)
# 运行方式: bash tool/install_hooks.sh
# ==============================================================================
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -d ".git" ]; then
  echo "❌ 未检测到 .git 目录"
  exit 1
fi

chmod +x .githooks/pre-commit
git config core.hooksPath .githooks

# 清理旧的本地未受控 hook
if [ -f ".git/hooks/pre-commit" ]; then
  rm -f ".git/hooks/pre-commit"
fi

echo "✅ Git hooks 路径已成功配置为 .githooks/ (core.hooksPath)"
echo "每次执行 git commit 时将自动运行秒级质量门禁（架构+格式+棘轮守卫，约 3.5s）。"
