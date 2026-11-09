---
description: 把 AI 开发规范装进当前项目（AGENTS.md + .agents/ 模块 + CLAUDE.md + git 钩子）
argument-hint: "[目标项目目录，默认当前目录]"
---

# 安装 AI 开发规范

目标项目：`$ARGUMENTS`
没给参数就用当前工作目录。

> 路径解析：`${CLAUDE_PLUGIN_ROOT}` 由插件注入。万一它为空，先跑
> `ls ~/.claude/plugins/cache/ai-dev-standards/` 找到版本目录，用那个绝对路径代替，
> 不要凭猜写路径。

## 1. 先确认目标

```bash
git -C "<目标>" rev-parse --show-toplevel
```

- 输出的是仓库根目录就以它为准；不是 git 仓库就用原目录（钩子会被跳过，其余照装）。
- 目标目录里如果已经有 `.agents/project-profile.md`，说明装过了。**停下来告诉用户**，不要重复装；要升级请让用户改用 `/ai-dev-standards:upgrade`。

## 2. 预览（不要跳过）

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" "<目标>" --dry-run
```

Windows 上没有 `bash` 时改用：

```
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/install.ps1" -Target "<目标>" -DryRun
```

把预览结果原样贴给用户：会新增哪些文件、跳过哪些。**等用户确认后再执行第 3 步。**

## 3. 正式安装

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" "<目标>"
```

默认级别＝**与项目相关**的规范模块 + `CLAUDE.md` + `.git/hooks/` 下的两个钩子，不写 CI、不写 `scripts/`。

安装器会按项目裁剪模块：Android 项目装 Android 那份（含签名发版）不装 Java，Java 项目不装 Python/Vue 规范，没用 GitHub 不装发布规范，没有 Docker 不装容器规范。`AGENTS.md` 的分流表会同步删掉未装模块的行。汇总里会写「模块：7/13（与项目无关，跳过 …）」——如果它判断错了，用 `--modules=` 补装，或 `--all-modules` 全装。

用户明确要 CI 或自检脚本时再加 `--with-ci` / `--with-check`；不想装钩子加 `--no-hooks`。
Windows 等价写法是 `-WithCi` / `-WithCheck` / `-NoHooks` / `-AllModules` / `-Modules`。

## 4. 报告，然后直接生成 profile

1. 贴出安装器最后几行汇总（写入 / 更新 / 跳过）。
2. 提醒一件事：钩子装在 `.git/hooks/`，不进版本控制，团队其他人 clone 后要各自装；
   想让门禁跟着仓库走，用 `--shared-hooks`（写 `.githooks/` + `core.hooksPath`）。
3. **不要问「要不要帮你填 profile」**：安装器已经按探测结果写了初稿（项目名、语言、构建命令、
   提交风格等）。接下来读 `commands/profile.md`，只补还没填的：
   `type` / `visibility` / `verify_*`（其余「未定」顺手问清）。

别把「补 profile」当成可选项留给用户手填——初稿已经在了，你只差几个只有人能答的选择。
唯一例外：用户明确说"先别填"，那就告诉他随时可以跑 `/ai-dev-standards:profile`。
