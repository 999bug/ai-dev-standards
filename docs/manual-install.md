# 手动安装

不想用插件命令、或者插件装不上时走这里。装进项目的是同一批文件，效果一样。

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
| 默认 | 入口 + 与项目相关的模块（按语言/平台裁剪）+ `CLAUDE.md`，钩子进 `.git/hooks/` | 3 个 |
| `--no-hooks` / `-NoHooks` | 同上，但不装钩子 | 3 个 |
| `--with-check` / `-WithCheck` | 再加 `scripts/check.sh`（七项自检） | 4 个 |
| `--with-ci` / `-WithCi` | 再加 `.github/workflows/check.yml`；会自动带上 `check.sh` | 5 个 |
| `--shared-hooks` / `-SharedHooks` | 钩子改写进项目里的 `.githooks/`，并设 `core.hooksPath` | 4 个 |
| `--all-modules` / `-AllModules` | 不裁剪，全部模块都装 | 3 个 |
| `--modules=a,b` / `-Modules` | 只装指定模块 | 3 个 |
| `--minimal` / `-Minimal` | 只装 `AGENTS.md` + `.agents/`，也不装钩子 | 2 个 |
| `--upgrade` / `-Upgrade` | 升级：没改过的更新，改过的另存 `.new` | — |
| `--force` / `-Force` | 覆盖已存在文件 | — |
| `--dry-run` / `-DryRun` | 只预览，不落盘 | — |

**默认按项目裁剪模块**，不把无关规范塞进来：

| 项目 | 装几个模块 |
| --- | --- |
| 纯 Java、无 GitHub、无 Docker | 7 |
| Java + GitHub Actions + Dockerfile | 9 |
| 前端 Vue + GitHub + Docker | 9 |
| 全量（`--all-modules`） | 11 |

判断依据是文件存在性：`pom.xml`/`build.gradle` → Java，`pyproject.toml` → Python，`package.json` + `vue` → Vue，`.github/workflows/` 或 github remote → 发布规范，`Dockerfile`/`compose` → 容器规范。跨语言的项目档案、提交、纪律、任务工作流、外部对接、老系统方法论始终装。

`AGENTS.md` 的分流表会同步删掉未装模块的行——否则 AI 会照表去读不存在的文件。

**钩子默认就装**，位置是 `.git/hooks/`，不占项目根目录、也不需要配 `core.hooksPath`。代价是它不进版本控制，别人 clone 后要各自装一次。想让门禁跟着仓库走、团队 clone 后直接生效，用 `--shared-hooks`：钩子写进 `.githooks/`，并执行 `git config core.hooksPath .githooks`（这条会改项目的 git 配置，所以不默认做）。

**自检脚本默认不装**——多数项目不会去改 `.agents/` 模块，用不上。想跑自检就加 `--with-check`；装了 `--with-ci` 会自动带上，因为 CI 里跑的就是它。

两条约束：

- `--minimal` 与 `--no-hooks` / `--with-check` / `--with-ci` 互斥。它也不装 `CLAUDE.md`，Claude Code 会读不到规范，只适合完全不用 Claude Code 的场景。
- **默认不覆盖已存在的文件**。装过一次再跑会全部跳过（输出「写入 0 个文件」）：内容与模板相同的文件不计入写入，钩子也不再每次重写。内容不同的不会被覆盖，那是你的改动。
- **要更新用 `--upgrade`，不要用 `--force`**。安装器在 `.agents/.standards-version` 里记了每个文件的 sha256：hash 对得上（说明装完之后没被改过）才覆盖成新版，对不上就把新版写成 `<文件>.new`，原文件和你手动合并。`--force` 是无条件覆盖，只在确认要以模板为准时用。

## 4. 确认装了什么

```bash
cd /path/to/your-project
ls AGENTS.md CLAUDE.md .agents scripts/check.sh
bash scripts/check.sh
```

七项全绿才算装好：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合、数字对账、插件清单。

