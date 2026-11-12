# AI 开发规范

**给 AI 编码工具用的一套开发规范。** 装上之后，Claude Code / Codex / Cursor / WorkBuddy 改代码前会先读你的规矩——怎么提交、怎么发版、这门语言有哪些坑——而不是按它自己的默认习惯来。

**规范本体装一次，所有项目共用；每个项目只初始化一次。**

- 规范本体（入口 + 14 个模块）放在 `~/.ai-dev-standards/`，升级只升这一处
- 项目里只多 3 个文件：指向全局的 `AGENTS.md` 指针、一行 `CLAUDE.md`、`.agents/project-profile.md`
- 项目事实（语言版本、构建命令、提交身份）写进 profile，通用规则永远不复制第二份

## 装完有什么变化

1. **AI 按你的规范改代码**：先诊断再动手、一次只做一件事、不伪造结果、不提交凭据
2. **提交格式有门禁**：`commit-msg` 钩子在本地拦下格式不对的提交
3. **语言与发布有专属模块**：Java / Python / Vue / Android 的坑，GitHub / Docker / Gitee 的发版流程，按任务加载

## 它由什么组成

| 位置                                | 内容                                 | 谁来改        |
| --------------------------------- | ---------------------------------- | ---------- |
| `~/.ai-dev-standards/`            | `AGENTS.md` 入口、14 个模块、钩子与项目模板、自检脚本 | 不手改，跟着升级   |
| `<项目>/AGENTS.md`                  | 约 20 行的指针：规范在哪、按什么顺序读              | 内容固定       |
| `<项目>/CLAUDE.md`                  | 一行 `@AGENTS.md`                    | 内容固定       |
| `<项目>/.agents/project-profile.md` | 项目事实：语言版本、构建命令、提交身份、例外             | **每个项目必改** |
| `<项目>/.git/hooks/`                | `commit-msg`、`post-commit`         | 不用管        |

全局目录一次装 22 个文件；项目侧只多 3 个文件，钩子不占根目录条目。

## 安装

### 1. 装插件

```bash
claude plugin marketplace add 999bug/ai-dev-standards
claude plugin install ai-dev-standards@ai-dev-standards --scope user
```

装完**退出会话再重进**（插件在会话启动时加载）。

### 2. 装全局规范 + 初始化当前项目

在任意项目里执行：

```text
/ai-dev-standards:install
```

它按顺序做三件事，每步都先预览、确认后才落盘：

1. 把规范装到 `~/.ai-dev-standards/`（22 个文件）
2. 给当前项目写 `AGENTS.md`、`CLAUDE.md`、`.agents/project-profile.md`
3. 把两个 git 钩子装进 `.git/hooks/`

已经装过就跳过：重跑输出「写入 0 个文件」。

### 3. 补齐项目档案

```text
/ai-dev-standards:profile
```

只问四个必须由人决定的选择（仓库性质、提交风格、推送策略、是否现在跑验证），其余从项目里读。没问到的留「未定」，AI 遇到「未定」必须停下来问，不许猜。

### 不用插件

两步命令，效果一样：

```bash
git clone https://github.com/999bug/ai-dev-standards.git
./ai-dev-standards/install.sh --global                 # 全局一次
./ai-dev-standards/install.sh /path/to/your-project    # 每个项目一次
```

Windows 写法与完整步骤：[docs/manual-install.md](docs/manual-install.md)

## 卸载

三步独立，按需选。

### 1. 项目侧

每个初始化过的项目各做一次。**先备份 `.agents/project-profile.md`**——里面是项目事实，删了要重填。

```bash
cd /path/to/your-project
cp .agents/project-profile.md /tmp/profile-backup.md

rm -f AGENTS.md
rm -f .agents/project-profile.md
rmdir .agents 2>/dev/null || true
rm -f .git/hooks/commit-msg .git/hooks/post-commit
```

`CLAUDE.md` 单独判断：内容只有 `@AGENTS.md` 的直接删；原本就有内容的，只删掉那一行。

### 2. 全局规范

```bash
ls ~/.ai-dev-standards/.backup    # 先看有没有要留的备份
rm -rf ~/.ai-dev-standards
```

全局目录如果是 clone 的仓库，删之前确认没有未推送的改动。

### 3. 插件

```bash
claude plugin uninstall ai-dev-standards@ai-dev-standards
claude plugin marketplace remove ai-dev-standards
```

只删插件、保留全局目录时，项目里的指针照样能读到规范，只是没有命令和会话提示了。

## 升级

**两步，顺序不能反。** 规范本体不是插件文件，是安装器第一次运行时写进全局目录的产物；`claude plugin update` 只更新插件缓存，不会碰它，也不会提示版本落后。

