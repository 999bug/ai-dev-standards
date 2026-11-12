---
name: ai-dev-standards
description: Installs a layered AI development standards kit once into a global directory and initializes each project with a pointer AGENTS.md, a one-line CLAUDE.md, and .agents/project-profile.md. Use when the user asks to set up AI coding conventions, adopt AGENTS.md across multiple projects, avoid reinstalling standards per repository, or asks why a project has no AGENTS.md / .agents setup.
---

# AI 开发规范（安装器）

本文件只是插件里的触发入口，**不要在这里找完整流程**：正文在插件根的 `SKILL.md`。

```
Read <插件根>/SKILL.md
```

`<插件根>` 就是本文件向上两级（`skills/ai-dev-standards/` → `skills/` → 插件根）。

## 最短路径

1. 先确认全局目录装没装：

   ```bash
   ls "${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}/AGENTS.md" 2>/dev/null
   ```

   没有 → 先装全局，加 `--dry-run` 给用户看再落盘：

   ```bash
   bash <插件根>/install.sh --global --dry-run
   bash <插件根>/install.sh --global
   ```

   有 → 跳过这步。项目侧不需要重复装规范。

2. 确认目标项目根目录（通常是有 `.git/` 的那一层），看初始化过没有：

   ```bash
   ls <目标>/.agents/project-profile.md 2>/dev/null
   ```

   有 → 说明初始化过了，只补 profile，不要再装。

3. 预览，把会写哪些文件贴给用户，**等确认**：

   ```bash
   bash <插件根>/install.sh <目标> --dry-run
   ```

   正常只有 3 个文件 + 2 个钩子。出现 `.agents/commit.md` 之类的模块说明是旧结构——停下，按打印的清单让用户自己清理。

4. 初始化：

   ```bash
   bash <插件根>/install.sh <目标>
   ```

   Windows 无 `bash` 时用 `pwsh -NoProfile -File <插件根>/install.ps1 -Target <目标>`。

5. 填 `.agents/project-profile.md`：从项目里读事实，能推断的直接填，推断不了的一次性列出来问用户。字段说明见 `<插件根>/references/profile-guide.md`。

## 边界

- 不覆盖已有文件；全局升级只走 `--global --upgrade`，不加 `--force`。
- 项目侧不需要升级，别去项目里跑 upgrade。
- 旧结构只报告、不删文件，清理命令交给用户执行。
- 装完不复述整个规范，只报「装了哪些 + 下一步填 profile」。
