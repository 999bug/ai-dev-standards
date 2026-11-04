---
name: ai-dev-standards
description: Installs a layered AI development standards kit into a project repository — AGENTS.md entry file, .agents/ task modules, commit-msg hook, and CI self-check gate. Use when the user asks to set up AI coding conventions for a project, initialize or adopt AGENTS.md, apply the same standards across multiple repositories, or asks why a project has no AGENTS.md / .agents setup.
---

# AI 开发规范（安装器）

本文件只是插件里的触发入口，**不要在这里找完整流程**：正文在插件根的 `SKILL.md`。

```
Read <插件根>/SKILL.md
```

`<插件根>` 就是本文件向上两级（`skills/ai-dev-standards/` → `skills/` → 插件根）。

## 最短路径

1. 确认目标项目根目录（通常是有 `.git/` 的那一层），先看有没有装过：

   ```bash
   ls <目标>/.agents/project-profile.md 2>/dev/null
   ```

   已经有 → 说明装过了，改用 `/ai-dev-standards:upgrade`，不要重装。

2. 预览，把会写哪些文件贴给用户，**等确认**：

   ```bash
   bash <插件根>/install.sh <目标> --dry-run
   ```

3. 安装（默认级别：规范文件 + `CLAUDE.md` + git 钩子）：

   ```bash
   bash <插件根>/install.sh <目标>
   ```

   Windows 无 `bash` 时用 `pwsh -NoProfile -File <插件根>/install.ps1 -Target <目标>`。

4. 填 `.agents/project-profile.md`：从项目里读事实，能推断的直接填，推断不了的一次性列出来问用户。字段说明见 `<插件根>/references/profile-guide.md`。

## 边界

- 不覆盖已有文件；升级只走 `--upgrade`，不加 `--force`。
- 不替用户决定装 CI / 自检脚本，除非他明确要。
- 装完不复述整个规范，只报「装了哪些 + 下一步填 profile」。
