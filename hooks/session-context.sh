#!/usr/bin/env bash
#
# 插件自带的 SessionStart hook：只读，不写项目里的任何文件。
#
# 它只做一件事——把「这个仓库的规范状态」用两三行进到 Claude 的上下文，
# 顺带解决「每次开工都要手动说一句『先读 AGENTS.md』」的摩擦。
#
# 为什么不再自动安装：
#   自动安装会在会话启动时悄悄写 15 个文件、还包括会改变提交行为的 git 钩子，
#   和这套规范自己的第一条红线（先诊断、后动手）直接冲突。安装现在是显式的：
#   用户执行 /ai-dev-standards:install。
#
# 开关：
#   AI_DEV_STANDARDS_SKIP=1     本次会话完全静默
#   AI_DEV_STANDARDS_QUIET=1    已安装且 profile 填好时静默（只保留未填完的告警）

set -uo pipefail

[ "${AI_DEV_STANDARDS_SKIP:-0}" = "1" ] && exit 0

project="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$project" 2>/dev/null || exit 0

# 不是 git 仓库就不说话：临时目录、家目录不该被塞提示
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

if [ -f .agents/project-profile.md ]; then
    undecided=$(grep -cE ':[[:space:]]*未定' .agents/project-profile.md 2>/dev/null)
    undecided=${undecided:-0}

    if [ "${AI_DEV_STANDARDS_QUIET:-0}" = "1" ] && [ "$undecided" -eq 0 ]; then
        exit 0
    fi

    echo "[ai-dev-standards] 本仓库已装这套规范（${undecided} 处「未定」待确认）。"
    if [ "$undecided" -gt 0 ]; then
        echo "  动手前先确认 project-profile.md，不许拿示例值当项目事实。"
    fi
    echo "  改代码前按 AGENTS.md 第 3 节分流表加载模块，不要一次性全读。"
elif [ -f AGENTS.md ]; then
    echo "[ai-dev-standards] 本仓库有 AGENTS.md，但没有 .agents/ 模块，不介入。"
    echo "  要接入：/ai-dev-standards:install"
else
    echo "[ai-dev-standards] 本仓库还没有 AI 开发规范。"
    echo "  安装：/ai-dev-standards:install（默认只装规范文件 + git 钩子）"
fi

exit 0
