#!/usr/bin/env bash
#
# 本仓库的自检脚本：规范文件自己检查自己。
#
# 检查项（每一项都对应一次真实踩过的坑）：
#   1. 入口行数        AGENTS.md 超过 150 行就该拆模块了
#   2. 真实邮箱        公开仓库的明文邮箱一旦推上去就洗不掉
#   3. 模块登记        新增 .agents/*.md 却忘了在分流表登记 → 永远不会被加载
#   4. 交叉引用        文档里引用的 .md 文件必须真实存在
#   5. 代码块闭合      结尾漏一个 ``` 会让后面所有内容渲染成代码
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

# 所有需要检查的文档
docs=$(ls AGENTS.md README.md CLAUDE.md SKILL.md .agents/*.md reviews/*.md references/*.md skills/*/SKILL.md 2>/dev/null)

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
for f in .agents/*.md; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    printf '%s' "$tables" | grep -q "$base" || missing="$missing $base"
done
if [ -z "$missing" ]; then
    ok "所有 .agents/*.md 都已在第 2/3 节登记"
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
external="CodeCommitGuide.md LOCAL-ONLY.md CLAUDE.local.md agent.md"
broken=""
refs=$(grep -ohE '`[A-Za-z0-9_./-]+\.md`' $docs 2>/dev/null | tr -d '`' | sort -u)
for ref in $refs; do
    skip=0
    for e in $external; do
        [ "$ref" = "$e" ] && skip=1
    done
    [ "$skip" = "1" ] && continue
    if [ ! -e "$ref" ] && [ ! -e ".agents/$ref" ] && [ ! -e "reviews/$ref" ] &&
        [ ! -e "references/$ref" ] && [ ! -e "templates/$ref" ]; then
        broken="$broken $ref"
    fi
done
if [ -z "$broken" ]; then
    ok "所有引用的 .md 文件都存在"
else
    bad "引用了不存在的文件：$broken"
fi

# ---------------------------------------------------------------- 5. 代码块闭合
section "5. 代码块闭合"
unclosed=""
for f in $docs templates/githooks/* scripts/*.sh; do
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

# ---------------------------------------------------------------- 汇总
printf '\n────────────────────────────\n'
if [ "$fail" -eq 0 ]; then
    printf '\033[32m通过 %d 项，全部正常。\033[0m\n' "$pass"
    exit 0
else
    printf '\033[31m通过 %d 项，%d 项失败。\033[0m\n' "$pass" "$fail"
    exit 1
fi
