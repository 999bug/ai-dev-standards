# AI 开发规范

一套分层开发规范：**全局装一次，每个项目只初始化一次**。

规范本体（`AGENTS.md` + 14 个模块 + 钩子模板 + 自检脚本）放在全局目录共用；项目里只留三个文件——一个二十行的指针 `AGENTS.md`、一行 `CLAUDE.md`、以及唯一需要按项目改的 `.agents/project-profile.md`。

目标是让 AI 按你的意图改代码，而不是按它的默认习惯。

## 它放在哪

| 位置 | 内容 | 谁来改 | 升级 |
| --- | --- | --- | --- |
| `~/.ai-dev-standards/`（可用 `AI_DEV_STANDARDS_HOME` 改） | `AGENTS.md`、`.agents/` 14 个模块、`scripts/`、`templates/` | 不要手改 | 全局升一次 |
| `<项目>/AGENTS.md` | 指向全局的指针，约 20 行 | 内容固定 | 不用管 |
| `<项目>/CLAUDE.md` | 一行 `@AGENTS.md` | 内容固定 | 不用管 |
| `<项目>/.agents/project-profile.md` | 项目事实：语言版本、构建命令、提交身份、例外 | **每个项目必改** | 永不覆盖 |
| `<项目>/.git/hooks/` | `commit-msg`、`post-commit` | 不用管 | 初始化时装一次 |

全局目录一次装 22 个文件；项目侧只多 3 个文件，钩子不占根目录条目。

这么分的原因很简单：14 个模块和具体项目无关，复制 N 份只会让升级变成 N 次。真正属于项目的只有 profile。

## 安装：全局一次

### Claude Code 插件市场（推荐）

本仓库自己就是一个 Claude Code 插件市场。先把插件装上：

```bash
claude plugin marketplace add 999bug/ai-dev-standards
claude plugin install ai-dev-standards@ai-dev-standards --scope user
```

`--scope user` 让所有项目都能用这两个命令。插件本身不写任何文件——安装规范是显式动作。

装完退出会话再重进（插件在会话启动时加载），然后在任意项目里执行：

```text
/ai-dev-standards:install
```

它会先检查全局目录：没装就装，落后就更新，已是最新就跳过；然后初始化当前项目。两步都先 `--dry-run` 把要写的文件摆给你看，确认后才落盘。

第一次装全局会往家目录写 22 个文件，之后每次都是幂等的（全最新时输出「写入 0 个文件」）。

Windows 上没有 `bash` 也不要紧：命令会自动改用 `install.ps1`，行为一致。

### 手动安装

不想用插件、或者插件装不上：

```bash
git clone https://github.com/999bug/ai-dev-standards.git

# 1. 全局装一次（默认 ~/.ai-dev-standards）
./ai-dev-standards/install.sh --global

# 2. 每个项目初始化一次
cd /path/to/your-project
/full/path/to/ai-dev-standards/install.sh
```

也可以直接把仓库 clone 到全局位置，省掉复制这一步，以后升级就是 `git pull`：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.ai-dev-standards
cd /path/to/your-project
~/.ai-dev-standards/install.sh
```

完整步骤、Windows 写法、常见报错：**[docs/manual-install.md](docs/manual-install.md)**

### 为什么不再自动安装

1.4.0 及更早的版本把安装挂在 SessionStart 上：装完插件，在任意 git 仓库开一次会话就会写入整套文件。两个问题——它和这套规范自己的第一条红线（先诊断、后动手）冲突；插件装成 `user` scope 时，clone 下来只想看一眼的仓库也会被写。

现在 SessionStart 只输出两三行上下文，告诉你这个仓库接入了没有、profile 还剩几处「未定」、改代码前该按分流表加载模块。不写文件、不执行命令。

## 装完之后

### 1. project-profile 已经填了初稿

首次初始化时，安装器会用 `scripts/detect-profile.sh` 探测构建/测试命令、语言版本、部署目标、提交风格、目录结构，直接写进 profile 初稿。装完只需要补三样：

- `type` / `visibility`：开源还是公司项目（只有你知道）
- `verify_*`：构建/测试命令要不要现在实跑一遍
- 探测不到的项目特有信息

想补齐就跑：

```text
/ai-dev-standards:profile
```

它只问四个必须由人决定的选择——仓库性质（开源 / 个人私有 / 公司内部）、提交信息风格、推送策略、要不要现在跑验证。

探测不到的会留「未定」并列成清单，不会拿示例值糊弄你。字段说明见 [`references/profile-guide.md`](references/profile-guide.md)。

### 2. 不用再背那句开场白了

以前每次开新会话都要手动说「先读 AGENTS.md 和 profile」。现在插件会在会话启动时自动输出：

```text
[ai-dev-standards] 本仓库已接入（规范在 ~/.ai-dev-standards，37 处「未定」待确认）。
  一键填充：/ai-dev-standards:profile（探测项目事实，只问几个必须人决定的选择）
  改代码前先读 ~/.ai-dev-standards/AGENTS.md，再按第 3 节分流表加载模块，不要一次性全读。
