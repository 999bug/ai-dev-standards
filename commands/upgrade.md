---
description: 把项目里已装的 AI 开发规范升级到插件当前版本，保留本地改动
argument-hint: "[目标项目目录，默认当前目录]"
---

# 升级 AI 开发规范

目标项目：`$ARGUMENTS`
没给参数就用当前工作目录。

## 1. 先看现状

```bash
grep '^version=' "<目标>/.agents/.standards-version"
```

- 文件不存在：说明是旧版安装器装的（或没装）。告诉用户这一版起才有升级清单，
  让他先跑 `/ai-dev-standards:install` 补齐清单，或直接用 `--force` 覆盖。
- 当前版本与插件版本一致：告诉用户已经是最新，不必升级。

## 2. 预览

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" "<目标>" --upgrade --dry-run
```

Windows 无 `bash` 时用 `pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/install.ps1" -Target "<目标>" -Upgrade -DryRun`。

预览里的三类结果要分别解释给用户：

| 输出 | 含义 |
| --- | --- |
| 更新 | 安装后没被改过，会覆盖成新版 |
| 跳过 | 内容已经和新版一致 |
| 冲突 → `.new` | 本地改过，新版另存为 `<文件>.new`，不动原文件 |

## 3. 执行

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" "<目标>" --upgrade
```

不要顺手加 `--force`：那会连本地改动一起覆盖掉。

## 4. 处理冲突

如果有 `.new` 文件，逐个和原文件 diff，把新版里需要的部分合并进去，然后删掉 `.new`。
合并完提醒用户：`.agents/.standards-version` 里记录的是**上次安装时**的 hash，
所以下次升级前最好先跑一次 `install.sh --upgrade` 让清单对上，或手动核对。

## 5. 收尾

告诉用户这次升级了哪些文件、哪些留了 `.new`、还有哪些没动。
