#!/usr/bin/env bash
#
# 插件自带的 SessionStart hook，做两件事：
#   1. 为当前项目自动安装 AI 开发规范（没有才装）
#   2. 检测 codegraph 命令，存在且未建索引时自动 codegraph init
#
# 为什么放在插件里而不是用户全局配置：
#   - 作用域跟随插件安装位置，local scope 装的项目才生效
#   - 不需要用户改 ~/.claude/settings.json
#   - 卸载插件即失效，不留残留
#
# 保护措施（每条对应一个真实风险）：
#   1. 只在 git 仓库执行 —— 临时目录、家目录跳过
#   2. 已有 AGENTS.md 就跳过安装 —— 幂等，不会每次会话重写
#   3. 有 .claude/no-ai-dev-standards 就跳过 —— 单个项目永久豁免
#   4. 任何失败都不影响会话 —— hook 卡住会拖慢所有会话启动
#   5. stdout 进 Claude 上下文 —— 让 Claude 知道刚发生了什么
#
# 豁免方式：
#   mkdir -p .claude && touch .claude/no-ai-dev-standards    # 单项目
#   AI_DEV_STANDARDS_SKIP=1 claude                            # 单次会话
#
# codegraph 相关环境变量：
#   CODEGRAPH_BIN           可执行文件路径或整条命令，如 `npx -y codegraph`
#   CODEGRAPH_INIT_TIMEOUT  首次 init 的超时秒数，默认 120

set -uo pipefail

[ "${AI_DEV_STANDARDS_SKIP:-0}" = "1" ] && exit 0

project="${CLAUDE_PROJECT_DIR:-$PWD}"
plugin="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

cd "$project" 2>/dev/null || exit 0

# 不是 git 仓库就不做任何事
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# ------------------------------------------------------------------ 1. 装规范
install_standards() {
    [ -f AGENTS.md ] && return 0
    [ -f .claude/no-ai-dev-standards ] && return 0
    [ -f "$plugin/install.sh" ] || return 0

    # 用默认级别：不装 git 钩子与 CI。钩子会改变提交行为、CI 会写进 .github/，
    # 这两样应当由用户主动选择，不该由一次会话启动悄悄做掉。
    local out
    out=$(bash "$plugin/install.sh" "$project" 2>&1) || return 0

    echo "[ai-dev-standards] 本项目还没有 AI 开发规范，已自动安装。"
    echo "$out" | grep -E '写入|跳过|备份' | sed 's/^/  /'
    echo ""
    echo "  下一步：填 .agents/project-profile.md —— 里面全是「未定」，需逐项确认。"
    echo "  豁免本项目：mkdir -p .claude && touch .claude/no-ai-dev-standards"
}

# ------------------------------------------------------------------ 2. codegraph
init_codegraph() {
    local bin="${CODEGRAPH_BIN:-codegraph}"
    local first="${bin%% *}"

    # 命令不在就直接跳过，不猜、不装
    command -v "$first" >/dev/null 2>&1 || return 0

    # 已有索引就不再重建
    [ -d .codegraph ] && return 0

    local limit="${CODEGRAPH_INIT_TIMEOUT:-120}"
    echo "[ai-dev-standards] 检测到 codegraph，首次建立索引（上限 ${limit}s）。"

    if command -v timeout >/dev/null 2>&1; then
        timeout "$limit" sh -c "$bin init" >/dev/null 2>&1
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$limit" sh -c "$bin init" >/dev/null 2>&1
    else
        # Git Bash 常不带 coreutils 的 timeout，手写兜底
        sh -c "$bin init" >/dev/null 2>&1 &
        local pid=$!
        ( sleep "$limit" && kill -9 "$pid" 2>/dev/null ) &
        local watcher=$!
        wait "$pid" 2>/dev/null
        kill "$watcher" 2>/dev/null
        wait "$watcher" 2>/dev/null
    fi

    if [ -d .codegraph ]; then
        echo "  索引已建立：.codegraph/"
    else
        echo "  ! 索引未生成或超时，可手动重试：cd \"$project\" && $bin init"
    fi
}

install_standards
init_codegraph

exit 0
