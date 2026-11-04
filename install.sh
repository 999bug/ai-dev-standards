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
#   --all-modules   不裁剪，.agents/ 下的模块全装（旧行为）
#   --modules=a,b   只装指定的模块（文件名，不带路径），如 --modules=commit.md,lang-java.md
#   --shared-hooks  钩子写进项目的 .githooks/ 并设置 core.hooksPath，
#                   这样钩子跟仓库一起提交，团队 clone 后直接生效
#   --force         覆盖已存在的文件（危险，先确认）
#   --dry-run       只打印将要做什么，不落盘
#
# 默认按项目裁剪模块（不用 --all-modules 时）：
#   - lang-java / lang-python / lang-vue 只在探测到对应语言时装
#   - release-github 只在用了 GitHub（workflows 或 github remote）时装
#   - release-docker 只在有 Dockerfile / compose 时装
#   跨语言的四件（project-profile、commit、discipline、task-workflow）和方法论两件
#   （integration、legacy）始终装。AGENTS.md 的分流表会同步删掉未装模块的行，
#   不留悬空引用。
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
all_modules=0
only_modules=""
hooks_mode="local"    # local = .git/hooks/；shared = .githooks/ + core.hooksPath

for arg in "$@"; do
    case "$arg" in
        --minimal)      minimal=1 ;;
        --no-hooks)     with_hooks=0 ;;
        --with-hooks)   with_hooks=1 ;;   # 兼容旧写法，已是默认行为
        --with-check)   with_check=1 ;;
        --with-ci)      with_ci=1 ;;
        --upgrade)      upgrade=1 ;;
        --all-modules)  all_modules=1 ;;
        --modules=*)    only_modules="${arg#--modules=}" ;;
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

# ---------- 模块裁剪：只装和这个项目有关的规范 ----------
# 跨语言、任何项目都用得上：项目档案、提交规范、纪律、任务工作流、外部对接、老系统方法论
ALWAYS_MODULES="project-profile.md commit.md discipline.md task-workflow.md integration.md legacy.md"

