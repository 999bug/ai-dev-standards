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
#   --minimal       只装 AGENTS.md + .agents/（项目根只多 2 个条目，不装钩子）
#                   适合不用 Claude Code 的场景；与 --with-check / --with-ci / --no-hooks 互斥
#   --no-hooks      不装 git 钩子（默认是装的）
#   --with-check    额外装 scripts/check.sh（五项自检）
#   --with-ci       额外装 .github/workflows/check.yml；会自动带上 scripts/check.sh，
#                   因为 CI 里跑的就是那个脚本
#   --force         覆盖已存在的文件（危险，先确认）
#   --dry-run       只打印将要做什么，不落盘
#
# 钩子装到 .git/hooks/（git 默认位置），不占项目根目录条目，也不需要 core.hooksPath。
# 代价是它不进版本控制：别人 clone 后要各自装一次。想团队共享钩子可自己改成
# core.hooksPath 方案，本安装器不做。
#
# 分级（项目根目录新增的条目数）：
#   --minimal                       2 个：AGENTS.md、.agents/
#   （默认）                        3 个：再加 CLAUDE.md
#                                  另有 .git/hooks/ 下的两个钩子（不计入根目录）
#   + --with-check                  4 个：再加 scripts/
#   + --with-ci                     5 个：再加 scripts/、.github/
#
# 例子：
#   ./install.sh ~/code/my-project --dry-run
#   ./install.sh ~/code/my-project --minimal
#   ./install.sh ~/code/my-project --no-hooks
#   ./install.sh ~/code/my-project --with-check --with-ci
#
# 设计原则：不覆盖已存在的文件。目标项目可能已经改过 AGENTS.md 或某个模块，
# 直接覆盖等于抹掉别人的工作。要覆盖必须显式加 --force。
# 钩子是例外：装了才生效，所以已有同名钩子会先备份再覆盖。

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

target="."
with_ci=0
with_hooks=1          # 默认装钩子
with_check=0          # 默认不装自检脚本
minimal=0
force=0
dry=0

for arg in "$@"; do
    case "$arg" in
        --minimal)    minimal=1 ;;
        --no-hooks)   with_hooks=0 ;;
        --with-hooks) with_hooks=1 ;;   # 兼容旧写法，已是默认行为
        --with-check) with_check=1 ;;
        --with-ci)    with_ci=1 ;;
        --force)      force=1 ;;
        --dry-run)    dry=1 ;;
        -h|--help)    sed -n '2,46p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)           echo "未知选项: $arg" >&2; exit 2 ;;
        *)            target="$arg" ;;
    esac
done

# CI 里跑的就是 scripts/check.sh，要装 CI 就必须带上它
if [ "$with_ci" -eq 1 ]; then
    with_check=1
fi

if [ "$minimal" -eq 1 ] && { [ "$with_ci" -eq 1 ] || [ "$with_check" -eq 1 ] || [ "$with_hooks" -eq 0 ]; }; then
    echo '--minimal 与 --with-check / --with-ci / --no-hooks 互斥。' >&2
    echo '--minimal 本身就是「只装核心」，不需要再叠加这些开关。' >&2
    exit 2
fi

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

# ---------- 核心：AGENTS.md + .agents/ ----------
log "1. 核心规范"
put "$REPO_ROOT/AGENTS.md" "$target/AGENTS.md"
for f in "$REPO_ROOT"/.agents/*.md; do
    [ -e "$f" ] || continue
    put "$f" "$target/.agents/$(basename "$f")"
done

if [ "$minimal" -eq 1 ]; then
    # ---------- minimal：到此为止 ----------
    log ""
    log "2. 已跳过（--minimal）：CLAUDE.md、scripts/check.sh、钩子、CI"
    log "   ! 没装 CLAUDE.md，Claude Code 将读不到这套规范。"
    log "     需要的话去掉 --minimal 重跑，或手动建 CLAUDE.md 写一行 @AGENTS.md"
else
    # ---------- 工具入口：CLAUDE.md ----------
    log "2. 工具入口"
    put "$REPO_ROOT/CLAUDE.md" "$target/CLAUDE.md"

    # ---------- 自检脚本（按需） ----------
    if [ "$with_check" -eq 1 ]; then
        if [ "$with_ci" -eq 1 ]; then
            log "3. 自检脚本（CI 依赖它，自动带上）"
        else
            log "3. 自检脚本"
        fi
        put "$REPO_ROOT/scripts/check.sh" "$target/scripts/check.sh"
        if [ "$dry" -eq 0 ] && [ -f "$target/scripts/check.sh" ]; then
            chmod +x "$target/scripts/check.sh"
        fi
    fi

    if [ "$with_ci" -eq 1 ]; then
        log "4. GitHub Actions 门禁"
        put "$REPO_ROOT/templates/github/check.yml" "$target/.github/workflows/check.yml"
    fi

    if [ "$with_hooks" -eq 1 ]; then
        log "5. git 钩子"

        git_dir=""
        if git -C "$target" rev-parse --absolute-git-dir >/dev/null 2>&1; then
            git_dir=$(git -C "$target" rev-parse --absolute-git-dir)
        fi

        if [ -z "$git_dir" ]; then
            log "  ! 目标不是 git 仓库，跳过钩子安装（装到 .git/hooks/ 需要仓库）"
        else
            hook_dir="$git_dir/hooks"

            # core.hooksPath 一旦设置，git 就完全不看 .git/hooks/ 了
            configured_hooks_path=$(git -C "$target" config core.hooksPath 2>/dev/null)
            if [ -n "$configured_hooks_path" ]; then
                log "  ! 该项目已配置 core.hooksPath=$configured_hooks_path"
                log "    git 会忽略 .git/hooks/，刚装的钩子不会生效。"
                log "    用之前先执行：git config --unset core.hooksPath"
            fi

            for h in commit-msg post-commit; do
                src="$REPO_ROOT/templates/githooks/$h"
                dst="$hook_dir/$h"
                [ -f "$src" ] || continue

                if [ "$dry" -eq 1 ]; then
                    log "  [预览] .git/hooks/$h"
                    copied=$((copied + 1))
                    continue
                fi

                mkdir -p "$hook_dir"

                # 钩子必须覆盖才生效，但已有的先备份，不静默丢用户的钩子
                if [ -f "$dst" ]; then
                    backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
                    if cp "$dst" "$backup" 2>/dev/null; then
                        log "  已有 $h，已备份为 $(basename "$backup")"
                    else
                        log "  ! 已有 $h，备份失败，仍继续覆盖"
                    fi
                fi

                cp "$src" "$dst" && chmod +x "$dst" && copied=$((copied + 1))
            done
        fi
    else
        log "4. 已跳过钩子（--no-hooks）"
    fi
fi

# ---------- 汇总 ----------
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
    if [ -f "$target/scripts/check.sh" ] && [ "$dry" -eq 0 ]; then
        log ""
        log "验证安装：cd \"$target\" && bash scripts/check.sh"
    fi
fi
