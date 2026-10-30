#!/usr/bin/env bash
#
# 插件自带的 SessionStart hook：为当前项目自动安装 AI 开发规范。
#
# 为什么放在插件里而不是用户全局配置：
#   - 作用域跟随插件安装位置，local scope 装的项目才生效
#   - 不需要用户改 ~/.claude/settings.json
#   - 卸载插件即失效，不留残留
#
# 保护措施（每条对应一个真实风险）：
#   1. 只在 git 仓库执行 —— 临时目录、家目录跳过
#   2. 已有 AGENTS.md 就静默退出 —— 幂等，不会每次会话重写
#   3. 有 .claude/no-ai-dev-standards 就跳过 —— 单个项目永久豁免
#   4. 任何失败都 exit 0 —— hook 卡住会拖慢所有会话启动
#   5. stdout 进 Claude 上下文 —— 让 Claude 知道刚装了什么
#
# 豁免方式：
#   mkdir -p .claude && touch .claude/no-ai-dev-standards    # 单项目
#   AI_DEV_STANDARDS_SKIP=1 claude                            # 单次会话

set -uo pipefail

[ "${AI_DEV_STANDARDS_SKIP:-0}" = "1" ] && exit 0

project="${CLAUDE_PROJECT_DIR:-$PWD}"
plugin="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

cd "$project" 2>/dev/null || exit 0

# 不是 git 仓库，不管
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# 已经装过，静默退出
[ -f AGENTS.md ] && exit 0

# 项目明确豁免
[ -f .claude/no-ai-dev-standards ] && exit 0

# 找不到安装器就放弃（插件结构异常）
[ -f "$plugin/install.sh" ] || exit 0

out=$(bash "$plugin/install.sh" "$project" --with-hooks --with-ci 2>&1) || exit 0

echo "[ai-dev-standards] 本项目还没有 AI 开发规范，已自动安装。"
echo "$out" | grep -E '写入|跳过' | sed 's/^/  /'
echo ""
echo "  下一步：填 .agents/project-profile.md —— 里面全是「未定」，需逐项确认后再开工。"
echo "  豁免本项目：mkdir -p .claude && touch .claude/no-ai-dev-standards"