Windows 上跑 `check.sh` 需要 Git Bash；也可以直接用项目里的 CI 跑同一份检查。

### 装完必做：补齐 profile

首次安装已经按探测结果写了初稿（项目名、语言版本、构建/测试命令、提交风格等），只剩 `type` / `visibility` / `verify_*` 需要确认：

```text
/ai-dev-standards:profile
```

不装插件的话，让 AI 按 [`references/profile-guide.md`](../references/profile-guide.md) 的「一键生成」执行同一套流程。

**升级不会改这个文件**，需要按新模板重整时手动跑上面的命令。探测不到的字段会留「未定」并列成清单——**不填等于让 AI 拿示例值当项目事实**。

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

已有同名钩子不会被停用。安装器把它保留成 `commit-msg.local`，规范钩子校验通过后会接着执行它——你原来的逻辑照旧生效，两边的门禁是叠加的，不是替换。

想确认发生了什么：

```bash
ls .git/hooks/ | grep -E 'commit-msg|post-commit'
# commit-msg          ← 规范的校验
# commit-msg.local    ← 你原来的钩子，会被自动调用
```

临时跳过：

```bash
SKIP_COMMIT_MSG_CHECK=1 git commit ...
SKIP_CODEGRAPH_SYNC=1 git commit ...
```

## 7. 更新

```bash
cd ai-dev-standards
git pull

# 先预览：哪些会更新（没改过）、哪些会冲突（你改过）
./install.sh /path/to/your-project --upgrade --dry-run

# 确认后执行
./install.sh /path/to/your-project --upgrade
```

`--upgrade` 的判断依据是 `.agents/.standards-version` 里记录的 sha256：

| 结果 | 含义 |
| --- | --- |
| 更新 | 装完之后没被改过，直接覆盖成新版 |
| 跳过 | 内容已经和新版一致 |
| 冲突 → `.new` | 本地改过，新版另存为 `<文件>.new`，原文件不动 |

有 `.new` 就逐个 diff 合并，然后删掉 `.new`。**不要图省事改用 `--force`**——那会把你的所有本地改动一起盖掉。

从 1.4.0 及更早版本升上来的项目没有安装清单，`--upgrade` 会把所有内容不同的文件都当成冲突（因为没有依据判断谁改过）。这种情况先跑一次普通安装（`./install.sh <目标>`）补齐清单，之后升级就正常了。

注意：裁剪规则变了（比如项目删掉了 Dockerfile）**不会删除已装的模块**，只是不再更新它。确认不需要时手动删 `.agents/` 下对应文件，并从 `AGENTS.md` 分流表里去掉那一行。

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
rm -rf .githooks && git config --unset core.hooksPath 2>/dev/null

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
| 输出「写入 0 个文件」 | 已经装过，且内容与模板一致（默认级别的钩子也不再重写）。要更新用 `--upgrade`，先预览 |
| 输出「有 N 个文件本地改动过」 | `--upgrade` 发现这些文件装完之后被改过，新版写成了 `.new`。逐个 diff 合并后删掉 `.new` |
| `check.sh` 报引用了不存在的文件 | 文档里写了不存在的 `.md`。改文件名或删引用，别加白名单绕 |
| `check.sh` 报模块没登记 | 新增了 `.agents/*.md`，但没在 `AGENTS.md` 分流表登记 |
| `check.sh` 报「文档里的数字过期」 | 「N 个模块」「写入 N 个文件」与实际不符，按提示改 |
| 提交被 `commit-msg` 拒绝 | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC` |
| Claude Code 读不到规范 | `CLAUDE.md` 首行缺 `@AGENTS.md`，或被 `/init` 覆盖了 |
| 会话启动没看到 `[ai-dev-standards]` 提示 | 不是 git 仓库；或改用 `AI_DEV_STANDARDS_SKIP=1` / `QUIET=1` 关掉了；或项目还没装（装完才有提示） |
