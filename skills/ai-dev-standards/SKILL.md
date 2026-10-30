---
name: ai-dev-standards
description: Installs a layered AI development standards kit into a project repository — AGENTS.md entry file, .agents/ task modules, commit-msg hook, and CI self-check gate. Use when the user asks to set up AI coding conventions for a project, initialize or adopt AGENTS.md, apply the same standards across multiple repositories, or asks why a project has no AGENTS.md / .agents setup.
---

# AI 开发规范（安装器）

本文件位于 `<插件根>/skills/ai-dev-standards/SKILL.md`，模板与脚本在插件根目录（即本文件向上两级）。

完整的安装流程、验证方法与注意事项写在插件根的 `SKILL.md` 里。**先读它**：

```
Read <插件根>/SKILL.md
```

## 核心步骤

1. **确认目标项目根目录** —— 通常是有 `.git/` 的那一层。先 `ls AGENTS.md .agents/ 2>/dev/null` 确认是否已经装过。

2. **预览**（不要跳过）：

   ```bash
   bash <插件根>/install.sh <目标目录> --dry-run
   ```

   Windows 用 `<插件根>/install.ps1 -Target <目标目录> -DryRun`。

3. **正式安装**：

   ```bash
   bash <插件根>/install.sh <目标目录> --with-hooks --with-ci
   ```

   默认不覆盖已存在的文件，装过一次后再跑是幂等的。

4. **填 profile（不能跳过）**：`.agents/project-profile.md` 里全是「未定」。从项目本身读事实（`pom.xml`、`package.json`、`.github/workflows/`），能推断的直接填，推断不了的一次性列出来问用户。填写规范见 `<插件根>/references/profile-guide.md`。

5. **验证**：`cd <目标目录> && bash scripts/check.sh`，五项全绿才算装好。

## 模板清单

插件根目录下这些都是要装到目标项目的：

| 文件 | 去向 |
| --- | --- |
| `AGENTS.md` | 项目根 |
| `CLAUDE.md` | 项目根（一行 `@AGENTS.md`，给 Claude Code 用） |
| `.agents/*.md` | 项目的 `.agents/` |
| `scripts/check.sh` | 项目的 `scripts/` |
| `templates/githooks/commit-msg` `post-commit` | 项目的 `templates/githooks/`（`--with-hooks`） |
| `templates/github/check.yml` | 项目的 `.github/workflows/`（`--with-ci`） |

## 安装后提醒用户

模块不会自动加载。之后每次开工第一句要说：

> 先读 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。

不说这句，模型可能直接开始改代码。