```bash
claude plugin update ai-dev-standards@ai-dev-standards   # ① 升插件：命令、安装器、模板
# 退出会话重进，新命令才会加载；第三方市场默认不开自动更新
```

```text
/ai-dev-standards:upgrade                                # ② 升全局规范本体
```

② 只升 `~/.ai-dev-standards/` 这一处，所有项目同时生效。项目侧 3 个文件 + 2 个钩子内容固定，**不用重跑 install**。改过的全局模块会先备份到 `.backup/<时间戳>/` 再覆盖。

顺序反了会静默失效：旧安装器拿旧模板比对，判定「内容一致」全部跳过。核对版本：`grep '^version=' ~/.ai-dev-standards/.standards-version`。

斜杠命令只是壳，直接在 shell 跑 `bash ~/.claude/plugins/cache/ai-dev-standards/<版本>/install.sh --global --upgrade` 等价，代价是自己找版本目录、自己看预览。

### 例外：全局目录是 clone 的仓库

清单里 `source=git` / `source=repo` 时，`git -C ~/.ai-dev-standards pull --ff-only` 就能更新规范本体，不必跑 ②；插件缓存那份仍要单独更新。

### WorkBuddy / 不用插件时

没有 `/ai-dev-standards:upgrade`，那是 Claude Code 插件的命名空间命令。更新同样两层，第一层换成 `git pull`：

```bash
git -C ~/.workbuddy/skills/ai-dev-standards pull --ff-only   # ① 更新 skill 副本
# 新开一段对话让新 skill 生效
bash ~/.workbuddy/skills/ai-dev-standards/install.sh --global --upgrade --dry-run
bash ~/.workbuddy/skills/ai-dev-standards/install.sh --global --upgrade   # ② 刷新全局目录
```

顺序不能反：旧版 skill 的安装器可能没有 `--global`（1.10.0 就只有项目模式的 `--upgrade`）。项目侧仍不用动。完整流程与排错见 [docs/manual-install.md](docs/manual-install.md)。

想定制规则，写进项目 `.agents/project-profile.md` 第 8 节 `overrides`，不要改全局模块。

## 支持哪些工具

| 工具             | 入口             | 额外动作       |
| -------------- | -------------- | ---------- |
| Claude Code    | 项目 `CLAUDE.md` | 无（初始化时已带上） |
| WorkBuddy      | 项目 `AGENTS.md` | 无          |
| Codex          | 项目 `AGENTS.md` | 无          |
| Cursor         | 项目 `AGENTS.md` | 无          |
| opencode       | 项目 `AGENTS.md` | 无          |
| GitHub Copilot | 项目 `AGENTS.md` | 无          |

各工具的验证问题与官方文档：[docs/other-agents.md](docs/other-agents.md)

指针要求模型读工作区外的文件。Claude Code 首次读 `~/.ai-dev-standards/` 会弹一次权限确认；个别限制工作区外读取的工具，把需要的模块复制进项目 `.agents/` 即可。

## 常见问题

| 现象                            | 处理                                                   |
| ----------------------------- | ---------------------------------------------------- |
| 初始化报「全局规范未安装」                 | 先跑 `--global`，或用 `/ai-dev-standards:install` 让它自己串起来 |
| 初始化列出 `.agents/commit.md` 等模块 | 旧结构。安装器只报告不删，按打印的命令清理后重跑                             |
| 同事 clone 后读不到规范               | 规范跟着机器走，让对方也跑一次 `--global`                           |
| Claude Code 读不到规范             | 查项目 `CLAUDE.md` 首行是不是 `@AGENTS.md`；`/init` 会把它冲掉     |
| 提交被拒绝                         | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC`         |
| 插件升了、规范还是旧版                  | `plugin update` 只升插件缓存，还要跑 `/ai-dev-standards:upgrade`          |

更多问题：[docs/manual-install.md](docs/manual-install.md)

## 为什么这样设计

- **入口必须短**：`AGENTS.md` 限 150 行，因为模型读长文档时开头权重远高于结尾
- **规则分三档**：红线 / 默认 / 建议，不分档等于没有优先级
- **模块按任务加载**：一次只读 1–2 个，不把 14 个模块全塞进上下文
- **规范跟机器走**：升级只升全局这一处，不用每个项目重跑；代价是同事要各自装一次全局

细节见 [references/how-it-works.md](references/how-it-works.md)。

## 许可

文档 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，脚本（`install.sh`、`install.ps1`、`hooks/`、`scripts/`、`templates/githooks/`）用 MIT，见 `LICENSE` 与 `LICENSE-MIT`。

```text
ai-dev-standards by saul, licensed under CC BY 4.0 (docs) and MIT (scripts)
https://github.com/999bug/ai-dev-standards
```

last-verified: 2026-11-12
