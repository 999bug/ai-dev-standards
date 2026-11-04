#!/usr/bin/env bash
#
# 把 AI 开发规范装到目标项目。
#
# 本脚本就在仓库根目录，clone 下来直接跑即可，不需要先复制任何文件。
# Claude Code 插件用户不用手动跑它：插件提供了 /ai-dev-standards:install 命令。
#
# 用法：
#   ./install.sh [目标目录] [选项]
#
# 选项：
#   --minimal       只装 AGENTS.md + .agents/（项目根只多 2 个条目，不装钩子）
#                   适合不用 Claude Code 的场景；与 --with-check / --with-ci / --no-hooks 互斥
#   --no-hooks      不装 git 钩子（默认是装的）
#   --with-check    额外装 scripts/check.sh（七项自检）
#   --with-ci       额外装 .github/workflows/check.yml；会自动带上 scripts/check.sh，
#                   因为 CI 里跑的就是那个脚本
#   --upgrade       升级已装的规范：只覆盖「装完之后没被改过」的文件，
#                   改过的另存为 <文件>.new，不动你的修改
#   --shared-hooks  钩子写进项目的 .githooks/ 并设置 core.hooksPath，
#                   这样钩子跟仓库一起提交，团队 clone 后直接生效
#   --force         覆盖已存在的文件（危险，先确认）
#   --dry-run       只打印将要做什么，不落盘
#
# 钩子默认装到 .git/hooks/（git 默认位置），不占项目根目录条目，也不需要
# core.hooksPath。代价是它不进版本控制：别人 clone 后要各自装一次。
# 想让门禁跟着仓库走，用 --shared-hooks。
#
# 分级（项目根目录新增的条目数）：
#   --minimal                       2 个：AGENTS.md、.agents/
#   （默认）                        3 个：再加 CLAUDE.md
#                                  另有 .git/hooks/ 下的两个钩子（不计入根目录）
#   + --with-check                  4 个：再加 scripts/
#   + --with-ci                     5 个：再加 .github/workflows/
#
# 安装清单写在 .agents/.standards-version，记录版本与每个文件的 sha256。
# --upgrade 靠它区分「安装器写的」和「你改过的」，所以别手改这个文件。
#
# 例子：
#   ./install.sh ~/code/my-project --dry-run
#   ./install.sh ~/code/my-project --minimal
#   ./install.sh ~/code/my-project --upgrade
#   ./install.sh ~/code/my-project --with-check --with-ci
#
# 设计原则：不覆盖已存在的文件。目标项目可能已经改过 AGENTS.md 或某个模块，
# 直接覆盖等于抹掉别人的工作。要覆盖必须显式加 --force。
# 升级走 --upgrade：hash 对得上才覆盖，对不上就另存 .new。
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
upgrade=0
hooks_mode="local"    # local = .git/hooks/；shared = .githooks/ + core.hooksPath

for arg in "$@"; do
    case "$arg" in
        --minimal)      minimal=1 ;;
        --no-hooks)     with_hooks=0 ;;
        --with-hooks)   with_hooks=1 ;;   # 兼容旧写法，已是默认行为
        --with-check)   with_check=1 ;;
        --with-ci)      with_ci=1 ;;
        --upgrade)      upgrade=1 ;;
        --shared-hooks) hooks_mode="shared" ;;
        --force)        force=1 ;;
        --dry-run)      dry=1 ;;
        -h|--help)      awk 'NR==1{next} /^#/{sub(/^# ?/,""); if ($0 == "" && !shown) next; shown=1; print; next} {exit}' "${BASH_SOURCE[0]}"; exit 0 ;;
        -*)             echo "未知选项: $arg" >&2; exit 2 ;;
        *)              target="$arg" ;;
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

# 版本号只有一个来源：插件清单。--upgrade 靠它写进安装清单。
VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -1)
[ -n "$VERSION" ] || VERSION="unknown"

manifest="$target/.agents/.standards-version"

new_count=0
upd_count=0
skip_count=0
conflict_count=0
skip_list=""
conflict_list=""
managed=()
preserved=()

log() { printf '%s\n' "$*"; }

# 三平台兜底：Git Bash / macOS / 只有 openssl 的环境
sha() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" 2>/dev/null | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
    else
        openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
    fi
}

