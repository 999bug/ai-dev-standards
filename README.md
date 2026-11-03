# AI 开发规范

装进项目就能生效的一套分层开发规范：`AGENTS.md` 做入口（≤150 行）按任务分流，`.agents/` 放 10 个模块，可选提交门禁与 CI 自检。目标是让 AI 按你的意图改代码，而不是按它的默认习惯。

装完一个项目只多 4 个条目：`AGENTS.md`、`.agents/`、`CLAUDE.md`、`scripts/`。

## 安装（Claude Code 插件市场，推荐）

本仓库自己就是一个 Claude Code 插件市场，两条命令装完：

```bash
cd /path/to/your-project

claude plugin marketplace add 999bug/ai-dev-standards
claude plugin install ai-dev-standards@ai-dev-standards --scope local
```

`--scope local` 只在本项目生效；不加默认装成 `user`，所有项目都会带上。

装完 **退出会话再重进**。插件在会话启动时检查当前目录：是 git 仓库、且还没有 `AGENTS.md`，就自动写入规范，屏幕上会看到：

```text
[ai-dev-standards] 本项目还没有 AI 开发规范，已自动安装。
  写入 15 个文件，跳过 0 个已存在的文件
```

自动安装走**默认级别**：规范文件 + git 钩子。钩子进 `.git/hooks/`，不占项目根目录条目。不写 CI——往 `.github/` 里加文件应该由你主动决定，需要时重跑安装器加 `--with-ci`。

### 官方插件装不上

网络装不了、市场没生效、或者想先看清会写哪些文件——走手动安装，效果完全一样：

**→ [docs/manual-install.md](docs/manual-install.md)**

里面是完整步骤：克隆、预览、正式安装、Windows 写法、只装核心、常见报错、卸载后清理。

### 更新与卸载

```bash
# 更新
claude plugin update ai-dev-standards@ai-dev-standards --scope local

# 卸载（scope 要和安装时一致）
claude plugin uninstall ai-dev-standards@ai-dev-standards --scope local

# 不再需要这个市场时再移除（会一并卸载它的插件）
claude plugin marketplace remove ai-dev-standards
```

卸载只删插件，**已经写进项目的文件不会自动消失**。删哪些、怎么删见 [docs/manual-install.md](docs/manual-install.md#卸载与清理)。

## 装完之后

### 1. 必改：`.agents/project-profile.md`

里面全是「未定」，逐项确认。这是整套体系能否生效的关键——不填，AI 会拿示例值当项目事实，然后一路错下去。

优先补这四个：`build_command`、`test_command`、`git_user_email`（开源项目一律匿名）、`push_policy`。字段说明与常见错误见 [`references/profile-guide.md`](references/profile-guide.md)。

### 2. 每开一次会话，先说一句

```text
先读 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。
```

模块不会自动加载，靠这句话把分流表打开。不说，模型可能直接开始改代码。

### 3. 验证

```bash
bash scripts/check.sh
```

五项全绿才算装好：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合。

## 要改哪些文件

| 文件 | 动不动 | 说明 |
| --- | --- | --- |
| `.agents/project-profile.md` | **每个项目必改** | 项目事实：语言版本、构建/测试命令、提交身份、部署目标、例外 |
| `AGENTS.md` | 一般不动 | 只在新增语言/平台模块时，往第 2、3 节分流表登记一行 |
| `.agents/*.md` | 按需 | 团队自己的约定写进对应模块，不要都堆到入口文件 |
| `CLAUDE.md` | 项目原来有才动 | 原有内容保留，只在第一行加 `@AGENTS.md` |
| `scripts/check.sh` | 不动 | 自检脚本，改它等于把规则检查绕过去 |
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
| `.agents/project-profile.md` | 每次会话 | 项目事实，唯一必改的文件 |
| `.agents/commit.md` | 写 commit、定分支、打 tag | 类型与单号、三段式格式、粒度禁令、分支与 Tag |
| `.agents/discipline.md` | 提交、碰凭据、收尾 | Git 红线、匿名与脱敏、自测闭环、多会话并行 |
| `.agents/integration.md` | 对接外部系统、调 SDK | HTTP 200 陷阱、签名与编码、时间戳单位、断线缓冲 |
| `.agents/legacy.md` | 接手老项目、重构巨型类 | 体检 grep、找接缝、迁移只搬不改、验收清单 |
| `.agents/lang-*.md` | 改对应语言时 | Java / Python / Vue 各自的坑，通用纪律不重复 |
| `.agents/release-*.md` | 发版、改镜像 | GitHub Actions 与 Docker 的发布、回滚 |
| `CLAUDE.md` | Claude Code 会话 | 一行 `@AGENTS.md`，让只认 CLAUDE.md 的工具读到同一份规范 |
| `scripts/check.sh` | 本地或 CI | 五项自检，见上 |
| `.git/hooks/`（装进去的） | 提交时 | `commit-msg` 校验提交信息；`post-commit` 在有 `.codegraph/` 时同步索引 |
| `templates/github/check.yml` | 目标项目的 CI | 自检 + 历史邮箱扫描 |

`install.sh` / `install.ps1` 负责把这些装到目标项目，默认不覆盖已有文件。运作原理见 [`references/how-it-works.md`](references/how-it-works.md)，扩展写法见 [`references/extending.md`](references/extending.md)。

## 许可

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，可自由复制、修改、商用，需保留署名。全文见 `LICENSE`。

```text
ai-dev-standards by saul, licensed under CC BY 4.0
https://github.com/999bug/ai-dev-standards
```

last-verified: 2026-11-03
