---
description: 全局装一次 AI 开发规范，并初始化当前项目（项目侧只写 3 个文件 + 2 个钩子）
argument-hint: "[目标项目目录，默认当前目录]"
---

# 安装 AI 开发规范

目标项目：`$ARGUMENTS`
没给参数就用当前工作目录。

> 路径解析：`${CLAUDE_PLUGIN_ROOT}` 由插件注入。万一它为空，先跑
> `ls ~/.claude/plugins/cache/ai-dev-standards/` 找到版本目录，用那个绝对路径代替，
> 不要凭猜写路径。

这套规范分两层：**规范本体在全局目录**（默认 `~/.ai-dev-standards`，可用
`AI_DEV_STANDARDS_HOME` 覆盖），**项目里只有指针和项目档案**。

所以这个命令做两件事，顺序不能反：先确保全局已装，再初始化项目。

## 1. 先看全局装没装

```bash
GH="${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}"
printf '%s\n' "$GH"
grep -E '^(version|source)=' "$GH/.standards-version" 2>/dev/null
```

| 结果 | 含义 |
| --- | --- |
| 目录不存在 | 第 2 步会装 |
| `version` 低于插件版本 | 第 2 步会更新 |
| `version` 与插件版本一致 | 跳过第 2 步，直接进第 3 步 |

插件当前版本：`grep '"version"' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"`。

## 2. 装 / 更新全局（幂等）

先预览：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --global --dry-run
```

Windows 没有 `bash` 时：

```
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/install.ps1" -Global -DryRun
```

把预览结果贴给用户：会写哪些文件（正常是 22 个）、跳过哪些。

**第一次装全局必须先让用户确认**——这会往家目录写文件。确认后去掉 `--dry-run` 执行。
之后每次都是幂等的：全是最新时输出「写入 0 个文件」。

如果 `source=git`（全局目录是 clone 的仓库），也可以让用户先 `git -C "$GH" pull --ff-only`
再跑安装刷新清单。

## 3. 初始化项目

```bash
git -C "<目标>" rev-parse --show-toplevel
```

输出的是仓库根就以它为准；不是 git 仓库就用原目录（钩子会跳过，其余照做）。

先预览：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" "<目标>" --dry-run
```

正常只该看到三样东西：

- `.agents/project-profile.md`（并按探测结果填初稿）
- `AGENTS.md`（指向全局规范的指针）
- `CLAUDE.md`（一行 `@AGENTS.md`）

外加 `.git/hooks/` 下两个钩子。**如果预览里出现 `.agents/commit.md` 之类的模块，
说明这是旧结构，不要继续**，见下一节。

用户确认后去掉 `--dry-run` 执行。

## 4. 三种特殊情况，别硬装

| 预览里看到 | 含义 | 怎么做 |
| --- | --- | --- |
| 列出 `.agents/commit.md` 等模块 | 这是 1.12.x 及更早的旧结构（规范副本在项目里） | **停下**。安装器只打印清理清单和命令，不会删任何文件。把清单原样贴给用户，等他清理完再重跑 |
| `! 已有自定义 AGENTS.md，未覆盖` | 项目原来有自己的 AGENTS.md | 不覆盖。告诉用户在文件开头加一段，指明规范在全局目录 |
| `! 已有自定义 CLAUDE.md，未覆盖` | 项目原来有自己的 CLAUDE.md | 不覆盖。告诉用户在**第一行**加 `@AGENTS.md` |

旧结构清理完，重跑一次本命令即可，profile 不会丢。

## 5. 报告，然后补 profile

1. 贴安装器最后几行汇总（写入 / 更新 / 跳过 + 钩子数）。
2. 说明一句关键事实：**项目侧只有 3 个文件，以后规范升级只跑全局，这个项目不用再动**。
3. **不要问「要不要帮你填 profile」**：安装器已经按探测结果写了初稿，读
   `commands/profile.md`，只补 `type` / `visibility` / `verify_*` 这些只有人能决定的。

唯一例外：用户明确说"先别填"，告诉他随时可以跑 `/ai-dev-standards:profile`。

## 6. 钩子的一次性提醒

钩子装在 `.git/hooks/`，不进版本控制，团队其他人 clone 后要各自初始化一次。

项目如果设过 `core.hooksPath`，git 会完全忽略 `.git/hooks/`，安装器会警告——
按提示 `git config --unset core.hooksPath`，否则钩子装了也不生效。