```

这段来自 `hooks/session-context.sh`，只读不写。嫌吵可以用环境变量关掉：`AI_DEV_STANDARDS_QUIET=1`（profile 填满后静默）、`AI_DEV_STANDARDS_SKIP=1`（本次会话完全静默）。

没装插件的项目，仍然靠这句话：

```text
先读全局的 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。
```

### 3. 验证

新会话里问：

> 按你读到的规范回答：① 改 Java 代码前要先读哪个文件？② 提交信息的类型有哪些？

答案应是 `lang-java.md` 和 `NF/BF/IM/SC/CU/RF/Doc/OT/Tag`。答不出来就查两件事：

```bash
# 全局目录是否可读
cat "${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}/AGENTS.md" | head -3

# 项目里的指针和 profile 在不在
ls AGENTS.md CLAUDE.md .agents/project-profile.md
```

## 要改哪些文件

| 文件 | 动不动 | 说明 |
| --- | --- | --- |
| `.agents/project-profile.md` | **每个项目必改** | 项目事实：语言版本、构建/测试命令、提交身份、部署目标、例外 |
| `<全局>/AGENTS.md` | 不动 | 入口与分流表；要加规则先加到模块里 |
| `<全局>/.agents/*.md` | 不动 | 团队自己的约定写进 profile 的 `overrides`，不要改全局模块 |
| 项目 `AGENTS.md` | 不动 | 指针，内容固定；升级安装器会自己更新 |
| 项目 `CLAUDE.md` | 项目原来有才动 | 原有内容保留，只在第一行加 `@AGENTS.md` |
| `<全局>/.standards-version` | 不动 | 安装清单，`--upgrade` 靠它判断谁改过 |

## 升级

```bash
/ai-dev-standards:upgrade
```

只升全局目录。项目侧不需要升级——那里只有指针和 profile，内容固定。

`--upgrade` 靠全局目录 `.standards-version` 里记录的 sha256 判断：装完之后没被改过的直接覆盖；你改过的先备份到 `.backup/<时间戳>/` 再覆盖，汇总里会列出来。

**不要改全局模块来做定制。** 真要偏离通用规则，写进项目 profile 第 8 节 `overrides`，全局保持原样，下次升级就不会冲突。

## 从 1.12.x 及更早升级

老版本把模块复制进了项目。新结构下这些副本要清掉，否则 AI 会同时读到两份规范。

在旧项目里跑一次安装器，它**只打印清理清单和命令，不删任何文件**：

```bash
~/.ai-dev-standards/install.sh /path/to/old-project
```

确认清单无误后按提示执行，再跑一次安装。`project-profile.md` 不在清理范围，项目事实不会丢。

## 其他 agent

同一份规范，各工具入口不同，项目里那两个文件就够：

| 工具 | 入口文件 | 额外动作 |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | 初始化时已带上（一行 `@AGENTS.md`） |
| WorkBuddy | `AGENTS.md` | 也可作为 skill 安装，一句话触发 |
| Codex | `AGENTS.md` | 无 |
| opencode | `AGENTS.md` | 无（也兼容 `CLAUDE.md`） |
| Cursor | `AGENTS.md` | 无 |
| GitHub Copilot | `AGENTS.md` | 无 |

每个工具的验证问题和官方文档链接：**[docs/other-agents.md](docs/other-agents.md)**

需要留意：指针要求模型去读工作区外的文件。Claude Code 首次读全局目录可能弹一次权限确认；个别工具如果限制工作区外读取，规范就只剩指针里那几行——这种情况把需要的模块复制进项目 `.agents/` 即可。

## 全局目录里有什么

| 文件 | 什么时候读 | 内容 |
| --- | --- | --- |
| `AGENTS.md` | 每次会话 | 优先级、工作方式、自动探测、分流表、10 条跨语言红线、完成定义 |
| `.agents/project-profile.md` | 初始化时复制进项目 | 模板；真正生效的是项目里那份 |
| `.agents/commit.md` | 写 commit、定分支、打 tag | 类型与单号、三段式格式、粒度禁令、分支与 Tag |
| `.agents/discipline.md` | 提交、碰凭据、收尾 | Git 红线、匿名与脱敏、自测闭环、多会话并行 |
| `.agents/integration.md` | 对接外部系统、调 SDK | HTTP 200 陷阱、响应类型与「不存在」形态、验证口径、签名与编码、时间戳单位、断线缓冲 |
| `.agents/legacy.md` | 接手老项目、重构巨型类 | 体检 grep、找接缝、迁移只搬不改、验收清单 |
| `.agents/task-workflow.md` | 跨多次会话、要拆子任务、接手半成品 | 何时写 spec/plan、模板、台账与交接、子代理任务书与报告 |
| `.agents/lang-*.md` | 改对应语言时 | Java / Kotlin-Android / Python / Vue 的坑，以及各自版本基线 |
| `.agents/release-*.md` | 发版、改镜像、打 APK、同步国内分发 | GitHub Actions 与 Docker 的发布回滚；Android 签名与 APK 校验；Gitee 附件镜像 |
| `scripts/check.sh` | 改规范仓库时 | 七项自检；CI 也调用它 |
| `scripts/detect-profile.sh` | 初始化项目时 | 只读探测，给 profile 填初稿 |
| `templates/githooks/` | 初始化项目时 | 复制进 `.git/hooks/` 的两个钩子 |
| `templates/project/` | 初始化项目时 | 项目侧的指针模板 |
| `.standards-version` | 升级时 | 版本与每个文件的 sha256 |

运作原理见 [`references/how-it-works.md`](references/how-it-works.md)，扩展写法见 [`references/extending.md`](references/extending.md)，发版见 [`references/claude-code.md`](references/claude-code.md)。

## 团队协作

**规范跟着机器走，不跟着仓库走。** 同事 clone 你的项目只会拿到二十行指针，没装全局目录就读不到内容。

三种处理，按场景选：

1. **让对方也装一次**（推荐）。一人一次，之后他自己的所有项目都受益。
2. **在项目 README 里写明**「开工前先装 AI 开发规范」，附上仓库地址。
3. **需要规范随仓库分发**时，把用到的模块从 `~/.ai-dev-standards/.agents/` 复制进项目 `.agents/`，再把项目 `AGENTS.md` 改成读取本地副本。这是手动操作，安装器不提供，升级也要自己负责。

## 发版产物同步到 Gitee

需要把 GitHub Release 附件镜像到 Gitee 的项目，`release-gitee.md` 模块里有规则和可执行骨架。完整操作手册留在规范仓库、不复制进项目：**[references/gitee-release-sync.md](references/gitee-release-sync.md)**。

里面有两个核心误区值得先看：平台的「仓库镜像」只同步分支、标签和提交，**不含 Release 附件**；以及「Release 建好就算发完了」——附件还在传的窗口期里最新版已经可见，所以**清单最后写，清单才是发布完成的判据**。

## 许可

文档部分 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，可自由复制、修改、商用，需保留署名，全文见 `LICENSE`。

脚本部分（`install.sh`、`install.ps1`、`hooks/`、`scripts/`、`templates/githooks/`）用 MIT，见 `LICENSE-MIT`——可执行代码用 CC 许可缺少免责与专利条款，不合适。

```text
ai-dev-standards by saul, licensed under CC BY 4.0 (docs) and MIT (scripts)
https://github.com/999bug/ai-dev-standards
```

last-verified: 2026-11-12
