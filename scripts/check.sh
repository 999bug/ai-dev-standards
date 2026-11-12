#!/usr/bin/env bash
#
# 本仓库的自检脚本：规范文件自己检查自己。
#
# 检查项（每一项都对应一次真实踩过的坑）：
#   1. 入口行数        AGENTS.md 超过 150 行就该拆模块了
#   2. 真实邮箱        公开仓库的明文邮箱一旦推上去就洗不掉
#   3. 模块登记        新增 .agents/*.md 却忘了在分流表登记 → 永远不会被加载
#   4. 交叉引用        文档里引用的 .md 文件必须真实存在（含 markdown 链接）
#   5. 代码块闭合      结尾漏一个 ``` 会让后面内容渲染成代码
#   6. 数字对账        「N 个模块」「写入 N 个文件」必须和仓库实际一致
#   7. 插件清单        plugin.json 版本 == CHANGELOG 首条；hooks 引用的脚本存在
#
# 用法：
#   bash scripts/check.sh          # 本地跑
#   退出码 0 = 全部通过，1 = 有问题

set -u

cd "$(dirname "$0")/.." || exit 1

fail=0
pass=0

ok() {
    printf '  \033[32m✓\033[0m %s\n' "$1"
    pass=$((pass + 1))
}

bad() {
    printf '  \033[31m✗\033[0m %s\n' "$1"
    fail=$((fail + 1))
}

section() {
    printf '\n%s\n' "$1"
}

