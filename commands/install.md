---
description: 把 AI 开发规范装进当前项目（AGENTS.md + .agents/ 模块 + CLAUDE.md + git 钩子）
argument-hint: "[目标项目目录，默认当前目录]"
---

# 安装 AI 开发规范

目标项目：`$ARGUMENTS`
没给参数就用当前工作目录。

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

默认级别＝规范文件 + `CLAUDE.md` + `.git/hooks/` 下的两个钩子，不写 CI、不写 `scripts/`。
用户明确要 CI 或自检脚本时再加 `--with-ci` / `--with-check`；不想装钩子加 `--no-hooks`。
Windows 等价写法是 `-WithCi` / `-WithCheck` / `-NoHooks`。

## 4. 报告与收尾

1. 贴出安装器最后几行汇总（写入 / 更新 / 跳过）。
2. 提醒两件事：
   - 钩子装在 `.git/hooks/`，不进版本控制，团队其他人 clone 后要各自装；
     想让门禁跟着仓库走，用 `--shared-hooks`（写 `.githooks/` + `core.hooksPath`）。
   - `.agents/project-profile.md` 全是「未定」，必须逐项确认。
3. 主动提出帮用户填 profile：从项目里读事实（`pom.xml` 的 `java.version`、
   `package.json` 的依赖、`.github/workflows/` 的触发方式），能推断的直接填，
   推断不了的一次性列出来问。**不要拿示例值当项目事实。**
