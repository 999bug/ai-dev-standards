# AI 开发规范

装进项目就能生效的一套分层开发规范：`AGENTS.md` 做入口（≤150 行）按任务分流，`.agents/` 有 14 个模块（安装时按项目裁剪），可选提交门禁与 CI 自检。目标是让 AI 按你的意图改代码，而不是按它的默认习惯。

装完一个项目只多 3 个条目：`AGENTS.md`、`.agents/`、`CLAUDE.md`。钩子进 `.git/hooks/`，不占根目录。

## 安装（Claude Code 插件市场，推荐）

本仓库自己就是一个 Claude Code 插件市场。先把插件装上：

```bash
claude plugin marketplace add 999bug/ai-dev-standards
claude plugin install ai-dev-standards@ai-dev-standards --scope local
```

`--scope local` 只在本项目生效；不加默认装成 `user`，所有项目都会带上。

**装成 `user` 也不会污染仓库**——插件只多出两个命令，不往任何目录写文件。安装规范是显式动作。

装完退出会话再重进（插件在会话启动时加载），然后在目标项目里执行：

```text
/ai-dev-standards:install
```

它会先跑 `--dry-run` 把「要写哪些文件、跳过哪些」摆给你看，确认后才落盘。默认级别＝**与项目相关的规范模块** + `CLAUDE.md` + `.git/hooks/` 下的两个钩子。

模块按项目裁剪，不会把无关规范塞进来：

| 项目情况 | 装什么 |
| --- | --- |
| 纯 Java、没用 GitHub、没有 Docker | 模块 7 个 · 文件 11 个 |
| Java + GitHub Actions + Dockerfile | 模块 9 个 · 文件 13 个 |
| 前端 Vue + GitHub + Docker | 模块 9 个 · 文件 13 个 |
| Android 应用 + GitHub Releases | 模块 9 个 · 文件 13 个 |
| 要全量（旧行为） | `--all-modules`，写入 18 个文件 |

判断依据直接复用 profile 的探测脚本：`app/build.gradle.kts` + `AndroidManifest.xml` → 只装 Android 规范（同时带上签名发版那份，不再装 Java），`pom.xml`/`build.gradle` → Java，`pyproject.toml` → Python，`package.json` + `vue` → Vue，`.github/workflows/` 或 github remote → 发布规范，`Dockerfile`/`compose` → 容器规范。workflow 里真的调了 Gitee API / 用了 `GITEE_TOKEN`，或存在 gitee 远端 → 再装 `release-gitee.md`（会连带发布规范），因为仓库镜像不带 Release 附件。**`AGENTS.md` 的分流表会同步删掉未装模块的行**，不会留悬空引用。

要 CI 或自检脚本，跟它说一声加上 `--with-ci` / `--with-check`；想手工指定模块用 `--modules=commit.md,lang-java.md`。

Windows 上没有 `bash` 也不要紧：命令会自动改用 `install.ps1`，效果一样。

### 为什么不再自动安装

1.4.0 及更早的版本把安装挂在 SessionStart 上：装完插件，在任意 git 仓库开一次会话就会写入整套文件（15 个，其中两个是会改变提交行为的 git 钩子）。这有两个问题——它和这套规范自己的第一条红线（先诊断、后动手）冲突；插件装成 `user` scope 时，clone 下来只想看一眼的仓库也会被写。

现在 SessionStart 只做一件事：输出两三行上下文，告诉你这个仓库装没装、profile 还剩几处「未定」、改代码前该按分流表加载模块。不写文件、不执行命令。

### 官方插件装不上

网络装不了、市场没生效、或者想先看清会写哪些文件——走手动安装，效果完全一样：

**→ [docs/manual-install.md](docs/manual-install.md)**

里面是完整步骤：克隆、预览、正式安装、Windows 写法、只装核心、升级、常见报错、卸载后清理。

### 更新与卸载

```bash
# 升级项目里的规范（保留你的本地改动）
/ai-dev-standards:upgrade

# 升级插件本身
claude plugin update ai-dev-standards@ai-dev-standards --scope local

# 卸载（scope 要和安装时一致）
claude plugin uninstall ai-dev-standards@ai-dev-standards --scope local

# 不再需要这个市场时再移除（会一并卸载它的插件）
claude plugin marketplace remove ai-dev-standards
```

