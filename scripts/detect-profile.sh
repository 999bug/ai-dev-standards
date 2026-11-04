#!/usr/bin/env bash
#
# 探测项目事实，给 /ai-dev-standards:profile 当底稿。
#
# 只读，不改任何文件。输出是 key=value，一行一条；没输出的键表示「没读到」，
# 不要拿默认值补——没读到就该去问人，或者留「未定」。
#
# 用法：
#   bash detect-profile.sh [目标目录]
#
# 为什么用脚本而不是让模型自己翻：同一份事实每次探测结果一致，
# 换会话、换模型都不会变；模型只负责判断、取舍和写文案。

set -uo pipefail

target="${1:-.}"
[ -d "$target" ] || { echo "目标目录不存在: $target" >&2; exit 1; }
cd "$target" || exit 1

emit() { [ -n "${2:-}" ] && printf '%s=%s\n' "$1" "$2"; return 0; }
have() { [ -e "$1" ]; }

# 从 package.json 取字符串字段；node 优先（Node 项目必有），否则退回 grep
json_str() {  # key.path
    if command -v node >/dev/null 2>&1; then
        out=$(node -p "(()=>{try{const v=require('./package.json').$1;return typeof v==='string'?v:''}catch(e){return ''}})()" 2>/dev/null)
        [ -n "$out" ] && { printf '%s' "$out"; return 0; }
    fi
    grep -oE "\"${1##*.}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" package.json 2>/dev/null |
        head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"$/\1/'
}

printf '# 由 detect-profile.sh 生成，只是事实底稿\n'

printf '\n# 一、仓库\n'
emit dir_name "$(basename "$(pwd)")"
if git rev-parse --git-dir >/dev/null 2>&1; then
    emit is_git_repo yes
    emit git_remote "$(git remote get-url origin 2>/dev/null)"
    emit git_branch "$(git branch --show-current 2>/dev/null)"
    emit git_user_name "$(git config user.name 2>/dev/null)"
    # 不打印原始邮箱：它可能是真实公司邮箱，一旦输出就会进对话记录，
    # 而这份脚本的用途之一恰恰是避免真实邮箱进公开仓库。
    # 只报告「是不是 GitHub 匿名地址」+ 来源（仓库级 / 全局），具体值由命令单独取。
    gmail=$(git config user.email 2>/dev/null)
    case "$gmail" in
        "") ;;
        *@users.noreply.github.com) emit git_email_noreply yes ;;
        *) emit git_email_noreply no
           emit git_email_domain "${gmail#*@}" ;;
    esac
    if git config --local user.email >/dev/null 2>&1; then
        emit git_email_source local
    else
        emit git_email_source global
    fi
    emit commit_count "$(git rev-list --count HEAD 2>/dev/null)"
    emit tags "$(git tag --sort=-creatordate 2>/dev/null | head -5 | tr '\n' ' ')"

    # 提交风格看历史，不看文档——文档说一套、提交写一套是常态
    recent=$(git log -60 --format=%s 2>/dev/null)
    company_hits=$(printf '%s\n' "$recent" | grep -cE '^\[(NF|BF|IM|SC|CU|RF|Doc|OT|Tag)\]')
    conv_hits=$(printf '%s\n' "$recent" | grep -cE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?: ')
    emit commit_style_company_hits "${company_hits:-0}"
    emit commit_style_conventional_hits "${conv_hits:-0}"
    emit last_commit "$(git log -1 --format=%s 2>/dev/null)"
else
    emit is_git_repo no
fi

printf '\n# 二、名称与描述\n'
if have package.json; then
    emit node_name "$(json_str name)"
    emit node_description "$(json_str description)"
fi
if have pom.xml; then
    emit maven_artifact "$(grep -oE '<artifactId>[^<]+' pom.xml | head -1 | sed 's/<artifactId>//')"
    emit maven_description "$(grep -oE '<description>[^<]+' pom.xml | head -1 | sed 's/<description>//')"
fi
if have pyproject.toml; then
    emit python_name "$(grep -oE '^name[[:space:]]*=[[:space:]]*"[^"]*"' pyproject.toml | head -1 | sed -E 's/.*"([^"]*)"/\1/')"
    emit python_description "$(grep -oE '^description[[:space:]]*=[[:space:]]*"[^"]*"' pyproject.toml | head -1 | sed -E 's/.*"([^"]*)"/\1/')"
fi
if have README.md; then
    # 第一段非标题、非徽章、非表格的文字，通常就是一句话简介
    emit readme_first_line "$(grep -vE '^\s*(#|>|!\[|\[!\[|<|\||-|$)' README.md 2>/dev/null | head -1 | cut -c1-120)"
fi

printf '\n# 三、语言与框架\n'
if have pom.xml; then
    java_v=$(grep -oE '<java\.version>[^<]+' pom.xml | head -1 | sed 's/<java\.version>//')
    [ -z "$java_v" ] && java_v=$(grep -oE '<maven\.compiler\.(release|source)>[^<]+' pom.xml | head -1 | sed -E 's/<[^>]+>//')
    emit lang_java "$java_v"
    grep -q 'spring-boot' pom.xml 2>/dev/null && emit framework spring-boot
fi
if have build.gradle || have build.gradle.kts; then
    gradle_file=build.gradle
    have "$gradle_file" || gradle_file=build.gradle.kts
    emit lang_java "$(grep -oE 'languageVersion[^0-9]*[0-9]+' "$gradle_file" | head -1 | grep -oE '[0-9]+')"
    grep -q 'spring-boot' "$gradle_file" 2>/dev/null && emit framework spring-boot