# 所有需要检查的文档。docs/ 必须在这里：它占了两个最长的文档，
# 之前漏掉过，结果是往里面塞真实邮箱都能全绿。
docs=$(ls AGENTS.md README.md CLAUDE.md SKILL.md docs/*.md .agents/*.md reviews/*.md references/*.md skills/*/SKILL.md commands/*.md templates/project/*.md 2>/dev/null)

# ---------------------------------------------------------------- 1. 入口行数
section "1. 入口文件长度"
if [ -f AGENTS.md ]; then
    lines=$(wc -l < AGENTS.md | tr -d ' ')
    if [ "$lines" -le 150 ]; then
        ok "AGENTS.md 共 ${lines} 行（上限 150）"
    else
        bad "AGENTS.md 共 ${lines} 行，超过 150 行上限——把细节挪进 .agents/ 模块"
    fi
else
    bad "AGENTS.md 不存在"
fi

# ---------------------------------------------------------------- 2. 真实邮箱
section "2. 明文邮箱"
# 白名单：GitHub 匿名地址、示例域名、反例中出现的第三方 noreply、管道 bot
email_hits=$(grep -rEn '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' $docs 2>/dev/null |
    grep -vE 'noreply\.github\.com|noreply@anthropic\.com' |
    grep -vE 'example\.(com|org|net)' |
    grep -vE 'your-|placeholder|someone@|<[^>]*@[^>]*>')
if [ -z "$email_hits" ]; then
    ok "未发现明文邮箱（GitHub 匿名地址与示例域名除外）"
else
    bad "发现疑似真实邮箱："
    printf '%s\n' "$email_hits" | sed 's/^/      /'
fi

# ---------------------------------------------------------------- 3. 模块登记
section "3. 模块在分流表中登记"
# 只取 AGENTS.md 第 2、3 节（自动探测 + 分流表）里的内容
tables=$(sed -n '/^## 2\./,/^## 4\./p' AGENTS.md 2>/dev/null)
missing=""
module_count=0
for f in .agents/*.md; do
    [ -e "$f" ] || continue
    module_count=$((module_count + 1))
    base=$(basename "$f")
    printf '%s' "$tables" | grep -q "$base" || missing="$missing $base"
done
if [ -z "$missing" ]; then
    ok "所有 .agents/*.md 都已在第 2/3 节登记（共 ${module_count} 个）"
else
    bad "以下模块没有登记（不登记就永远不会被加载）：$missing"
fi

# ---------------------------------------------------------------- 4. 交叉引用
section "4. 交叉引用的文件存在"
# 已知存在于仓库之外的文件名，不参与存在性检查：
#   CodeCommitGuide.md  公司内部提交规范，不在本仓库
#   LOCAL-ONLY.md       本地私有记录，按约定永不入库
#   CLAUDE.local.md     Claude Code 的个人偏好文件，按约定不入库
#   agent.md            部分工具要求的小写入口，由使用者自行改名产生
#   docs/PROGRESS.md    任务台账，由 task-workflow.md 指导装到目标项目里
#   下面三个是「别的工具的入口文件」，只在目标项目里存在，由 docs/other-agents.md 提到
external="CodeCommitGuide.md LOCAL-ONLY.md CLAUDE.local.md agent.md docs/PROGRESS.md"
external="$external GEMINI.md AGENTS.override.md .github/copilot-instructions.md"
broken=""
for f in $docs; do
    [ -f "$f" ] || continue
    fdir=$(dirname "$f")

    # 两种写法都要认：反引号里的路径、markdown 链接的 href。
    # README 用的是 [x](docs/y.md)，只认反引号会整片漏掉。
    refs=$(grep -ohE '`[A-Za-z0-9_./-]+\.md`|\]\([A-Za-z0-9_./#-]+\.md(#[^)]*)?\)' "$f" 2>/dev/null |
        sed -E 's/^`//; s/`$//; s/^\]\(//; s/\)$//; s/#.*$//' | sort -u)

    for ref in $refs; do
        skip=0
        for e in $external; do
            [ "$ref" = "$e" ] && skip=1
        done
        [ "$skip" = "1" ] && continue

        [ -e "$ref" ] && continue
        [ -e "$fdir/$ref" ] && continue
        [ -e ".agents/$ref" ] && continue
        [ -e "docs/$ref" ] && continue
        [ -e "references/$ref" ] && continue
        [ -e "reviews/$ref" ] && continue
        [ -e "templates/$ref" ] && continue

        case "$broken" in
            *" $ref"*) ;;
            *) broken="$broken $ref" ;;
        esac
    done
done
if [ -z "$broken" ]; then
    ok "所有引用的 .md 文件都存在（反引号与 markdown 链接）"
else
    bad "引用了不存在的文件：$broken"
fi

# ---------------------------------------------------------------- 5. 代码块闭合
section "5. 代码块闭合"
unclosed=""
for f in $docs templates/githooks/* hooks/*.sh scripts/*.sh; do
    [ -f "$f" ] || continue
    n=$(grep -c '^```' "$f" 2>/dev/null || true)
    n=${n:-0}
    [ $((n % 2)) -eq 0 ] || unclosed="$unclosed $f($n)"
done
if [ -z "$unclosed" ]; then
    ok "所有文档的代码块都成对闭合"
else
    bad "代码块未闭合：$unclosed"
fi

# ---------------------------------------------------------------- 6. 数字对账
# 「14 个模块」「全局 22 个文件」这类数字散在多个文件里，改一个数最容易漏改其余几处。
# 这里用仓库实际值去核对，不靠人肉记。
section "6. 文档里的数字与实际一致"
# CHANGELOG 记的是历史事实，不参与对账
count_docs=$(printf '%s\n' $docs | grep -v '^CHANGELOG.md$')
# 全局目录装的是：AGENTS.md + 模块 + scripts/×2 + templates/githooks/×2
#                  + templates/project/×2 + templates/github/×1
# 加模板或脚本时改这个偏移，文档里的「全局 N 个文件」会跟着对上。
global_files=$((module_count + 8))

num_bad=""
mod_hits=$(grep -ohE '[0-9]+ 个模块' $count_docs 2>/dev/null | sort -u)
global_hits=$(grep -ohE '全局[^。，；：]{0,10}[0-9]+ 个文件' $count_docs 2>/dev/null | sort -u)

# 这两类命中都带空格，按行切而不是按词切，否则 "14 个模块" 会被拆成 "14" 和 "个模块"
old_ifs=$IFS
IFS='
'
for hit in $mod_hits; do
    n=${hit%% 个模块*}
    [ "$n" = "$module_count" ] || num_bad="$num_bad ${hit}(应为 ${module_count})"
done
for hit in $global_hits; do
    n=$(printf '%s' "$hit" | sed -E 's/.*[^0-9]([0-9]+) 个文件/\1/')
    [ "$n" = "$global_files" ] || num_bad="$num_bad ${hit}(应为 ${global_files})"
done
IFS=$old_ifs

# 文档必须声明这个数，否则「全局装了多少」没人说得清
[ -z "$global_hits" ] && num_bad="$num_bad 文档里没写「全局 N 个文件」（当前应为 ${global_files}）"

if [ -z "$num_bad" ]; then
    ok "模块数 ${module_count}、全局安装 ${global_files} 个文件，文档与仓库一致"
else
    bad "文档里的数字过期或缺失：$num_bad"
fi

# ---------------------------------------------------------------- 7. 插件清单
section "7. 插件清单自洽"
# 装到目标项目的 check.sh 也会跑这一项，但目标项目没有插件清单，跳过而不是判失败
if [ ! -f .claude-plugin/plugin.json ]; then
    ok "没有 .claude-plugin/plugin.json，跳过（说明这里是目标项目，不是规范仓库）"
else
    manifest_bad=""

    plugin_version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json 2>/dev/null | head -1)
    if [ -z "$plugin_version" ]; then
        manifest_bad="$manifest_bad plugin.json 读不到 version"
    elif [ -f CHANGELOG.md ]; then
        changelog_version=$(sed -n 's/^## \[\([0-9][0-9.]*\)\].*/\1/p' CHANGELOG.md | head -1)
        [ "$plugin_version" = "$changelog_version" ] ||
            manifest_bad="$manifest_bad 版本不一致：plugin.json ${plugin_version} / CHANGELOG ${changelog_version:-空}"
    fi

    # hooks.json 里用 ${CLAUDE_PLUGIN_ROOT}/x 引用的脚本必须真实存在
    if [ -f hooks/hooks.json ]; then
        hook_refs=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' hooks/hooks.json | sed 's|${CLAUDE_PLUGIN_ROOT}/||')
        for ref in $hook_refs; do
            [ -e "$ref" ] || manifest_bad="$manifest_bad hooks.json 引用了不存在的 ${ref}"
        done
    fi

    # 插件命令必须有 description，否则 /help 里是一行空白
    for c in commands/*.md; do
        [ -e "$c" ] || continue
        grep -q '^description:' "$c" || manifest_bad="$manifest_bad ${c} 缺 description"
    done

    if [ -z "$manifest_bad" ]; then
        ok "plugin.json 版本 ${plugin_version:-?}、hooks 引用与命令说明都正常"
    else
        bad "插件清单有问题：$manifest_bad"
    fi
fi

# ---------------------------------------------------------------- 汇总
printf '\n────────────────────────────\n'
if [ "$fail" -eq 0 ]; then
    printf '\033[32m通过 %d 项，全部正常。\033[0m\n' "$pass"
    exit 0
else
    printf '\033[31m通过 %d 项，%d 项失败。\033[0m\n' "$pass" "$fail"
    exit 1
fi