`/ai-dev-standards:upgrade` 靠 `.agents/.standards-version` 里记录的 hash 判断每个文件是否被你改过：没改过的更新成新版，改过的另存为 `<文件>.new`，原文件不动。

卸载只删插件，**已经写进项目的文件不会自动消失**。删哪些、怎么删见 [docs/manual-install.md](docs/manual-install.md#卸载与清理)。

### 想自己发布插件

插件的生成、发布、别人怎么找到、以及各种装不上的排错，单独写了一份：

**→ [docs/plugin-publishing.md](docs/plugin-publishing.md)**

## 装完之后

### 1. `.agents/project-profile.md` 已经帮你填好了

首次安装时，安装器会用 `scripts/detect-profile.sh` 探测构建/测试命令、语言版本、部署目标、提交风格、目录结构，直接写进 profile 初稿。装完只需要补三样：

- `type` / `visibility`：开源还是公司项目（只有你知道）
- `verify_*`：构建/测试命令要不要现在实跑一遍
- 探测不到的项目特有信息

想补齐就跑：

```text
/ai-dev-standards:profile
```

它只问四个必须由人决定的选择——仓库性质（开源 / 个人私有 / 公司内部）、提交信息风格、推送策略、要不要现在跑验证。

**升级不会改这个文件。** 里面是项目事实和你手写的结论，模板更新不该覆盖它；需要按新模板重整时，手动跑上面那条命令。

探测不到的会留「未定」并列成清单，不会拿示例值糊弄你。字段说明见 [`references/profile-guide.md`](references/profile-guide.md)。



### 2. 不用再背那句开场白了

以前每次开新会话都要手动说「先读 AGENTS.md 和 profile」。现在插件会在会话启动时自动输出：

```text
[ai-dev-standards] 本仓库已装这套规范（37 处「未定」待确认）。
  动手前先确认 project-profile.md，不许拿示例值当项目事实。
  改代码前按 AGENTS.md 第 3 节分流表加载模块，不要一次性全读。
```

这段来自 `hooks/session-context.sh`，只读不写。嫌吵可以用环境变量关掉：`AI_DEV_STANDARDS_QUIET=1`（profile 填满后静默）、`AI_DEV_STANDARDS_SKIP=1`（本次会话完全静默）。

没有装插件的项目，仍然靠这句话：

```text
先读 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。
```

### 3. 验证

新会话里问：

> 按你读到的规范回答：① 改 Java 代码前要先读哪个文件？② 提交信息的类型有哪些？

答案应是 `.agents/lang-java.md` 和 `NF/BF/IM/SC/CU/RF/Doc/OT/Tag`。答不出来说明 `CLAUDE.md` 首行缺 `@AGENTS.md`。

自检脚本默认不装（多数项目用不到）。想跑就装 `--with-check`，然后：

```bash
bash scripts/check.sh
```

七项全绿：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合、数字对账、插件清单。

## 要改哪些文件

| 文件 | 动不动 | 说明 |
| --- | --- | --- |
| `.agents/project-profile.md` | **每个项目必改** | 项目事实：语言版本、构建/测试命令、提交身份、部署目标、例外 |
| `AGENTS.md` | 一般不动 | 只在新增语言/平台模块时，往第 2、3 节分流表登记一行 |
| `.agents/*.md` | 按需 | 团队自己的约定写进对应模块，不要都堆到入口文件 |
| `CLAUDE.md` | 项目原来有才动 | 原有内容保留，只在第一行加 `@AGENTS.md` |
| `.agents/.standards-version` | 不动 | 安装清单，`--upgrade` 靠它判断谁改过；手改会让升级误判 |
| `scripts/check.sh` | 不动 | 只有装了 `--with-check`（或 `--with-ci`）才有；改它等于把规则检查绕过去 |
| `.github/workflows/check.yml` | 可选 | 只有 `--with-ci` 才装；改触发策略时才动 |

## 其他 agent

同一套文件，各工具入口不同，装一次全都生效：

| 工具 | 入口文件 | 额外动作 |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | 安装器已带上（内容一行 `@AGENTS.md`） |
| WorkBuddy | `AGENTS.md` | 也可作为 skill 安装，一句话触发 |
| Codex | `AGENTS.md` | 无 |
| opencode | `AGENTS.md` | 无（也兼容 `CLAUDE.md`） |
| Cursor | `AGENTS.md` | 无 |
| GitHub Copilot | `AGENTS.md` | 无 |

每个工具的安装命令、验证问题和官方文档链接：**[docs/other-agents.md](docs/other-agents.md)**

## 装进来的文件

| 文件 | 什么时候读 | 内容 |
| --- | --- | --- |
| `AGENTS.md` | 每次会话 | 优先级、工作方式、自动探测、分流表、10 条跨语言红线、完成定义 |
| `.agents/project-profile.md` | 每次会话 | 项目事实，唯一必改的文件；已有 `/init` 产物时可自动生成初稿 |
| `.agents/commit.md` | 写 commit、定分支、打 tag | 类型与单号、三段式格式、粒度禁令、分支与 Tag |
| `.agents/discipline.md` | 提交、碰凭据、收尾 | Git 红线、匿名与脱敏、自测闭环、多会话并行 |
| `.agents/integration.md` | 对接外部系统、调 SDK | HTTP 200 陷阱、签名与编码、时间戳单位、断线缓冲 |
| `.agents/legacy.md` | 接手老项目、重构巨型类 | 体检 grep、找接缝、迁移只搬不改、验收清单 |
| `.agents/task-workflow.md` | 跨多次会话、要拆子任务、接手半成品 | 何时写 spec/plan、模板、台账与交接、子代理任务书与报告 |
| `.agents/lang-*.md` | 改对应语言时 | Java（版本特性、导入与命名、并发、超时、缓存）/ Kotlin-Android（版本基线、四层验证、Room 迁移、设备观察）/ Python / Vue 的坑，通用纪律不重复 |
| `.agents/release-*.md` | 发版、改镜像、打 APK、同步国内分发 | GitHub Actions 与 Docker 的发布、回滚；Android 的签名、版本号、APK 校验与升级策略；Gitee Release 附件的镜像、校验与失败补传 |
| `CLAUDE.md` | Claude Code 会话 | 一行 `@AGENTS.md`，让只认 CLAUDE.md 的工具读到同一份规范 |
| `.agents/.standards-version` | 升级时 | 版本与每个文件的 sha256，`--upgrade` 据此保留你的改动 |
| `scripts/check.sh` | 按需（`--with-check`） | 七项自检；CI 也调用它 |
| `.git/hooks/`（装进去的） | 提交时 | `commit-msg` 校验提交信息；`post-commit` 在有 `.codegraph/` 时同步索引 |
| `templates/github/check.yml` | 目标项目的 CI | 自检 + 历史邮箱扫描 |

`install.sh` / `install.ps1` 负责把这些装到目标项目，默认不覆盖已有文件。运作原理见 [`references/how-it-works.md`](references/how-it-works.md)，扩展写法见 [`references/extending.md`](references/extending.md)，发版见 [`references/claude-code.md`](references/claude-code.md)。

## 发版产物同步到 Gitee

需要把 GitHub Release 附件镜像到 Gitee 的项目，安装器会额外带上 `.agents/release-gitee.md`，并把触发条件登记进 `AGENTS.md` 第 2、3 节。探测依据是 workflow 里真的调了 Gitee API / 用了 `GITEE_TOKEN`，或存在 gitee 远端——只凭「用了 GitHub Actions」不会多装一份用不上的规范。

完整操作手册单独一份，留在规范仓库、不装进目标项目：**[references/gitee-release-sync.md](references/gitee-release-sync.md)**。里面有可直接搬走的镜像 job 模板、参数替换表、Gitee OpenAPI 速查、Git Bash 与 PowerShell 两套人工补传脚本、验证清单、高频坑与迁移 Checklist。

手册解决的核心误区：平台的「仓库镜像」只同步分支、标签和提交，**不含 Release 附件**；附件必须由 CI 复用同一份 artifact、调 API 单独上传。

## 许可

文档部分 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，可自由复制、修改、商用，需保留署名，全文见 `LICENSE`。

脚本部分（`install.sh`、`install.ps1`、`hooks/`、`scripts/`、`templates/githooks/`）用 MIT，见 `LICENSE-MIT`——可执行代码用 CC 许可缺少免责与专利条款，不合适。

```text
ai-dev-standards by saul, licensed under CC BY 4.0 (docs) and MIT (scripts)
https://github.com/999bug/ai-dev-standards
```

last-verified: 2026-11-10