fi
if have pyproject.toml; then
    py_v=$(grep -oE 'requires-python[[:space:]]*=[[:space:]]*"[^"]*"' pyproject.toml | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    emit lang_python "$py_v"
    grep -qE 'fastapi' pyproject.toml 2>/dev/null && emit framework fastapi
    grep -qE 'django' pyproject.toml 2>/dev/null && emit framework django
    grep -qE 'flask' pyproject.toml 2>/dev/null && emit framework flask
fi
# .python-version 更精确（3.11.9），但只在 pyproject 没给出主次版本时补
[ -n "${py_v:-}" ] || { [ -f .python-version ] && emit lang_python "$(head -1 .python-version | tr -d 'v')"; }
have go.mod && emit lang_go "$(grep -oE '^go [0-9.]+' go.mod | head -1 | sed 's/go //')"
if have package.json; then
    emit lang_vue "$(grep -oE '"vue"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    emit lang_react "$(grep -oE '"react"[[:space:]]*:[[:space:]]*"[^"]*"' package.json | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    grep -q '"next"' package.json 2>/dev/null && emit framework next
    grep -q '"vue"' package.json 2>/dev/null && emit framework vue
    grep -q '"react"' package.json 2>/dev/null && emit framework react
fi
have tsconfig.json && emit lang_typescript yes

printf '\n# 四、包管理器（可能有多个，取主语言对应的那个）\n'
pm=""
add_pm() { case " $pm " in *" $1 "*) return 0 ;; esac; pm="${pm:+$pm }$1"; }
have package-lock.json && add_pm npm
have pnpm-lock.yaml && add_pm pnpm
have yarn.lock && add_pm yarn
have bun.lockb && add_pm bun
have uv.lock && add_pm uv
have poetry.lock && add_pm poetry
have requirements.txt && add_pm pip
have pyproject.toml && add_pm pip
have mvnw && add_pm maven
have pom.xml && add_pm maven
have gradlew && add_pm gradle
have build.gradle && add_pm gradle
have build.gradle.kts && add_pm gradle
emit package_managers "$pm"

printf '\n# 五、命令（候选值，写进 profile 前必须实跑一次）\n'
build_cmd=""
test_cmd=""
dev_cmd=""
if have package.json && command -v node >/dev/null 2>&1; then
    build_cmd=$(node -p "require('./package.json').scripts?.build || ''" 2>/dev/null)
    test_cmd=$(node -p "require('./package.json').scripts?.test || ''" 2>/dev/null)
    dev_cmd=$(node -p "require('./package.json').scripts?.dev || require('./package.json').scripts?.start || ''" 2>/dev/null)
fi
if [ -z "$build_cmd" ]; then
    if have mvnw; then build_cmd="./mvnw -B package"
    elif have gradlew; then build_cmd="./gradlew build"
    elif have Makefile && grep -qE '^build:' Makefile 2>/dev/null; then build_cmd="make build"
    elif have pom.xml; then build_cmd="mvn -B package"
    fi
fi
if [ -z "$test_cmd" ]; then
    if have mvnw; then test_cmd="./mvnw -B test"
    elif have gradlew; then test_cmd="./gradlew test"
    elif have Makefile && grep -qE '^test:' Makefile 2>/dev/null; then test_cmd="make test"
    elif have pom.xml; then test_cmd="mvn -B test"
    elif have pyproject.toml && grep -qE 'pytest' pyproject.toml 2>/dev/null; then test_cmd="pytest"
    elif have tox.ini; then test_cmd="tox"
    fi
fi
if [ -z "$dev_cmd" ]; then
    if have docker-compose.yml || have compose.yaml; then dev_cmd="docker compose up"; fi
fi
emit build_command "$build_cmd"
emit test_command "$test_cmd"
emit dev_command "$dev_cmd"

printf '\n# 六、交付与发布\n'
have Dockerfile && emit has_dockerfile yes
have docker-compose.yml && emit deploy_target docker-compose
have compose.yaml && emit deploy_target docker-compose
have k8s && emit deploy_target k8s
have charts && emit deploy_target k8s
have systemd && emit deploy_target systemd
if [ -d .github/workflows ]; then
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        [ -f "$f" ] || continue
        emit workflow "$(basename "$f")"
        grep -q 'pages' "$f" 2>/dev/null && emit pages yes
        emit registry "$(grep -oE 'ghcr\.io/[A-Za-z0-9_./-]+' "$f" 2>/dev/null | head -1)"
    done
fi
have release-please-config.json && emit release_tool release-please
have .releaserc && emit release_tool semantic-release

printf '\n# 七、敏感信息\n'
if have .env.example || have .env.sample; then emit has_env_example yes; fi
if [ -d .github/workflows ]; then
    emit workflow_secrets "$(grep -rhoE 'secrets\.[A-Z_][A-Z0-9_]*' .github/workflows 2>/dev/null | sed 's/secrets\.//' | sort -u | tr '\n' ' ')"
fi
have .gitignore && emit has_gitignore yes

printf '\n# 八、目录结构\n'
for d in src app web frontend backend server api internal pkg cmd lib packages services tests test docs; do
    have "$d" && emit dir "$d"
done
for d in src/main src/test src/main/java src/main/resources; do
    have "$d" && emit dir "$d"
done
emit top_level_files "$(ls -1 2>/dev/null | grep -vE '^\.' | head -20 | tr '\n' ' ')"

printf '\n# 九、项目自有文档（related_docs 候选）\n'
for f in *.md; do
    [ -f "$f" ] || continue
    case "$f" in
        README*|AGENTS.md|CLAUDE.md|CHANGELOG*|LICENSE*|CONTRIBUTING*|CODE_OF_CONDUCT*) ;;
        *) emit doc "$f" ;;
    esac
done
have docs && emit has_docs_dir yes

printf '\n# 探测结束：没出现的键＝没读到，交给用户确认或留「未定」，不要补默认值。\n'
