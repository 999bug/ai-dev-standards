# 手动安装

官方插件装不上时走这里。装进项目的是同一批文件，效果一样。

## 前置条件

- `git`
- `bash`（macOS / Linux 自带；Windows 用 Git Bash）
- 目标项目目录。建议是 git 仓库——不是也能装，但 git 钩子不会生效

Windows 的 PowerShell 安装器要求 **PowerShell 7+**（`pwsh`），系统自带的 5.1 跑不了。

## 1. 拿到代码

```bash
git clone https://github.com/999bug/ai-dev-standards.git
cd ai-dev-standards
```

不想用 git 就在 GitHub 页面点 **Code → Download ZIP**，解压后进目录。脚本就在仓库根目录，不需要复制到别处。

## 2. 先预览

```bash
# macOS / Linux / Git Bash
./install.sh /path/to/your-project --dry-run
```

```powershell
# Windows PowerShell 7
.\install.ps1 -Target F:\code\my-project -DryRun
```

预览只打印会写哪些文件，不落盘。第一次装务必先看一眼。

如果提示 `Permission denied`：

```bash
chmod +x install.sh
```

## 3. 正式安装

```bash
# 默认：AGENTS.md + CLAUDE.md + .agents/
#       外加 .git/hooks/ 下的两个钩子（钩子不占项目根目录条目）
./install.sh /path/to/your-project

# 加自检脚本
./install.sh /path/to/your-project --with-check

# 加 CI 门禁（会自动带上 check.sh）
./install.sh /path/to/your-project --with-ci

# 只要规范核心，不要钩子
./install.sh /path/to/your-project --minimal
```

```powershell
# Windows 等价写法
.\install.ps1 -Target F:\code\my-project
.\install.ps1 -Target F:\code\my-project -WithCi
.\install.ps1 -Target F:\code\my-project -Minimal
```

| 选项（sh / ps1） | 装什么 | 项目根新增 |
| --- | --- | --- |
| 默认 | 入口 + 10 个模块 + `CLAUDE.md`，并把钩子装进 `.git/hooks/` | 3 个 |
| `--no-hooks` / `-NoHooks` | 同上，但不装钩子 | 3 个 |
| `--with-check` / `-WithCheck` | 再加 `scripts/check.sh`（五项自检） | 4 个 |
| `--with-ci` / `-WithCi` | 再加 `.github/workflows/check.yml`；会自动带上 `check.sh` | 5 个 |
| `--minimal` / `-Minimal` | 只装 `AGENTS.md` + `.agents/`，也不装钩子 | 2 个 |
| `--force` / `-Force` | 覆盖已存在文件 | — |
| `--dry-run` / `-DryRun` | 只预览，不落盘 | — |

**钩子默认就装**，位置是 `.git/hooks/`，不占项目根目录、也不需要配 `core.hooksPath`。代价是它不进版本控制，别人 clone 后要各自装一次。

**自检脚本默认不装**——多数项目不会去改 `.agents/` 模块，用不上。想跑自检就加 `--with-check`；装了 `--with-ci` 会自动带上，因为 CI 里跑的就是它。

两条约束：

- `--minimal` 与 `--no-hooks` / `--with-check` / `--with-ci` 互斥。它也不装 `CLAUDE.md`，Claude Code 会读不到规范，只适合完全不用 Claude Code 的场景。
- **默认不覆盖已存在的文件**。装过一次再跑是幂等的（写入 0，全部跳过）。目标项目可能已经改过某个模块，要覆盖必须显式加 `--force`，先确认清楚。钩子是例外——装了才生效，所以已有同名钩子会先备份再覆盖。

## 4. 确认装了什么

```bash
cd /path/to/your-project
ls AGENTS.md CLAUDE.md .agents scripts/check.sh
bash scripts/check.sh
```

五项全绿才算装好：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合。

Windows 上跑 `check.sh` 需要 Git Bash；也可以直接用项目里的 CI 跑同一份检查。

### 装完必做：填 profile

`.agents/project-profile.md` 里全是「未定」，逐项确认。不填等于让 AI 拿示例值当项目事实。字段说明与常见错误见 [`references/profile-guide.md`](../references/profile-guide.md)。

