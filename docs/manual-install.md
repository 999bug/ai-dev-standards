# 手动安装

不想用插件命令、或者插件装不上时走这里。装的是同一套文件，效果一样。

分两步，顺序不能反：**先全局装一次，再给每个项目初始化一次**。

## 前置条件

- `git`
- `bash`（macOS / Linux 自带；Windows 用 Git Bash）
- 目标项目目录。建议是 git 仓库——不是也能初始化，但 git 钩子不会生效

Windows 的 PowerShell 安装器要求 **PowerShell 7+**（`pwsh`），系统自带的 5.1 跑不了。

## 1. 拿到代码

```bash
git clone https://github.com/999bug/ai-dev-standards.git
cd ai-dev-standards
```

不想用 git 就在 GitHub 页面点 **Code → Download ZIP**，解压后进目录。

也可以直接 clone 到全局位置，省掉第 2 步的复制：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.ai-dev-standards
```

## 2. 全局安装（只做一次）

```bash
# macOS / Linux / Git Bash
./install.sh --global --dry-run
./install.sh --global
```

```powershell
# Windows PowerShell 7
.\install.ps1 -Global -DryRun
.\install.ps1 -Global
```

默认装到 `~/.ai-dev-standards/`，共 22 个文件。想换位置就设环境变量：

```bash
export AI_DEV_STANDARDS_HOME=/path/to/standards
./install.sh --global
```

装完这个目录里有：

```
~/.ai-dev-standards/
├── AGENTS.md                入口
├── .agents/                 14 个模块 + project-profile 模板
├── scripts/                 check.sh · detect-profile.sh
├── templates/               钩子、项目指针、CI 模板
└── .standards-version       版本与每个文件的 sha256
```

**幂等**：重复跑只会输出「写入 0 个文件」。全局已经被你改过的文件，`--upgrade` 会先备份到 `.backup/<时间戳>/` 再覆盖。

## 3. 项目初始化（每个项目一次）

```bash
./install.sh /path/to/your-project --dry-run
./install.sh /path/to/your-project
```

```powershell
.\install.ps1 -Target F:\code\my-project -DryRun
.\install.ps1 -Target F:\code\my-project
```

正常只写三样东西：

| 文件 | 内容 |
| --- | --- |
| `AGENTS.md` | 指向全局目录的指针，约 20 行 |
| `CLAUDE.md` | 一行 `@AGENTS.md` |
| `.agents/project-profile.md` | 项目事实，已按探测结果填初稿 |

外加 `.git/hooks/` 下两个钩子（不占项目根目录条目）。

| 选项（sh / ps1） | 作用 |
| --- | --- |
| `--no-hooks` / `-NoHooks` | 不装 git 钩子 |
| `--force` / `-Force` | 覆盖已存在的文件 |
| `--dry-run` / `-DryRun` | 只预览，不落盘 |

两条约束：

- **默认不覆盖已存在的文件。** 项目原来就有 `AGENTS.md` 或 `CLAUDE.md` 时只提示、不落盘——那可能是人家自己的规范。按提示手动加一段指向全局目录的说明，或第一行加 `@AGENTS.md`。
- **项目侧不需要升级。** 这里只有指针和 profile，内容固定；升级只作用于全局目录。

## 4. 确认装了什么

```bash
cd /path/to/your-project
ls AGENTS.md CLAUDE.md .agents/project-profile.md
```

指针内容应该是这样：

```bash
cat AGENTS.md
# 本文件是指针，不是规范本体。规范装在全局目录...
```

再确认全局可读：

```bash
cat "${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}/AGENTS.md" | head -3
```

### 装完必做：补齐 profile

首次初始化已经按探测结果写了初稿（项目名、语言版本、构建/测试命令、提交风格等），只剩 `type` / `visibility` / `verify_*` 需要确认：

```text
/ai-dev-standards:profile
```

不装插件的话，让 AI 按 [`references/profile-guide.md`](../references/profile-guide.md) 的「一键生成」执行同一套流程。

探测不到的字段会留「未定」并列成清单——**不填等于让 AI 拿示例值当项目事实**。

## 5. 项目里原来就有文件

### CLAUDE.md

安装器不会覆盖它，于是 `AGENTS.md` 装了也读不到。手动在**第一行**加：

```markdown
@AGENTS.md
```

原有内容一行不用动。注意别在新项目里跑 `/init`，它会把这一行冲掉。

### AGENTS.md

安装器同样不会覆盖。在文件开头加一段即可：

```markdown
> 本仓库的 AI 开发规范在全局目录：
> `${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}/`
> 开工前先读该目录下的 AGENTS.md，模块路径相对它所在目录；再读本仓库
> `.agents/project-profile.md`。
```

## 6. git 钩子

默认就装了，位置是 `.git/hooks/`：

```bash
ls -l .git/hooks/commit-msg .git/hooks/post-commit
```

两个钩子的作用：

- `commit-msg`：按 `.agents/commit.md` 校验提交信息，格式不对直接拒绝
- `post-commit`：项目有 `.codegraph/` 时提交后同步索引，失败或超时只提示、不阻塞提交

**注意 `core.hooksPath`**：项目之前设过这个值的话，git 会完全忽略 `.git/hooks/`，钩子装了也不生效。检查并清掉：

```bash
git config --get core.hooksPath     # 有输出说明设过
git config --unset core.hooksPath
```

不想要钩子：重装时加 `--no-hooks`，或直接删掉两个钩子文件。

已有同名钩子不会被停用。安装器把它保留成 `commit-msg.local`，规范钩子校验通过后会接着执行它——两边门禁叠加，不是替换。

临时跳过：

```bash
SKIP_COMMIT_MSG_CHECK=1 git commit ...
SKIP_CODEGRAPH_SYNC=1 git commit ...
```

## 7. 更新

不管用哪个工具，更新都是「先拿到新代码 → 再用新安装器刷全局目录」，顺序不能反。

仓库若是 clone 到 WorkBuddy 的 skill 目录，把下面的 `cd ai-dev-standards` 换成 `cd ~/.workbuddy/skills/ai-dev-standards`；跑完**新开一段对话**让新 skill 生效。WorkBuddy 没有斜杠命令，也可以直接在对话里说「升级 AI 开发规范」让 skill 触发。项目侧不用动。

```bash
cd ai-dev-standards
git pull