wanted=""
add_wanted() {
    case " $wanted " in *" $1 "*) return 0 ;; esac
    wanted="${wanted:+$wanted }$1"
}
is_wanted() {
    case " $wanted " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

# 复用 profile 的探测脚本，避免安装器和 /ai-dev-standards:profile 各判断一套
facts=""
if [ -f "$REPO_ROOT/scripts/detect-profile.sh" ]; then
    facts=$(bash "$REPO_ROOT/scripts/detect-profile.sh" "$target" 2>/dev/null)
fi
has_fact() { printf '%s\n' "$facts" | grep -q "^$1="; }
fact() { printf '%s\n' "$facts" | sed -n "s/^$1=//p" | head -1; }

# 把探测到的事实写进 profile 初稿。只填「读得到」的字段；
# type / visibility / verify_* 这类需要人确认或实跑的，留给 /ai-dev-standards:profile。
set_field() {  # file key value
    [ -n "${3:-}" ] || return 0
    awk -v k="$2" -v v="$3" '
        !done && $0 ~ ("^" k ":") { print k ": " v; done = 1; next }
        { print }
    ' "$1" > "$1.seed" && mv "$1.seed" "$1"
}

# 语言块里的示例行要么启用成实际值，要么注释掉——留着示例值会被当成项目事实
set_lang() {  # file key value [present]
    local p="$1" k="$2" v="$3" present="${4:-0}"
    if [ -n "$v" ]; then
        awk -v k="$k" -v v="$v" '
            $0 ~ ("^  # " k ":") { print "  " k ": " v; next }
            { print }
        ' "$p" > "$p.seed" && mv "$p.seed" "$p"
        set_field "$p" "  $k" "$v"
    elif [ "$present" = "1" ]; then
        # 是这门语言，但版本没读到：保留「未定」让人填，别注释掉
        return 0
    else
        awk -v k="$k" '
            $0 ~ ("^  " k ":") { print "  # " substr($0, 3); next }
            { print }
        ' "$p" > "$p.seed" && mv "$p.seed" "$p"
    fi
}

# 只替换某个键下面的第一条 "- 未定"
set_list_first() {  # file key value
    [ -n "${3:-}" ] || return 0
    awk -v k="$2" -v v="$3" '
        $0 ~ ("^" k ":") { inlist = 1; print; next }
        inlist && $0 ~ /^[[:space:]]+- 未定/ { sub(/未定/, v); inlist = 0; print; next }
        inlist && $0 !~ /^[[:space:]]/ { inlist = 0 }
        { print }
    ' "$1" > "$1.seed" && mv "$1.seed" "$1"
}

seed_profile() {
    local p="$target/.agents/project-profile.md" v ch cv
    [ "$dry" -eq 0 ] && [ -f "$p" ] || return 0

    v=$(fact node_name); [ -n "$v" ] || v=$(fact maven_artifact)
    [ -n "$v" ] || v=$(fact python_name); [ -n "$v" ] || v=$(fact dir_name)
    set_field "$p" project "$v"

    v=$(fact node_description); [ -n "$v" ] || v=$(fact maven_description)
    [ -n "$v" ] || v=$(fact python_description); [ -n "$v" ] || v=$(fact readme_first_line)
    set_field "$p" description "$v"

    set_lang "$p" java "$(fact lang_java)" "$(has_fact source_java_files && echo 1 || echo 0)"
    set_lang "$p" python "$(fact lang_python)" "$(has_fact source_python_files && echo 1 || echo 0)"
    set_lang "$p" vue "$(fact lang_vue)" "$(has_fact source_vue_files && echo 1 || echo 0)"

    set_field "$p" framework "$(fact framework)"
    set_field "$p" package_manager "$(printf '%s' "$(fact package_managers)" | awk '{print $1}')"
    set_field "$p" build_command "$(fact build_command)"
    set_field "$p" test_command "$(fact test_command)"
    set_field "$p" dev_command "$(fact dev_command)"

    # 身份只在仓库自己配过身份时才写。否则拿到的是全局配置（可能是公司身份），
    # 写进一个开源项目就错了，留给 /ai-dev-standards:profile 按 type 决定。
    if [ "$(fact git_email_source)" = "local" ]; then
        set_field "$p" git_user_name "$(fact git_user_name)"
        if [ "$(fact git_email_noreply)" = "yes" ]; then
            set_field "$p" git_user_email "$(git -C "$target" config user.email 2>/dev/null)"
        fi
    fi

    ch=$(fact commit_style_company_hits); cv=$(fact commit_style_conventional_hits)
    if [ -n "$ch" ] && [ -n "$cv" ]; then
        [ "$ch" -gt "$cv" ] 2>/dev/null && set_field "$p" commit_style company
        [ "$cv" -gt "$ch" ] 2>/dev/null && set_field "$p" commit_style conventional
    fi

    printf '%s' "$(fact git_remote)" | grep -q github &&
        set_field "$p" issue_tracker "GitHub Issues"

    # 部署目标：只写有证据的。有 Dockerfile 就是容器，什么都没有才是 none。
    # 有 CI 但判断不出目标时留「未定」——写个错的比空着更糟。
    v=$(fact deploy_target)
    [ -n "$v" ] || { [ "$(fact pages)" = "yes" ] && v="pages"; }
    if [ -z "$v" ]; then
        if [ "$(fact has_dockerfile)" = "yes" ]; then
            v="docker"
        elif [ -z "$(fact workflow)" ]; then
            v="none"
        fi
    fi
    set_field "$p" deploy_target "$v"

    if [ -n "$(fact registry)" ]; then
        set_field "$p" registry "$(fact registry)"
    elif [ "$v" = "none" ]; then
        set_field "$p" registry none
    fi
    [ "$(fact pages)" = "yes" ] && set_field "$p" pages yes

    v=$(fact tags)
    case "$v" in
        *v1.0.*) set_field "$p" version_scheme "v1.0.<run_number>" ;;
        *v[0-9]*.[0-9]*.[0-9]*) set_field "$p" version_scheme "语义化 semver" ;;
    esac

    if [ -n "$(fact workflow_secrets)" ]; then
        set_field "$p" secrets_location "GitHub Repository secrets"
    elif [ "$(fact has_env_example)" = "yes" ]; then
        set_field "$p" secrets_location "本地 .env"
    fi

    # ai_scope：取第一个源码目录，跳过文档与测试目录
    v=$(printf '%s\n' "$facts" | sed -n 's/^dir=//p' | grep -vE '^(docs|tests|test)$' | head -1)
    set_list_first "$p" ai_scope "$v"

    set_list_first "$p" related_docs "$(fact doc)"
}


