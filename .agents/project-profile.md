# 项目档案（project-profile）

> 每个项目只改这一个文件。写 `未定` 表示还没确认——去确认，不要猜。
> 这里的事实优先于通用规范；通用规范不写项目事实。
>
> 安装时已按探测结果填过初稿。还剩「未定」的，跑 `/ai-dev-standards:profile` 补齐。
> **升级不会改这个文件**；需要按新模板重整时，手动跑同一条命令。

## 0. 遇到「未定」怎么办

**【红线】不许猜。** 没填完的 profile 比没有更危险：AI 会拿示例值当事实，一路错下去。

遇到 `未定` 就停下来问，一次问清。只有三种情况可以不等：用户已给出等价信息、该项与当前任务无关、用户说"先按默认走"。

判定标准：**猜错的代价 > 多问一句的成本时，必须问。**

## 1. 基本信息

```yaml
project: 未定
type: 未定                        # oss = GitHub 开源 | internal = 公司内部
visibility: 未定                  # public | private
description: 未定                 # 一句话：给谁解决什么问题
```

`type` 决定提交身份、敏感信息尺度、发布链路。下面各节按类型给默认值，不符就显式写出来。

## 2. 技术栈

```yaml
languages:                        # 只填实际用到的，版本写实际值，不写 "8+"
  java: 未定                      # 取 pom.xml 的 java.version / maven.compiler.release
  # kotlin: 1.9.24                # Android 项目看 gradle/libs.versions.toml
  # python: 3.11
  # vue: 3
framework: 未定                   # spring-boot 3.3 / fastapi / vue / 无
package_manager: 未定             # maven | gradle | uv | poetry | pnpm | npm
build_command: 未定               # 实际跑通过的命令
test_command: 未定
dev_command: 未定                 # 本地起服务
```

## 3. 提交与推送

```yaml
git_user_name: 未定
git_user_email: 未定              # oss 必须 noreply：<GitHub数字ID>+<用户名>@users.noreply.github.com
commit_style: 未定                # company = [NF]/[BF] 前缀+单号 | conventional = feat:/fix:
issue_tracker: 未定               # 禅道 / Bugzilla / GitHub Issues / none
auto_commit: true                 # 改完自动提交，不必每次问
push_policy: on-request           # on-request（等授权）| never | allowed
```

## 4. 交付与发布

```yaml
deploy_target: 未定               # docker | docker-compose | k8s | systemd | pages | jar | none
release_trigger: 未定             # manual（Actions 手动）| tag | push-main
version_scheme: 未定              # v1.0.<run_number> | 语义化 semver | 日期 yyyy.mm.dd
registry: 未定                    # 镜像仓库；没有就写 none
pages: no                         # 只有纯静态产物才 yes
```

## 5. 敏感信息

```yaml
secrets_location: 未定            # GitHub Repository secrets | 内网 vault | 本地 .env
never_commit:                     # 除通用规则外的项目特有项；没有写「无」
  - 未定
internal_endpoints:
  allowed_in_docs: false          # 内网地址能否写进公开文档
```

## 6. 作用域与验证

```yaml
ai_scope:                         # 只写目录路径，不写"前端代码"这种描述
  - 未定
log_language: en                  # en（默认）| zh（项目历史全中文时）
verify_build: 未定                # 与 build_command 一致
verify_test: 未定
verify_test_policy: full          # full | compile-only（用 compile-only 要在 §8 写原因）
test_port: 9099                   # 自测端口，避开默认端口
# 有冒烟/版本/UI 检查就补：verify_smoke、verify_version、verify_ui，写命令
```

`verify_*` 为空时按通用规范兜底：构建 + 测试 + 起服务实测。填了就必须跑填的那条。

## 7. 项目自有文档

```yaml
related_docs:                     # 先读这些再动手，优先级高于通用建议
  - 未定                          # 例如 DEVELOPMENT.md / DEPLOY.md；没有写「无」
```

## 8. 覆盖与例外

通用规范里不适用或需要偏离的，逐条写「规则 / 偏离 / 理由」。没有写「无」。

```yaml
overrides: []
```

## 9. 已知的雷区

只写会影响判断的那几条：字段名与含义不符、不能碰的模块、必须连真实环境才能跑的测试。

- 未定

## 10. 附：从 /init 产物抽取的原文（可选）

需要时把项目原有 `CLAUDE.md` / `AGENTS.md` 的正文按标题降一级追加到这里。
先消化进 §1–§9，再归档；不需要就删掉本节。
