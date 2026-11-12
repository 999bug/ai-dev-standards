#!/usr/bin/env bash
#
# AI 开发规范：全局装一次，项目只初始化一次。
#
# 两种模式：
#   ./install.sh --global [--upgrade]    把规范装到全局目录（默认 ~/.ai-dev-standards）
#   ./install.sh [目标目录]               初始化项目（默认当前目录）
#
# 全局目录装什么：AGENTS.md + .agents/ 全部模块 + scripts/ + templates/
# 项目初始化装什么：AGENTS.md（指针）、CLAUDE.md（一行）、
#                  .agents/project-profile.md、.git/hooks/ 下两个钩子
#
# 选项：
#   --global        装到全局目录，不碰任何项目
#   --upgrade       升级已装的全局目录（隐含 --global）
#   --no-hooks      项目初始化时不装 git 钩子
#   --force         覆盖已存在的文件（连备份也不做判断，危险）
#   --dry-run       只打印将要做什么，不落盘
#   -h, --help      显示本帮助
#
# 环境变量：
#   AI_DEV_STANDARDS_HOME   全局目录位置，默认 ~/.ai-dev-standards
#
# 全局目录可以就是本仓库（git clone 到 ~/.ai-dev-standards），这时不复制文件，
# 升级用 git pull，install.sh 只负责刷新清单。
#
# 升级语义：
#   全局：hash 与清单一致（装完没被改过）→ 覆盖；不一致（你改过）→
#         先备份到 .backup/<时间戳>/ 再覆盖，汇总里列出备份位置
#   项目：永不覆盖 project-profile.md；AGENTS.md / CLAUDE.md 只在
#         「内容与模板相同」或「确认是我们以前写的指针」时更新
#
# 1.13.0 起不再支持 --minimal / --with-check / --with-ci / --all-modules /
# --modules= / --shared-hooks：模块全量装进全局目录，项目侧不再有副本，
# 这套裁剪与项目级门禁的开关失去意义。命中旧参数会明确报错，不静默忽略。

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GLOBAL_HOME="${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}"
case "$GLOBAL_HOME" in
    '~')   GLOBAL_HOME="$HOME" ;;
    '~/'*) GLOBAL_HOME="$HOME/${GLOBAL_HOME#\~/}" ;;
esac

mode="project"
target="."
upgrade=0
no_hooks=0
force=0
dry=0

for arg in "$@"; do
    case "$arg" in
        --global)    mode="global" ;;
        --project)   mode="project" ;;
        --upgrade)   upgrade=1; mode="global" ;;
        --no-hooks)  no_hooks=1 ;;
        --force)     force=1 ;;
        --dry-run)   dry=1 ;;
        --minimal|--with-check|--with-ci|--all-modules|--shared-hooks)
            echo "1.13.0 起不再支持 $arg。" >&2
            echo "模块现在全量装进全局目录，项目侧只初始化 3 个文件，不需要裁剪或项目级门禁开关。" >&2
            echo "用法：./install.sh --global 装一次；之后在项目里跑 ./install.sh" >&2
            exit 2 ;;
        --modules=*)
            echo "1.13.0 起不再支持 --modules：全局目录全量安装，不再按项目裁剪。" >&2
            exit 2 ;;
        -h|--help)
            awk 'NR==1{next} /^#/{sub(/^# ?/,""); if ($0 == "" && !shown) next; shown=1; print; next} {exit}' "${BASH_SOURCE[0]}"
            exit 0 ;;
        -*) echo "未知选项: $arg" >&2; exit 2 ;;
        *)  target="$arg" ;;
    esac
done

if [ ! -f "$REPO_ROOT/AGENTS.md" ] || [ ! -d "$REPO_ROOT/.agents" ]; then
    echo "找不到模板文件，确认本脚本位于 ai-dev-standards 仓库根目录。" >&2
    echo "当前目录: $REPO_ROOT" >&2
    exit 1
fi

# 版本号只有一个来源：插件清单
VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$REPO_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -1)
[ -n "$VERSION" ] || VERSION="unknown"

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

stamp=$(date +%Y%m%d-%H%M%S)

