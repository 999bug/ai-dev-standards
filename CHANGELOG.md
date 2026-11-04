# 变更记录

版本号是插件的更新依据：`plugin.json` 里的 `version` 不变，装了插件的用户就收不到新版。
发版流程见 `scripts/release.sh`。

## [1.5.0] - 2026-11-04

### 破坏性变更

- **去掉 SessionStart 自动安装**。以前装完插件、在任意 git 仓库开一次会话就会自动写入 15 个文件，
  其中还包括会改变提交行为的 git 钩子。这和规范自己的第一条红线「先诊断、后动手」冲突，
  而且插件装成 `user` scope 时会影响所有仓库。安装改为显式命令：`/ai-dev-standards:install`。
- SessionStart hook 保留，但只输出两三行上下文（是否已装、还有几处「未定」、按分流表加载模块），
  不再写任何文件，也不再自动执行 `codegraph init`。

### 新增

- `/ai-dev-standards:install` 与 `/ai-dev-standards:upgrade` 两个插件命令。
- `install.sh --upgrade` / `install.ps1 -Upgrade`：按 `.agents/.standards-version` 里记录的
  sha256 判断文件是否被本地改过，没改过的更新、改过的另存为 `<文件>.new`。
- `install.sh --shared-hooks` / `install.ps1 -SharedHooks`：钩子写进项目的 `.githooks/`
  并设置 `core.hooksPath`，让门禁跟着仓库走，团队 clone 后直接生效。
- 安装清单 `.agents/.standards-version`，记录版本与每个文件的 hash。
- `scripts/check.sh` 第 6 项数字对账（模块数、默认安装文件数）、第 7 项插件清单自洽
  （plugin.json 版本 == CHANGELOG 首条、hooks 引用的脚本存在、命令有 description）。
- `scripts/release.sh`：一条命令改版本、补 CHANGELOG、跑自检、打 tag。
- `LICENSE-MIT`：脚本部分改用 MIT，文档仍是 CC BY 4.0。

### 修复

- **重复安装不再重写钩子**。之前每次跑都会重写两个钩子，输出「写入 2 个文件」，
  和文档里写的「写入 0，全部跳过」不符；现在内容相同就真跳过。
- `check.sh` 之前漏检 `docs/*.md`（两个最长的文档），往里面塞真实邮箱都能全绿。
- `check.sh` 第 4 项之前只认反引号里的路径，README 用的 markdown 链接整片漏检。
- 冲突文件不再把本地改动后的 hash 写进安装清单，避免下一次 `--upgrade` 静默覆盖。

## [1.4.0] - 2026-11-03

- `project-profile.md` 支持按映射表从 `/init` 产物生成初稿。

## [1.3.0] - 2026-11-03

- 新增 `.agents/task-workflow.md`：长任务拆分、台账与交接、子代理任务书。

## [1.2.0] - 2026-10-30

- 钩子改为链式调用：已有的自定义钩子保留为 `.local`，由规范钩子接着执行，不再停用。
- 自检脚本改为按需安装（`--with-check`），默认不写 `scripts/`。
- 钩子改为默认安装，落到 `.git/hooks/`；`post-commit` 增加 codegraph 索引同步。

## [1.1.0] - 2026-10-30

- 插件自带 SessionStart hook，首次在项目里开会话时自动安装规范。

## [1.0.0] - 2026-10-30

- 首个版本：`AGENTS.md` 入口 + `.agents/` 模块 + 安装器 + 插件市场分发。
