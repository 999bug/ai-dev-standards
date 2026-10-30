#!/usr/bin/env bash
#
# 把 AI 开发规范装到目标项目。
#
# 本脚本就在仓库根目录，clone 下来直接跑即可，不需要先复制任何文件。
#
# 用法：
#   ./install.sh [目标目录] [选项]
#
# 选项：
#   --with-ci       同时安装 .github/workflows/check.yml
#   --with-hooks    安装 git 钩子并设置 core.hooksPath
#   --force         覆盖已存在的文件（危险，先确认）
#   --dry-run       只打印将要做什么，不落盘
#
# 例子：
#   ./install.sh ~/code/my-project --dry-run
#   ./install.sh ~/code/my-project --with-hooks --with-ci
#   ./install.sh .                       # 装到当前目录
#
# 设计原则：不覆盖已存在的文件。目标项目可能已经改过 AGENTS.md 或某个模块，
# 直接覆盖等于抹掉别人的工作。要覆盖必须显式加 --force。

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

target="."
with_ci=0
with_hooks=0
force=0
dry=0

for arg in "$@"; do
    case "$arg" in
        --with-ci)    with_ci=1 ;;
        --with-hooks) with_hooks=1 ;;
        --force)      force=1 ;;
        --dry-run)    dry=1 ;;
        -h|--help)    sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)           echo "未知选项: $arg" >&2; exit 2 ;;
        *)            target="$arg" ;;
    esac
done

if [ ! -d "$target" ]; then
    echo "目标目录不存在: $target" >&2
    exit 1
fi
target="$(cd "$target" && pwd)"

if [ ! -f "$REPO_ROOT/AGENTS.md" ] || [ ! -d "$REPO_ROOT/.agents" ]; then
    echo "找不到模板文件，确认本脚本位于 ai-dev-standards 仓库根目录。" >&2
    echo "当前目录: $REPO_ROOT" >&2
    exit 1
fi

if [ "$target" = "$REPO_ROOT" ]; then
    echo "目标目录就是本仓库，跳过。" >&2
    exit 1
fi

copied=0
skipped=0
skipped_list=""

log() { printf '%s\n' "$*"; }

put() {
    src=$1
    dst=$2
    rel=${dst#"$target"/}

    if [ -e "$dst" ] && [ "$force" -eq 0 ]; then
        skipped=$((skipped + 1))
        skipped_list="$skipped_list $rel"
        return 0
    fi

    if [ "$dry" -eq 1 ]; then
        log "  [预览] $rel"
        copied=$((copied + 1))
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    copied=$((copied + 1))
}

log "模板来源: $REPO_ROOT"
log "目标项目: $target"
log ""

log "1. 核心规范文件"
put "$REPO_ROOT/AGENTS.md" "$target/AGENTS.md"
put "$REPO_ROOT/CLAUDE.md" "$target/CLAUDE.md"
for f in "$REPO_ROOT"/.agents/*.md; do
    [ -e "$f" ] || continue
    put "$f" "$target/.agents/$(basename "$f")"
done

log "2. 自检脚本"
put "$REPO_ROOT/scripts/check.sh" "$target/scripts/check.sh"
if [ "$dry" -eq 0 ] && [ -f "$target/scripts/check.sh" ]; then
    chmod +x "$target/scripts/check.sh"
fi

if [ "$with_ci" -eq 1 ]; then
    log "3. GitHub Actions 门禁"
    put "$REPO_ROOT/templates/github/check.yml" "$target/.github/workflows/check.yml"
fi

if [ "$with_hooks" -eq 1 ]; then
    log "4. git 钩子"
    put "$REPO_ROOT/templates/githooks/commit-msg"  "$target/templates/githooks/commit-msg"
    put "$REPO_ROOT/templates/githooks/post-commit" "$target/templates/githooks/post-commit"
    if [ "$dry" -eq 0 ] && [ -d "$target/templates/githooks" ]; then
        chmod +x "$target/templates/githooks/"* 2>/dev/null
        if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
            git -C "$target" config core.hooksPath templates/githooks
            log "  core.hooksPath -> templates/githooks"
        else
            log "  ! 目标不是 git 仓库，跳过 hooksPath 配置"
        fi
    fi
fi

log ""
log "────────────────────────────"
log "写入 $copied 个文件，跳过 $skipped 个已存在的文件"

if [ -n "$skipped_list" ]; then
    log ""
    log "以下文件已存在，未被覆盖："
    for f in $skipped_list; do log "  $f"; done
    log ""
    log "确认要覆盖请加 --force 重跑。"
fi

if [ "$dry" -eq 0 ]; then
    log ""
    log "下一步（必须）：填 .agents/project-profile.md"
    log "  文件里全是「未定」。逐项确认后再开工——"
    log "  规范要求 AI 遇到未定项必须停下来问，不许拿示例值当事实。"
    log "  字段说明见 references/profile-guide.md"
    log ""
    log "验证安装：cd \"$target\" && bash scripts/check.sh"
fi