# 预览
./install.sh --global --upgrade --dry-run

# 执行
./install.sh --global --upgrade
```

判断依据是全局目录 `.standards-version` 里记录的 sha256：

| 结果 | 含义 |
| --- | --- |
| 更新 | 装完之后没被改过，直接覆盖成新版 |
| 跳过 | 内容已经和新版一致 |
| 你改过 → 备份到 `.backup/<时间戳>/` 后覆盖 | 全局模块被本地改过，旧版先备份 |

备份在 `~/.ai-dev-standards/.backup/<时间戳>/`，随时可以取回。

**不要为了定制去改全局模块。** 把偏离写进项目 `.agents/project-profile.md` 第 8 节 `overrides`，全局保持原样，下次升级就不会冲突。**也不要用 `--force` 图省事**。

## 8. 从 1.12.x 及更早升级

老版本把模块复制进了项目。新结构下这些副本要清掉，否则 AI 会同时读到两份规范。

在旧项目里跑一次初始化：

```bash
./install.sh /path/to/old-project
```

它会检测到旧结构，**只打印清理清单和命令，不删任何文件**，然后退出：

```text
需要清理的：
  .agents/commit.md
  .agents/discipline.md
  ...
  .agents/.standards-version
  AGENTS.md

确认无误后执行（project-profile.md 不动）：
  cd "/path/to/old-project"
  git rm -q .agents/commit.md .agents/discipline.md ...
  /path/to/ai-dev-standards/install.sh "/path/to/old-project"
```

确认清单无误后照做，再跑一次就已经是新结构了。`project-profile.md` 不在清理范围，项目事实不会丢。

清理前建议先提交一次，万一删错还能从 git 找回。

## 卸载与清理

先删插件（如果装过）：

```bash
claude plugin uninstall ai-dev-standards@ai-dev-standards --scope user
claude plugin marketplace remove ai-dev-standards
```

### 项目侧

```bash
cd /path/to/your-project

# 指针与项目档案（profile 里有你的项目事实，先备份再删）
rm -f AGENTS.md .agents/project-profile.md
rmdir .agents 2>/dev/null || true

# 钩子
rm -f .git/hooks/commit-msg .git/hooks/post-commit
```

`CLAUDE.md` 要单独判断：安装器创建的（内容只有一行 `@AGENTS.md`）可以直接删；原本就存在的，只删掉 `@AGENTS.md` 那一行。

Windows PowerShell：

```powershell
Remove-Item -Force AGENTS.md, .agents\project-profile.md -ErrorAction SilentlyContinue
Remove-Item -Force .git\hooks\commit-msg, .git\hooks\post-commit -ErrorAction SilentlyContinue
```

### 全局目录

全局目录里可能有你的 `.backup/`，先看一眼再删：

```bash
ls ~/.ai-dev-standards
rm -rf ~/.ai-dev-standards
```

如果它是 git clone 的仓库，删之前确认没有未推送的改动。

## 常见问题

| 现象 | 原因与处理 |
| --- | --- |
| `Permission denied` | 没执行权限，`chmod +x install.sh` |
| `未知选项: --with-ci` | 1.13.0 起删了这些开关。模块全量装在全局，项目侧只写 3 个文件 |
| 初始化时报「全局规范未安装」 | 先跑 `--global`。手动两个安装器都要分两步 |
| 提示目标不是 git 仓库 | 文件照装，钩子跳过（`.git/hooks/` 需要仓库）；要钩子就先 `git init` |
| 钩子装了但不生效 | 项目设过 `core.hooksPath`，git 会忽略 `.git/hooks/`。`git config --unset core.hooksPath` |
| 初始化输出「写入 0 个文件」 | 已经初始化过，内容与模板一致 |
| 列出 `.agents/commit.md` 等模块 | 旧结构。安装器只报告不删，按打印的命令清理后重跑 |
| `check.sh` 报引用了不存在的文件 | 文档里写了不存在的 `.md`。改文件名或删引用，别加白名单绕 |
| `check.sh` 报文档里的数字过期 | 「N 个模块」「全局 N 个文件」与实际不符，按提示改 |
| 提交被 `commit-msg` 拒绝 | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC` |
| Claude Code 读不到规范 | 项目 `CLAUDE.md` 首行缺 `@AGENTS.md`，或被 `/init` 覆盖了 |
| 会话启动没看到 `[ai-dev-standards]` 提示 | 不是 git 仓库；或用了 `AI_DEV_STANDARDS_SKIP=1` / `QUIET=1`；或还没初始化 |
| 同事 clone 后读不到规范 | 规范跟着机器走，让对方也跑一次 `--global` |