# 安装清单里记录的、安装当时的 hash。没有清单或没记录就返回空。
recorded() {
    [ -f "$manifest" ] || return 0
    awk -v p="$1" '$1 == "file" && $2 == p { h = $3; sub(/\r$/, "", h); print h; exit }' "$manifest" 2>/dev/null
}

write_file() {  # src dst
    mkdir -p "$(dirname "$2")" && cp "$1" "$2"
}

put() {
    local src="$1" dst="$2" rel rec
    rel=${dst#"$target"/}

    # ---------- 目标不存在：新增 ----------
    if [ ! -e "$dst" ]; then
        if [ "$dry" -eq 1 ]; then
            log "  [预览] 新增 $rel"
        elif ! write_file "$src" "$dst"; then
            log "  ! 写入失败：$rel" >&2
            return 0
        fi
        new_count=$((new_count + 1))
        managed+=("$rel")
        return 0
    fi

    # ---------- --force：无条件覆盖 ----------
    if [ "$force" -eq 1 ]; then
        if [ "$dry" -eq 1 ]; then
            log "  [预览] 覆盖 $rel"
        else
            write_file "$src" "$dst"
        fi
        upd_count=$((upd_count + 1))
        managed+=("$rel")
        return 0
    fi

    # ---------- 内容相同：跳过，不打扰 ----------
    if cmp -s "$src" "$dst"; then
        skip_count=$((skip_count + 1))
        managed+=("$rel")
        return 0
    fi

    # ---------- --upgrade：只有「没被改过」才覆盖 ----------
    if [ "$upgrade" -eq 1 ]; then
        rec=$(recorded "$rel")
        if [ -n "$rec" ] && [ "$rec" = "$(sha "$dst")" ]; then
            if [ "$dry" -eq 1 ]; then
                log "  [预览] 更新 $rel"
            else
                write_file "$src" "$dst"
            fi
            upd_count=$((upd_count + 1))
            managed+=("$rel")
            return 0
        fi

        if [ "$dry" -eq 1 ]; then
            log "  [预览] 冲突 $rel → $rel.new（本地有改动，不覆盖）"
        else
            write_file "$src" "$dst.new"
            log "  本地已改动，新版写为 $rel.new（确认后可手动合并）"
        fi
        conflict_count=$((conflict_count + 1))
        conflict_list="$conflict_list $rel"
        # 没装进去，就不能把本地改动后的 hash 记进清单，否则下次 --upgrade
        # 会误判成「没被改过」直接覆盖。保留上一次安装时的记录。
        [ -n "$rec" ] && preserved+=("$rel $rec")
        return 0
    fi

    # ---------- 默认：已存在就跳过 ----------
    skip_count=$((skip_count + 1))
    skip_list="$skip_list $rel"
    managed+=("$rel")
}

log "模板来源: $REPO_ROOT"
log "目标项目: $target"
log "规范版本: $VERSION"
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
            log "  ! 目标不是 git 仓库，跳过钩子安装（装钩子需要仓库）"
        elif [ "$hooks_mode" = "shared" ]; then
            # .githooks/ 跟着仓库走：团队 clone 后不用各自装
            hook_dir="$target/.githooks"
            for h in commit-msg post-commit; do
                src="$REPO_ROOT/templates/githooks/$h"
                [ -f "$src" ] || continue
                put "$src" "$hook_dir/$h"
                [ "$dry" -eq 0 ] && [ -f "$hook_dir/$h" ] && chmod +x "$hook_dir/$h"
            done
            if [ "$dry" -eq 0 ]; then
                git -C "$target" config core.hooksPath .githooks
                log "  已设 core.hooksPath=.githooks，钩子会跟仓库一起提交"
            fi
        else
            hook_dir="$git_dir/hooks"

            # core.hooksPath 一旦设置，git 就完全不看 .git/hooks/ 了
            configured_hooks_path=$(git -C "$target" config core.hooksPath 2>/dev/null)
            if [ -n "$configured_hooks_path" ]; then
                log "  ! 该项目已配置 core.hooksPath=$configured_hooks_path"
                log "    git 会忽略 .git/hooks/，刚装的钩子不会生效。"
                log "    两种处理：git config --unset core.hooksPath（改回 .git/hooks/）"
                log "              或用 --shared-hooks 把钩子装进项目里的 .githooks/"
            fi

            for h in commit-msg post-commit; do
                src="$REPO_ROOT/templates/githooks/$h"
                dst="$hook_dir/$h"
                [ -f "$src" ] || continue

                if [ "$dry" -eq 1 ]; then
                    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
                        skip_count=$((skip_count + 1))
                    else
                        log "  [预览] .git/hooks/$h"
                        new_count=$((new_count + 1))
                    fi
                    continue
                fi

                mkdir -p "$hook_dir"

                # 已有钩子分三种情况处理，不静默停用用户的东西
                if [ -f "$dst" ]; then
                    if grep -q 'ai-dev-standards-hook' "$dst" 2>/dev/null; then
                        # 已经是我们的：内容一样就不重写，这样重复安装才是真幂等
                        if cmp -s "$src" "$dst"; then
                            skip_count=$((skip_count + 1))
                            continue
                        fi
                        log "  更新 $h（$VERSION）"
                        upd_count=$((upd_count + 1))
                    elif [ -f "$dst.local" ]; then
                        log "  已有 $h，原钩子保留在 $(basename "$dst").local，未重复备份"
                    else
                        # 用户自定义钩子：改名成 .local，由我们的钩子链式调用
                        if cp "$dst" "$dst.local" 2>/dev/null; then
                            log "  已有自定义 $h，保留为 $(basename "$dst").local（规范钩子会接着执行它）"
                        else
                            log "  ! 已有 $h，无法保留原钩子，仍继续覆盖"
                        fi
                    fi
                fi

                cp "$src" "$dst" && chmod +x "$dst" && new_count=$((new_count + 1))
            done
        fi
    else
        log "4. 已跳过钩子（--no-hooks）"
    fi
fi

# ---------- 安装清单：给 --upgrade 判断「谁改过」用 ----------
# 不参与「写入 N 个文件」的计数：它是安装器自己的元数据，不是装进项目的内容。
write_manifest() {
    [ "$dry" -eq 1 ] && return 0
    [ "${#managed[@]}" -eq 0 ] && return 0

    local tmp
    tmp="$(mktemp 2>/dev/null)" || return 0

    mkdir -p "$target/.agents"
    {
        printf '%s\n' "# ai-dev-standards 安装清单，install.sh 生成，不要手改。"
        printf '%s\n' "# 用途：--upgrade 用这里的 sha256 判断文件是否被本地改过。"
        printf 'version=%s\n' "$VERSION"
        printf 'installed=%s\n' "$(date +%Y-%m-%d)"
        for rel in "${managed[@]}"; do
            [ -f "$target/$rel" ] || continue
            printf 'file %s %s\n' "$rel" "$(sha "$target/$rel")"
        done
        if [ "${#preserved[@]}" -gt 0 ]; then
            for entry in "${preserved[@]}"; do
                printf 'file %s\n' "$entry"
            done
        fi
    } > "$tmp"

    # 内容没变就不落盘，避免每天多出一条无意义的改动
    if ! cmp -s "$tmp" "$manifest"; then
        cat "$tmp" > "$manifest"
    fi
    rm -f "$tmp"
}

write_manifest

# ---------- 汇总 ----------
log ""
log "────────────────────────────"
log "写入 $new_count 个文件，更新 $upd_count 个，跳过 $skip_count 个已存在的文件"
[ "$dry" -eq 0 ] && [ -f "$manifest" ] && log "安装清单: .agents/.standards-version（version=$VERSION）"

if [ "$conflict_count" -gt 0 ]; then
    log ""
    log "有 $conflict_count 个文件本地改动过，新版另存为 .new："
    for f in $conflict_list; do log "  $f"; done
    log "手动 diff 合并后删掉 .new 即可。"
fi

if [ -n "$skip_list" ]; then
    log ""
    log "以下文件已存在、内容与模板不同，未被覆盖："
    for f in $skip_list; do log "  $f"; done
    log ""
    log "只是版本旧了用 --upgrade；确认要以模板为准请加 --force 重跑。"
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
