#!/usr/bin/env bash
#
# 发版助手：改版本号、补 CHANGELOG 骨架、跑自检、告诉你下一步该敲什么。
#
# 用法：
#   bash scripts/release.sh 1.6.0
#
# 它只改文件，不做任何 git 操作（不 commit、不 tag、不 push）。
# 为什么：打 tag 和推送属于对外动作，必须由人确认。脚本只把准备工作做完，
# 并在最后把命令打出来。
#
# 版本号只有一个来源：.claude-plugin/plugin.json。
# CHANGELOG.md 的第一条 ## [x.y.z] 必须和它一致，scripts/check.sh 第 7 项会校验。

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

new="${1:-}"
if [ -z "$new" ]; then
    echo '用法：bash scripts/release.sh <版本号>    例：bash scripts/release.sh 1.6.0' >&2
    exit 2
fi

if ! printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "版本号必须是 x.y.z：$new" >&2
    exit 2
fi

current=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .claude-plugin/plugin.json | head -1)
if [ "$current" = "$new" ]; then
    echo "plugin.json 已经是 $new，没有要改的。" >&2
    exit 1
fi

if grep -q "^## \[$new\]" CHANGELOG.md 2>/dev/null; then
    echo "CHANGELOG.md 里已经有 $new 的条目，先确认是不是改错了版本号。" >&2
    exit 1
fi

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo '工作区有未提交的改动。发版前先处理干净，否则这个提交会混进别的东西。' >&2
    git status --short >&2
    exit 1
fi

today=$(date +%Y-%m-%d)

# sed -i 在 GNU 和 BSD 上行为不同（后者要 -i ''），统一走临时文件
tmp=$(mktemp) || exit 1
sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1$new\2/" .claude-plugin/plugin.json > "$tmp" &&
    cat "$tmp" > .claude-plugin/plugin.json
rm -f "$tmp"

# 新条目插在第一个 ## [ 之前，保持最新的在最上面
tmp=$(mktemp) || exit 1
awk -v ver="$new" -v day="$today" '
    done { print; next }
    /^## \[/ {
        printf "## [%s] - %s\n\n### 新增\n\n- \n\n### 修复\n\n- \n\n", ver, day
        done = 1
    }
    { print }
' CHANGELOG.md > "$tmp" && cat "$tmp" > CHANGELOG.md
rm -f "$tmp"

printf 'plugin.json: %s -> %s\n' "$current" "$new"
echo 'CHANGELOG.md 已插入新条目，去把两条 `- ` 填成实际改动。'
echo ''

# 自检会校验「plugin.json 版本 == CHANGELOG 首条」，填错版本号在这一步就红
if bash scripts/check.sh; then
    echo ''
    echo '下一步：'
    echo "  1. 填写 CHANGELOG.md 里的 $new 条目"
    echo '  2. git add .claude-plugin/plugin.json CHANGELOG.md'
    echo "  3. git commit -m \"[IM]: 版本升到 $new\""
    echo '  4. claude plugin tag          # 官方命令，校验清单后打 ai-dev-standards--v'$new
    echo '  5. git push --follow-tags     # 推送由你决定，脚本不做'
else
    echo ''
    echo '自检没通过，先修完再发版。' >&2
    exit 1
fi