# ============================================================================
# 全局模式
# ============================================================================
if [ "$mode" = "global" ]; then
    ghome="$GLOBAL_HOME"

    # 用物理路径比较：Windows 下 F:/x 与 /f/x 是同一个目录，字符串比会失手
    same_place=0
    if [ -d "$ghome" ]; then
        ghome_phys=$(cd "$ghome" 2>/dev/null && pwd)
        [ -n "$ghome_phys" ] && [ "$ghome_phys" = "$REPO_ROOT" ] && same_place=1
    fi

    if [ -d "$ghome" ] && [ "$same_place" -eq 0 ] && [ ! -w "$ghome" ]; then
        echo "全局目录不可写: $ghome" >&2
        exit 1
    fi

    manifest="$ghome/.standards-version"

    recorded() {
        [ -f "$manifest" ] || return 0
        awk -v p="$1" '$1 == "file" && $2 == p { h = $3; sub(/\r$/, "", h); print h; exit }' "$manifest" 2>/dev/null
    }

    files=()
    files+=("AGENTS.md")
    for f in "$REPO_ROOT"/.agents/*.md; do
        [ -e "$f" ] && files+=(".agents/$(basename "$f")")
    done
    files+=("scripts/check.sh")
    files+=("scripts/detect-profile.sh")
    files+=("templates/githooks/commit-msg")
    files+=("templates/githooks/post-commit")
    files+=("templates/project/AGENTS.md")
    files+=("templates/project/CLAUDE.md")
    files+=("templates/github/check.yml")

    new_count=0
    upd_count=0
    skip_count=0
    backup_count=0
    skip_list=""
    backup_list=""
    managed=()
    preserved=()

    put_global() {  # src rel
        local src="$1" rel="$2" dst="$ghome/$rel" rec

        if [ ! -e "$dst" ]; then
            if [ "$dry" -eq 1 ]; then
                log "  [预览] 新增 $rel"
            elif ! { mkdir -p "$(dirname "$dst")" && cp "$src" "$dst"; }; then
                log "  ! 写入失败：$rel" >&2
                return 0
            fi
            new_count=$((new_count + 1))
            managed+=("$rel")
            return 0
        fi

        if cmp -s "$src" "$dst"; then
            skip_count=$((skip_count + 1))
            managed+=("$rel")
            return 0
        fi

        # 内容不同：判断是「旧版」还是「用户改过」
        rec=$(recorded "$rel")
        untouched=0
        if [ "$force" -eq 1 ] || [ "$upgrade" -eq 0 ]; then
            untouched=1
        elif [ -n "$rec" ] && [ "$rec" = "$(sha "$dst")" ]; then
            untouched=1
        fi

        if [ "$untouched" -eq 1 ]; then
            if [ "$dry" -eq 1 ]; then
                log "  [预览] 更新 $rel"
            else
                mkdir -p "$(dirname "$dst")" && cp "$src" "$dst"
            fi
            upd_count=$((upd_count + 1))
            managed+=("$rel")
            return 0
        fi

        # 用户改过：备份后覆盖。全局目录是安装产物，不是工作区；
        # 真要定制应该写进项目的 profile overrides，而不是改全局模块。
        if [ "$dry" -eq 1 ]; then
            log "  [预览] 你改过 $rel → 备份到 .backup/$stamp/ 后覆盖"
            upd_count=$((upd_count + 1))
            managed+=("$rel")
            return 0
        fi

        bdir="$ghome/.backup/$stamp"
        if mkdir -p "$bdir/$(dirname "$rel")" 2>/dev/null && cp "$dst" "$bdir/$rel" 2>/dev/null; then
            backup_count=$((backup_count + 1))
            backup_list="$backup_list $rel"
            cp "$src" "$dst"
            upd_count=$((upd_count + 1))
            managed+=("$rel")
        else
            log "  ! 备份失败，保留原文件：$rel" >&2
            skip_count=$((skip_count + 1))
            skip_list="$skip_list $rel"
            [ -n "$rec" ] && preserved+=("$rel $rec")
        fi
    }

    log "模板来源: $REPO_ROOT"
    log "全局目录: $ghome"
    log "规范版本: $VERSION"
    log ""

    if [ "$same_place" -eq 1 ]; then
        log "1. 全局规范"
        log "  全局目录就是本仓库，不复制文件（升级用 git pull）。"
        for rel in "${files[@]}"; do
            [ -e "$ghome/$rel" ] || log "  ! 缺少 $rel" >&2
            managed+=("$rel")
            skip_count=$((skip_count + 1))
        done
    else
        log "1. 全局规范"
        for rel in "${files[@]}"; do
            put_global "$REPO_ROOT/$rel" "$rel"
        done
    fi

    # ---------- 清单 ----------
    write_manifest() {
        [ "$dry" -eq 1 ] && return 0
        [ "${#managed[@]}" -eq 0 ] && return 0

        local tmp src_kind
        tmp="$(mktemp 2>/dev/null)" || return 0

        src_kind="copy"
        [ "$same_place" -eq 1 ] && src_kind="repo"
        if [ "$same_place" -eq 0 ] && git -C "$ghome" rev-parse --git-dir >/dev/null 2>&1; then
            src_kind="git"
        fi

        mkdir -p "$ghome"
        {
            printf '%s\n' "# ai-dev-standards 全局安装清单，install.sh 生成，不要手改。"
            printf '%s\n' "# 用途：--upgrade 用这里的 sha256 判断文件是否被本地改过。"
            printf 'version=%s\n' "$VERSION"
            printf 'installed=%s\n' "$(date +%Y-%m-%d)"
            printf 'source=%s\n' "$src_kind"
            for rel in "${managed[@]}"; do
                [ -f "$ghome/$rel" ] || continue
                printf 'file %s %s\n' "$rel" "$(sha "$ghome/$rel")"
            done
            if [ "${#preserved[@]}" -gt 0 ]; then
                for entry in "${preserved[@]}"; do
                    printf 'file %s\n' "$entry"
                done
            fi
        } > "$tmp"

        # 用 mv 收尾：内容相同时直接覆盖也算「没变」，git 不会当成改动。
        # 不用 rm —— 某些环境的 rm 被安全包装拦截，会刷一行没意义的报错。
        cmp -s "$tmp" "$manifest" 2>/dev/null || cat "$tmp" > "$manifest"
        mv -f "$tmp" "$manifest" 2>/dev/null || true
    }

    write_manifest

    log ""
    log "────────────────────────────"
    log "写入 $new_count 个文件，更新 $upd_count 个，跳过 $skip_count 个已存在的文件"
    if [ "$backup_count" -gt 0 ]; then
        log "你改过的 $backup_count 个文件已备份到 $ghome/.backup/$stamp/"
        for f in $backup_list; do log "  $f"; done
    fi
    if [ -n "$skip_list" ]; then
        log "以下文件写入失败或被保留：$skip_list"
    fi
    [ "$dry" -eq 0 ] && [ -f "$manifest" ] && log "安装清单: $manifest（version=$VERSION）"
    log ""
    log "项目侧不需要升级：那里只有指针和 project-profile，内容固定。"
    log "新项目初始化：cd <项目> && $REPO_ROOT/install.sh"
    exit 0
fi

# ============================================================================
# 项目模式
# ============================================================================
if [ ! -d "$target" ]; then
    echo "目标目录不存在: $target" >&2
    exit 1
fi
target="$(cd "$target" && pwd)"

if [ "$target" = "$REPO_ROOT" ]; then
    echo "目标目录就是本仓库，跳过。" >&2
    echo "要装全局目录请用 --global；初始化别的项目请传项目路径。" >&2
    exit 1
fi

if [ "$target" = "$GLOBAL_HOME" ]; then
    echo "目标目录就是全局目录，不能在这里初始化项目。" >&2
    exit 1
fi

if [ ! -f "$GLOBAL_HOME/AGENTS.md" ] || [ ! -d "$GLOBAL_HOME/.agents" ]; then
    echo "全局规范未安装：$GLOBAL_HOME" >&2
    echo "" >&2
    echo "先装一次（所有项目共用）：" >&2
    echo "  $REPO_ROOT/install.sh --global" >&2
    echo "" >&2
    echo "或用插件命令：/ai-dev-standards:install（它会先确保全局已装）" >&2
    exit 1
fi

# ---------- 旧结构检测：只报告，不删任何文件 ----------
legacy_modules=""
legacy_other=""
if [ -d "$target/.agents" ]; then
    for f in "$target"/.agents/*.md; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        [ "$base" = "project-profile.md" ] && continue
        legacy_modules="$legacy_modules .agents/$base"
    done
fi
[ -f "$target/.agents/.standards-version" ] && legacy_other="$legacy_other .agents/.standards-version"
# 旧版的 AGENTS.md 是整份规范副本，带 last-verified；新指针里没有这一行
if [ -f "$target/AGENTS.md" ] && grep -q '^last-verified:' "$target/AGENTS.md" 2>/dev/null; then
    legacy_other="$legacy_other AGENTS.md"
fi
legacy_count=$(printf '%s\n' $legacy_modules $legacy_other | grep -c .)

if [ -n "$legacy_modules$legacy_other" ]; then
    log "目标项目: $target"
    log ""
    log "这个项目装的是 1.12.x 及更早的结构：规范副本在项目里，一共 ${legacy_count} 处。"
    log "新结构下项目侧只留 AGENTS.md（指针）、CLAUDE.md 和 .agents/project-profile.md。"
    log ""
    log "需要清理的："
    for f in $legacy_modules $legacy_other; do log "  $f"; done
    log ""

    # 只删我们自己装的模块，profile 和人写的文件必须留下
    if git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
        log "确认无误后执行（project-profile.md 不动）："
        log "  cd \"$target\""
        log "  git rm -q$legacy_modules$legacy_other"
        log "  $REPO_ROOT/install.sh \"$target\""
        log ""
        log "  没提交过的文件 git rm 会报错，那就把 git rm -q 换成 rm -f。"
    else
        log "确认无误后执行（project-profile.md 不动）："
        log "  cd \"$target\""
        log "  rm -f$legacy_modules$legacy_other"
        log "  $REPO_ROOT/install.sh \"$target\""
    fi
    log ""
    log "本脚本没有删任何文件。清理完重跑一次即可。"
    exit 0
fi

# ---------- 探测事实（给 profile 填初稿） ----------
detect="$GLOBAL_HOME/scripts/detect-profile.sh"
[ -f "$detect" ] || detect="$REPO_ROOT/scripts/detect-profile.sh"
facts=""
[ -f "$detect" ] && facts=$(bash "$detect" "$target" 2>/dev/null)
has_fact() { printf '%s\n' "$facts" | grep -q "^$1="; }
fact() { printf '%s\n' "$facts" | sed -n "s/^$1=//p" | head -1; }

set_field() {  # file key value
    [ -n "${3:-}" ] || return 0
    awk -v k="$2" -v v="$3" '
        !done && $0 ~ ("^" k ":") { print k ": " v; done = 1; next }
        { print }
    ' "$1" > "$1.seed" && mv "$1.seed" "$1"
}

set_lang() {  # file key value [present]
    local p="$1" k="$2" v="$3" present="${4:-0}"
    if [ -n "$v" ]; then
        awk -v k="$k" -v v="$v" '
            $0 ~ ("^  # " k ":") { print "  " k ": " v; next }
            { print }
        ' "$p" > "$p.seed" && mv "$p.seed" "$p"
        set_field "$p" "  $k" "$v"
    elif [ "$present" = "1" ]; then
        return 0
    else
        awk -v k="$k" '
            $0 ~ ("^  " k ":") { print "  # " substr($0, 3); next }
            { print }
        ' "$p" > "$p.seed" && mv "$p.seed" "$p"
    fi
}

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
    set_lang "$p" kotlin "$(fact lang_kotlin)" "$(has_fact has_android_app && echo 1 || echo 0)"
    set_lang "$p" python "$(fact lang_python)" "$(has_fact source_python_files && echo 1 || echo 0)"
    set_lang "$p" vue "$(fact lang_vue)" "$(has_fact source_vue_files && echo 1 || echo 0)"

    set_field "$p" framework "$(fact framework)"
    set_field "$p" package_manager "$(printf '%s' "$(fact package_managers)" | awk '{print $1}')"
    set_field "$p" build_command "$(fact build_command)"
    set_field "$p" test_command "$(fact test_command)"
    set_field "$p" dev_command "$(fact dev_command)"

    # 身份只在仓库自己配过身份时才写，避免把全局公司身份写进开源项目
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

    v=$(printf '%s\n' "$facts" | sed -n 's/^dir=//p' | grep -vE '^(docs|tests|test)$' | head -1)
    set_list_first "$p" ai_scope "$v"

    set_list_first "$p" related_docs "$(fact doc)"
}

new_count=0
upd_count=0
skip_count=0
profile_created=0
agents_custom=0
claude_custom=0

log "目标项目: $target"
log "全局目录: $GLOBAL_HOME"
log "规范版本: $VERSION"
log ""

# ---------- 1. 项目档案 ----------
log "1. 项目档案"
prof_dst="$target/.agents/project-profile.md"
prof_src="$GLOBAL_HOME/.agents/project-profile.md"

if [ ! -e "$prof_dst" ]; then
    if [ "$dry" -eq 1 ]; then
        log "  [预览] 新增 .agents/project-profile.md（并按探测结果填初稿）"
    else
        mkdir -p "$target/.agents"
        if cp "$prof_src" "$prof_dst" 2>/dev/null; then
            profile_created=1
            new_count=$((new_count + 1))
            seed_profile
            log "  新增 .agents/project-profile.md，已按探测结果填好初稿"
        else
            log "  ! 写入失败：.agents/project-profile.md" >&2
        fi
    fi
else
    skip_count=$((skip_count + 1))
    log "  已存在 .agents/project-profile.md，未改动"
fi

# ---------- 2. 入口指针 ----------
log "2. 入口指针"
ptr_src="$GLOBAL_HOME/templates/project/AGENTS.md"
ptr_dst="$target/AGENTS.md"

if [ ! -e "$ptr_dst" ]; then
    if [ "$dry" -eq 1 ]; then
        log "  [预览] 新增 AGENTS.md（指向全局规范）"
    elif mkdir -p "$target" && cp "$ptr_src" "$ptr_dst" 2>/dev/null; then
        new_count=$((new_count + 1))
        log "  新增 AGENTS.md（指向全局规范）"
    else
        log "  ! 写入失败：AGENTS.md" >&2
    fi
elif cmp -s "$ptr_src" "$ptr_dst"; then
    skip_count=$((skip_count + 1))
    log "  AGENTS.md 已是最新指针"
elif grep -q '本文件是指针，不是规范本体' "$ptr_dst" 2>/dev/null; then
    if [ "$dry" -eq 1 ]; then
        log "  [预览] 更新 AGENTS.md（指针有新版本）"
    else
        cp "$ptr_src" "$ptr_dst"
    fi
    upd_count=$((upd_count + 1))
    log "  更新 AGENTS.md（指针有新版本）"
elif [ "$force" -eq 1 ]; then
    if [ "$dry" -eq 1 ]; then
        log "  [预览] 覆盖 AGENTS.md"
    else
        cp "$ptr_src" "$ptr_dst"
    fi
    upd_count=$((upd_count + 1))
    log "  覆盖 AGENTS.md（--force）"
else
    agents_custom=1
    skip_count=$((skip_count + 1))
    log "  ! 已有自定义 AGENTS.md，未覆盖"
fi

cl_src="$GLOBAL_HOME/templates/project/CLAUDE.md"
cl_dst="$target/CLAUDE.md"

if [ ! -e "$cl_dst" ]; then
    if [ "$dry" -eq 1 ]; then
        log "  [预览] 新增 CLAUDE.md（一行 @AGENTS.md）"
    elif cp "$cl_src" "$cl_dst" 2>/dev/null; then
        new_count=$((new_count + 1))
        log "  新增 CLAUDE.md（一行 @AGENTS.md）"
    else
        log "  ! 写入失败：CLAUDE.md" >&2
    fi
elif grep -q '^@AGENTS\.md' "$cl_dst" 2>/dev/null; then
    skip_count=$((skip_count + 1))
    log "  CLAUDE.md 已含 @AGENTS.md"
elif [ "$force" -eq 1 ]; then
    if [ "$dry" -eq 1 ]; then
        log "  [预览] 覆盖 CLAUDE.md"
    else
        cp "$cl_src" "$cl_dst"
    fi
    upd_count=$((upd_count + 1))
    log "  覆盖 CLAUDE.md（--force）"
else
    claude_custom=1
    skip_count=$((skip_count + 1))
    log "  ! 已有自定义 CLAUDE.md，未覆盖"
fi

if [ "$agents_custom" -eq 1 ]; then
    log ""
    log "  手动处理：在 AGENTS.md 开头加一段，指明规范在全局目录——"
    log "    本仓库的 AI 开发规范在 \${AI_DEV_STANDARDS_HOME:-\$HOME/.ai-dev-standards}/"
    log "    开工前先读该目录下的 AGENTS.md，模块路径相对它所在目录。"
    log "    再读本仓库 .agents/project-profile.md。"
fi
if [ "$claude_custom" -eq 1 ]; then
    log ""
    log "  手动处理：在 CLAUDE.md 第一行加 @AGENTS.md"
fi

# ---------- 3. git 钩子 ----------
hook_new=0
hook_skip=0

install_hooks() {
    local git_dir hook_dir src dst h configured
    git_dir=""
    if git -C "$target" rev-parse --absolute-git-dir >/dev/null 2>&1; then
        git_dir=$(git -C "$target" rev-parse --absolute-git-dir)
    fi

    if [ -z "$git_dir" ]; then
        log "  ! 目标不是 git 仓库，跳过钩子安装（装钩子需要仓库）"
        return 0
    fi

    hook_dir="$git_dir/hooks"
    configured=$(git -C "$target" config core.hooksPath 2>/dev/null)
    if [ -n "$configured" ]; then
        log "  ! 该项目已配置 core.hooksPath=$configured"
        log "    git 会忽略 .git/hooks/，刚装的钩子不会生效。"
        log "    处理：git config --unset core.hooksPath"
    fi

    for h in commit-msg post-commit; do
        src="$GLOBAL_HOME/templates/githooks/$h"
        dst="$hook_dir/$h"
        [ -f "$src" ] || continue

        if [ "$dry" -eq 1 ]; then
            if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
                hook_skip=$((hook_skip + 1))
            else
                log "  [预览] .git/hooks/$h"
                hook_new=$((hook_new + 1))
            fi
            continue
        fi

        mkdir -p "$hook_dir"

        if [ -f "$dst" ]; then
            if grep -q 'ai-dev-standards-hook' "$dst" 2>/dev/null; then
                if cmp -s "$src" "$dst"; then
                    hook_skip=$((hook_skip + 1))
                    continue
                fi
                log "  更新 $h（$VERSION）"
            elif [ -f "$dst.local" ]; then
                log "  已有 $h，原钩子保留在 $(basename "$dst").local，未重复备份"
            else
                if cp "$dst" "$dst.local" 2>/dev/null; then
                    log "  已有自定义 $h，保留为 $(basename "$dst").local（规范钩子会接着执行它）"
                else
                    log "  ! 已有 $h，无法保留原钩子，仍继续覆盖"
                fi
            fi
        fi

        cp "$src" "$dst" && chmod +x "$dst" && hook_new=$((hook_new + 1))
    done
}

log ""
log "3. git 钩子"
if [ "$no_hooks" -eq 1 ]; then
    log "  已跳过（--no-hooks）"
else
    install_hooks
fi

# ---------- 汇总 ----------
log ""
log "────────────────────────────"
log "写入 $new_count 个文件，更新 $upd_count 个，跳过 $skip_count 个"
if [ "$no_hooks" -eq 0 ]; then
    log "钩子：新增/更新 $hook_new 个，跳过 $hook_skip 个"
fi
log ""
log "下一步：补齐 .agents/project-profile.md 里剩下的「未定」"
log "  装过插件：/ai-dev-standards:profile"
log "  没装插件：让 AI 按 references/profile-guide.md 的「一键生成」执行"
log ""
log "其他项目只需重复这一步；规范本身升级只跑 install.sh --global --upgrade"
