---
description: 一键生成 .agents/project-profile.md：自动探测项目事实，只问必须由人决定的选择
argument-hint: "[目标项目目录，默认当前目录]"
---

# 一键生成 project-profile

目标项目：`$ARGUMENTS`
没给参数就用当前工作目录。

> 路径解析：`${CLAUDE_PLUGIN_ROOT}` 由插件注入。为空时先
> `ls ~/.claude/plugins/cache/ai-dev-standards/` 找版本目录，用绝对路径代替。

这份文件是整套规范唯一需要按项目改的东西。原则：**能读到的绝不问人，只有「人才能决定的事」才弹框**。

## 0. 先判断要不要写

```bash
ls "<目标>/.agents/project-profile.md" 2>/dev/null
```

| 情况 | 动作 |
| --- | --- |
| 文件不存在 | 从插件的 `.agents/project-profile.md` 复制模板，然后走下面的流程 |
| 存在，且还能 grep 到 `: 未定` | **保留已确认的值**，只填剩下的，不要整份重写 |
| 存在，且没有 `未定` | **停下**，告诉用户「profile 已填好，重跑会覆盖」。除非他明确说要重新生成 |

## 1. 探测事实（不要猜）

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-profile.sh" "<目标>"
```

输出是 `key=value`。**没出现的键就是没读到**，不要用默认值补。

Windows 没有 `bash` 时，按同一份清单自己读（读到就记，读不到就跳过）：

- `package.json` 的 `name` / `description` / `scripts` / `dependencies`
- `pom.xml` 的 `artifactId` / `java.version` / `maven.compiler.release`
- `pyproject.toml` 的 `name` / `requires-python`、`.python-version`
- `go.mod` 的 `go` 行、`tsconfig.json`、锁文件
- `Dockerfile`、`docker-compose.yml`、`.github/workflows/*.yml`
- `git remote get-url origin`、`git tag`、`git log -60 --format=%s`

脚本对邮箱做了脱敏：只给 `git_email_noreply=yes|no` 和域名，不打原始地址。**不要为了填 profile 去打印真实邮箱**。

## 2. 补读脚本覆盖不到的

| 要填的字段 | 去哪看 |
| --- | --- |
| `description` | README 第一段（探测已给 `readme_first_line`），缩成一句话 |
| `ai_scope` | 源码目录：`src/`、`app/`、`web/`、`internal/`…，排除 `docs/`、`tests/`、生成物 |
| `related_docs` | 根目录除 README/AGENTS/CLAUDE/CHANGELOG/LICENSE 之外的 `.md` |
| `§9 雷区` | README 的「注意事项」「Known issues」、`CLAUDE.md` / `AGENTS.md` 里的告警 |
| `§10 详细档案` | 已有 `CLAUDE.md` / `AGENTS.md` 时按标题降一级搬进去，不要改写 |

## 3. 只问四件事

用 AskUserQuestion **一次问完**，不要逐条追问。每个问题把探测结果放进选项描述里，让用户一眼能选。

| 问题 | 选项 | 决定什么 |
| --- | --- | --- |
| 这个仓库的性质？ | GitHub 开源项目 / 个人私有仓库 / 公司内部项目 | `type`、`visibility`、邮箱策略、发布链路 |
| 提交信息用哪套？ | `[NF]/[BF]` 前缀（带单号）/ Conventional Commits / 沿用仓库现状 | `commit_style` |
| 推送策略？ | 只提交、推送我自己来 / 允许自动推送 / 从不推送 | `push_policy` |
| 验证命令现在跑一遍吗？ | 跑（推荐）/ 先不跑，标成未验证 | `verify_*` 是否可信 |

推荐项放在第一个，并在描述里写清探测到的证据（例如「最近 60 条提交里 58 条是 `[NF]` 风格」）。

**不要问**：语言版本、构建命令、部署目标、registry、目录结构——这些要么能读到，要么读了也比你问得准。

## 4. 写文件

以模板为骨架，保留 §0–§10 的结构和注释，把值换掉。顶部加一行来源说明：

```markdown
> 生成方式：detect-profile.sh 探测 + 用户确认（2026-11-04）。仍标「未定」的项见 §9。
```

字段映射：

| 字段 | 取值 |
| --- | --- |
| `project` | 目录名，或 `node_name` / `maven_artifact` / `python_name` |
| `type` / `visibility` | Q1：开源=`oss`+`public`，个人私有=`oss`+`private`，公司=`internal`+`private` |
| `description` | 一句话，不超过 40 字；读不到就留「未定」 |
| `languages.*` | 探测到的 `lang_*`，只写实际用到的 |
| `framework` / `package_manager` | 探测值；`package_managers` 有多个时取主语言对应的，另一个写进 §9 |
| `build_command` / `test_command` / `dev_command` | 探测值。**Q4 选择跑过之后才写**；跑不通就写「未定」并把报错记进 §9 |
| `git_user_name` | `oss`：用户的 GitHub 用户名（Q1 里确认）；`internal`：探测到的 `git_user_name` |
| `git_user_email` | `oss`：`<GitHub数字ID>+<用户名>@users.noreply.github.com`，不知道 ID 就问一次；`internal`：用仓库配置的真实值 |
| `commit_style` | Q2 |
| `issue_tracker` | 有 GitHub remote → `GitHub Issues`；公司项目 → 问不出来的写「未定」 |
| `auto_commit` | `true`（本套规范的默认行为） |
| `push_policy` | Q3 |
| `deploy_target` | 探测值；都没有写 `none`，不要编 |
| `release_trigger` | 读 workflow 的 `on:`；没有 CI 写 `manual` |
| `version_scheme` | 看 `tags` 形态：`v1.2.3` → 语义化；`v1.0.<数字>` → run_number；纯日期 → `yyyy.mm.dd`；没有 tag 写 `语义化 semver` |
| `registry` | 探测值；没有写 `none` |
| `domestic_mirror` | `oss` 且 registry 是 `ghcr.io` → 阿里云 ACR；`internal` → `None` |
| `pages` | 探测到 `pages=yes` 才写 yes |
| `release_assets` | 有 Dockerfile → `镜像 tar.gz`；Maven 无 Docker → `jar`；纯静态 → `静态包` |
| `retention` | `20`（除非仓库已有约定） |
| `secrets_location` | `workflow_secrets` 非空 → `GitHub Repository secrets`；有 `.env.example` → 补 `本地 .env`；公司项目读不到 → 「未定」 |
| `never_commit` | 从 `.gitignore` 挑 1–3 条项目特有的，通用项不要抄 |
| `internal_endpoints.allowed_in_docs` | `internal` → `false`；`oss` → `false` |
| `ai_scope` | 主源码目录列表 |
| `log_language` | 默认 `en`；只有仓库历史日志全中文才写 `zh`，并说明原因 |
| `verify_build` / `verify_test` | 与 `build_command` / `test_command` 一致 |
| `verify_smoke` / `verify_version` / `verify_ui` | 探测不到就删掉这一行（不要留「未定」占位） |
| `test_port` | `9099` |
| `related_docs` | 探测到的 `doc` 列表；没有就写 `无` |
| `overrides` | 没有就写 `无` |

**硬规则：**

1. 读不到、又没人确认的字段，写 `未定`，并在 §9 列出来。**不许用"看起来合理"的值填**——填错的代价比留空大得多。
2. 不把任何 token、真实邮箱、内网地址写进 profile。
3. `oss` 项目的 `git_user_email` 只能是 noreply 地址；`internal` 项目才允许公司邮箱。
4. 已有 profile 里用户手写的值**一律保留**，即使你认为它不对——在汇报里指出来，让人改。

## 5. 验证命令

Q4 选了「跑」的话，在目标项目里依次执行，每条给 120 秒超时：

```bash
cd "<目标>" && <build_command>
cd "<目标>" && <test_command>
```

- 通过：`verify_*` 写这条命令
- 失败：命令**不写进** profile，把失败原因记进 §9，并在汇报里说明「未验证」
- 项目没有测试：`verify_test` 删掉，`verify_test_policy` 保持 `full`，在 §9 写明「无测试」

## 6. 汇报

最后给三段，不要贴整份 profile：

1. **填了什么**：多少项来自探测、多少项来自你的选择。
2. **还差什么**：`未定` 的字段逐条列出（通常 0–3 项），问用户要不要现在确认。
3. **验证结果**：构建/测试跑了没有、通没通；没跑就直说。

顺带提醒一句：`/ai-dev-standards:profile` 可以重复跑，已确认的值不会被覆盖。