if [ "$all_modules" -eq 1 ]; then
    for f in "$REPO_ROOT"/.agents/*.md; do
        [ -e "$f" ] && add_wanted "$(basename "$f")"
    done
elif [ -n "$only_modules" ]; then
    for m in $(printf '%s' "$only_modules" | tr ',' ' '); do
        if [ ! -f "$REPO_ROOT/.agents/$m" ]; then
            echo "未知模块: $m（可用模块见 .agents/ 目录）" >&2
            exit 2
        fi
        add_wanted "$m"
    done
else
    for m in $ALWAYS_MODULES; do add_wanted "$m"; done
    if has_fact lang_java || has_fact source_java_files; then
        add_wanted lang-java.md
    fi
    if has_fact lang_python || has_fact source_python_files; then
        add_wanted lang-python.md
    fi
    if has_fact lang_vue || has_fact source_vue_files; then
        add_wanted lang-vue.md
    fi
    if has_fact workflow || printf '%s\n' "$facts" | grep -q '^git_remote=.*github'; then
        add_wanted release-github.md
    fi
    if has_fact has_dockerfile || printf '%s\n' "$facts" | grep -q '^deploy_target=docker-compose'; then
        add_wanted release-docker.md
    fi
fi

skipped_modules=""
for f in "$REPO_ROOT"/.agents/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    is_wanted "$base" || skipped_modules="$skipped_modules $base"
done

# 没装的模块不能留在 AGENTS.md 的分流表里，否则 AI 会照表去读不存在的文件
tmpdir=$(mktemp -d 2>/dev/null)
agents_src="$REPO_ROOT/AGENTS.md"
if [ -n "${tmpdir:-}" ] && [ -n "$skipped_modules" ]; then
    cp "$REPO_ROOT/AGENTS.md" "$tmpdir/AGENTS.md"
    for bad in $skipped_modules; do
        # 只删表格行里点名该文件的行，正文里的引用保持原样
        grep -vE "^\|.*\`${bad}\`" "$tmpdir/AGENTS.md" > "$tmpdir/next" 2>/dev/null || true
        mv "$tmpdir/next" "$tmpdir/AGENTS.md"
    done
    agents_src="$tmpdir/AGENTS.md"
fi

new_count=0
upd_count=0
skip_count=0
conflict_count=0
skip_list=""
conflict_list=""
managed=()
preserved=()
profile_kept=0
profile_existed=0
[ -f "$target/.agents/project-profile.md" ] && profile_existed=1

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

    # 升级不动项目档案：里面是项目事实和你手填的结论，模板更新不该覆盖它
    if [ "$upgrade" -eq 1 ] && [ "$rel" = ".agents/project-profile.md" ] && [ -e "$dst" ]; then
        profile_kept=1
        skip_count=$((skip_count + 1))
        managed+=("$rel")
        return 0
    fi

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
put "$agents_src" "$target/AGENTS.md"
for f in "$REPO_ROOT"/.agents/*.md; do
    [ -e "$f" ] || continue
    is_wanted "$(basename "$f")" || continue
    put "$f" "$target/.agents/$(basename "$f")"
done

# 首次安装就按探测结果填好初稿，别让人对着「未定」逐项查
if [ "$upgrade" -eq 0 ] && [ "$profile_existed" -eq 0 ]; then
    seed_profile
    if [ "$dry" -eq 0 ] && [ -f "$target/.agents/project-profile.md" ]; then
        log "  已按探测结果填好 profile 初稿；type / visibility / verify_* 仍需确认"
    fi
fi

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
log "模块：$(printf '%s\n' $wanted | wc -l | tr -d ' ')/11$([ -n "$skipped_modules" ] && printf '（与项目无关，跳过%s）' "$skipped_modules")"
[ "$profile_kept" -eq 1 ] && log "项目档案未改动：升级不改 .agents/project-profile.md（要重整跑 /ai-dev-standards:profile）"
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

if [ "$dry" -eq 0 ] && [ "$profile_kept" -eq 0 ]; then
    log ""
    log "下一步（必须）：生成 .agents/project-profile.md"
    log "  文件里全是「未定」。别手填——装过插件的话跑：/ai-dev-standards:profile"
    log "  它会探测项目事实，只问你几个必须由人决定的选择。"
    log "  规范要求 AI 遇到未定项必须停下来问，不许拿示例值当事实。"
    log "  字段说明见 references/profile-guide.md"
    if [ -f "$target/scripts/check.sh" ] && [ "$dry" -eq 0 ]; then
        log ""
        log "验证安装：cd \"$target\" && bash scripts/check.sh"
    fi
fi

# 裁剪 AGENTS.md 用的临时目录
if [ -n "${tmpdir:-}" ]; then
    rm -f "$tmpdir/AGENTS.md" "$tmpdir/next" 2>/dev/null
    rmdir "$tmpdir" 2>/dev/null || true
fi