优先补这四个：`build_command`、`test_command`、`git_user_email`、`push_policy`。

## 5. 项目里原来就有 CLAUDE.md

安装器会跳过它，`AGENTS.md` 装了也读不到。手动在 `CLAUDE.md` 的**第一行**加：

```markdown
@AGENTS.md
```

原有内容一行不用动。注意别在新项目里跑 `/init`，它会把这一行冲掉。

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

不想要钩子：重装时加 `--no-hooks`，或直接删掉 `.git/hooks/commit-msg` 和 `.git/hooks/post-commit`。

已有同名钩子不会被静默丢掉——安装器会先备份成 `commit-msg.bak.<时间戳>` 再覆盖。

临时跳过：

```bash
SKIP_COMMIT_MSG_CHECK=1 git commit ...
SKIP_CODEGRAPH_SYNC=1 git commit ...
```

## 7. 更新

```bash
cd ai-dev-standards
git pull

# 先不加 --force 跑一次：结尾列出的「已存在、未被覆盖」就是更新会盖掉的文件
./install.sh /path/to/your-project --dry-run

# 确认后再覆盖
./install.sh /path/to/your-project --force
```

`--force` 会盖掉目标项目里改过的同名文件。先用 `git diff`（目标项目是 git 仓库的话）确认自己没有本地修改。

## 卸载与清理

先删插件（如果装过）：

```bash
claude plugin uninstall ai-dev-standards@ai-dev-standards --scope local
claude plugin marketplace remove ai-dev-standards
```

插件只管自己，**项目里的文件要手动删**。先确认这些文件确实是安装器写的，`.agents/` 里如果加过自己的模块，先备份。

```bash
cd /path/to/your-project

# 安装器写入的文件
rm -rf .agents
rm -f AGENTS.md scripts/check.sh
rmdir scripts 2>/dev/null || true

# 钩子（默认就装，不想要就删）
rm -f .git/hooks/commit-msg .git/hooks/post-commit

# CI（装过 --with-ci 才有）
rm -f .github/workflows/check.yml
```

`CLAUDE.md` 要单独判断：安装器创建的（内容只有一行 `@AGENTS.md`）可以直接删；原本就存在的，只删掉 `@AGENTS.md` 那一行，别整份删。

Windows PowerShell：

```powershell
Remove-Item -Recurse -Force .agents -ErrorAction SilentlyContinue
Remove-Item -Force AGENTS.md, scripts\check.sh -ErrorAction SilentlyContinue
Remove-Item -Force .git\hooks\commit-msg, .git\hooks\post-commit -ErrorAction SilentlyContinue
Remove-Item -Force .github\workflows\check.yml -ErrorAction SilentlyContinue
```

## 常见问题

| 现象 | 原因与处理 |
| --- | --- |
| `Permission denied` | 没执行权限，`chmod +x install.sh` |
| `未知选项: --with-ci` | 在 PowerShell 里跑了 sh 参数。换成 `-WithCi` |
| 提示目标不是 git 仓库 | 文件照装，钩子跳过（`.git/hooks/` 需要仓库）；要钩子就先 `git init` |
| 钩子装了但不生效 | 项目设过 `core.hooksPath`，git 会忽略 `.git/hooks/`。`git config --unset core.hooksPath` |
| 输出「写入 0 个文件」 | 已经装过，这是幂等行为。要更新加 `--force`，先预览 |
| `check.sh` 报引用了不存在的文件 | 文档里写了不存在的 `.md`。改文件名或删引用，别加白名单绕 |
| `check.sh` 报模块没登记 | 新增了 `.agents/*.md`，但没在 `AGENTS.md` 分流表登记 |
| 提交被 `commit-msg` 拒绝 | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC` |
| Claude Code 读不到规范 | `CLAUDE.md` 首行缺 `@AGENTS.md`，或被 `/init` 覆盖了 |
| 装完没有任何提示 | 不是 git 仓库 / 已有 `AGENTS.md` / 有豁免标记 `.claude/no-ai-dev-standards` |
