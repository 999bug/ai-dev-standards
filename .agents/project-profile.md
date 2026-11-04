# 项目档案（project-profile）

> 每个项目只改这一个文件。写 `未定` 表示还没确认——那就去确认，不要猜。
> 这里的事实优先于通用规范；通用规范不写项目事实。
>
> 三种填法，优先第一种：
>
> 1. **让 AI 一键生成**：脚本探测构建命令、语言版本、部署目标、提交风格，再问你 2–4 个
>    只有人才能决定的选择（项目性质、提交风格、推送策略），然后写完整份。
>    Claude Code 里是 `/ai-dev-standards:profile`；其他工具让 AI 按填写指南的「一键生成」执行。
> 2. 已有 `CLAUDE.md` / `AGENTS.md`（`/init` 产物）时，按填写指南的「自动生成」映射表出初稿。
> 3. 逐项手填。

## 0. 遇到「未定」怎么办

**【红线】不许猜。** 一份没填完的 profile 比没有 profile 更危险：AI 会拿你写的示例值当事实，用「看起来合理」的默认值代替你的实际情况，然后一路错下去。

遇到 `未定` 时，停下来问，一次问清：

> 「profile 里还有 3 项未定：`build_command`、`deploy_target`、`push_policy`。它们会影响我接下来的判断，请逐项确认；或者告诉我先按什么值走。」

只有三种情况可以不等：

1. 用户在本次指令里已经给出了等价信息；
2. 该项与当前任务无关（改前端样式不需要知道 `registry`）；
3. 用户明确说"先按默认走"。

**判定标准**：猜错的代价 > 多问一句的成本时，必须问。改错一次构建脚本、发错一次版本，都比问一句贵。

自动生成初稿时本条同样生效：`/init` 产物里没有的字段照写「未定」，不从原文的示例值、注释、过期内容里猜。

## 1. 基本信息

```yaml
project: 未定                    # 项目名
type: oss                        # oss = GitHub 开源项目；internal = 公司内部项目
visibility: public               # public | private
description: 未定                 # 一句话：给谁解决什么问题
```

`type` 决定三件事：提交身份、敏感信息处理尺度、发布链路。下面各节按类型给默认值，不符就显式写出来。

## 2. 技术栈

```yaml
languages:                       # 只填实际用到的
  java: 17                       # 取 pom.xml 的 java.version，不写"8+"
  # python: 3.11
  # vue: 3
framework: 未定                   # spring-boot 3.3 / fastapi / 无
package_manager: 未定             # maven | gradle | uv | poetry | pnpm | npm
build_command: 未定               # 实际能跑通的命令，例如 ./build.sh
test_command: 未定                # 例如 mvn -B test
dev_command: 未定                 # 本地起服务，例如 java -jar target/x.jar --server.port=9099
```

## 3. 提交身份与策略（按 type 二选一）

```yaml
# oss：匿名
git_user_name: 未定
git_user_email: 未定              # <GitHub数字ID>+<用户名>@users.noreply.github.com
enable_private_email: true        # GitHub → Settings → Emails 两个开关都要开

# internal：公司全局身份
# git_user_name: 未定
# git_user_email: 未定
```

```yaml
commit_style: company             # company = [NF]/[BF]/[IM] 前缀 + 单号（见 commit.md）
                                  # conventional = feat: / fix: / docs:
issue_tracker: 未定               # 禅道 / Bugzilla / GitHub Issues / none
auto_commit: true                 # 改完自动提交，不必每次询问
push_policy: on-request           # on-request（默认，等授权）| never | allowed
```

## 4. 交付与发布

```yaml
deploy_target: 未定               # docker-compose | k8s | systemd | pages | jar | none
release_trigger: 未定             # manual（Actions 手动）| tag（打 v*）| push-main
version_scheme: 未定              # v1.0.<run_number> | 语义化 semver | 日期 yyyy.mm.dd
registry: 未定                    # ghcr.io/<owner>/<image>；internal 填内网 registry
domestic_mirror: 未定             # oss 默认阿里云 ACR；internal 默认 None
pages: no                         # 只有纯静态产物才 yes
release_assets: 未定              # jar / 镜像 tar.gz / 静态包
retention: 未定                   # Release 保留数量，例如 20
```

## 5. 敏感信息

```yaml
secrets_location: 未定            # GitHub Repository secrets | 内网 vault | 本地 .env
never_commit:                     # 除通用规则外的项目特有项
  - 未定
internal_endpoints:               # 内网地址能否写进公开文档
  allowed_in_docs: false
```

## 6. 作用域与验证（写命令，不写描述）

```yaml
ai_scope:                         # AI 只看 / 只改哪些目录，其余一律不动
  - 未定                          # 例如：src/main/java、web/src；排除 python/、native_wrapper/
log_language: en                  # en = 日志与异常消息用英文（默认）；zh = 项目历史全中文，保持一致
verify_build: 未定                # ./build.sh
verify_test: 未定                 # mvn -B test
verify_test_policy: full          # full = 提交前跑测试（默认）；compile-only = 只要求编译通过
verify_smoke: 未定                # python tools/api-smoke.py
verify_version: 未定              # curl -s localhost:8088/api/meta/version
verify_ui: 未定                   # 截图/取数脚本，或 Playwright 命令
test_port: 9099                   # 自测端口，避开默认端口
```

`verify_*` 为空时按通用规范兜底：构建 + 测试 + 起服务实测。填了就必须跑填的那条。
`verify_test_policy: compile-only` 只允许在项目明确这样约定时使用（例如测试依赖外部环境跑不起来），且要在 §8 的 overrides 里写明原因。

## 7. 项目自有文档

```yaml
related_docs:                     # 先读这些，再动手；它们的优先级高于通用建议
  - 未定                          # 例如 DEVELOPMENT.md（流程）/ DEPLOY.md（部署）
```

## 8. 覆盖与例外

通用规范里不适用或需要偏离的，逐条写清。没有就写"无"。

```yaml
overrides:
  - rule: 未定                    # 例如：容器内以 root 运行
    deviation: 未定               # 例如：允许，基础镜像未提供非 root 用户
    reason: 未定
```

## 9. 已知的技术债 / 雷区

写下来，避免每次都重新踩。只写"会影响判断"的那几条。

- 未定

## 10. 项目详细档案（可选，从 /init 产物抽取）

> 项目里已有 CLAUDE.md / AGENTS.md（`/init` 产物）时，把原文抽取到这一节，作为 §1–§9 的判断依据。
> 没有产物、或原文很短已全部消化进 §1–§9 时，整节省略，不要留空壳。

抽取规则：

1. **标题降一级**：原文 `##` 变 `###`，顺序不变，原样搬运，不改写内容。
2. **先消化再归档**：能填进 §1–§9 的事实（构建命令、提交规范、部署目标、雷区）先填；两处不一致时，以 §1–§9 的结论为准。
3. **不丢工具指令**：原文里的工具配置块（如 `<!-- CODEGRAPH_START -->` 标记的 CodeGraph 段）原样保留。
