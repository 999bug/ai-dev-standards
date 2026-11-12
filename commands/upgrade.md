---
description: 升级全局 AI 开发规范（项目侧不需要升级）
---

# 升级 AI 开发规范

项目里只有指针和 `project-profile.md`，内容固定，**不需要升级**。要升的只有全局目录。

> 路径解析：`${CLAUDE_PLUGIN_ROOT}` 由插件注入。万一它为空，先跑
> `ls ~/.claude/plugins/cache/ai-dev-standards/` 找到版本目录，用那个绝对路径代替，
> 不要凭猜写路径。

## 1. 看现状

```bash
GH="${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}"
grep -E '^(version|source)=' "$GH/.standards-version" 2>/dev/null
```

| 结果 | 含义 |
| --- | --- |
| 清单不存在 | 全局还没装过。改用 `/ai-dev-standards:install` |
| `version` 与插件版本一致 | 已经最新，不用升 |
| `source=git` | 全局目录是 clone 的仓库，可以 `git -C "$GH" pull --ff-only` 后再跑一次安装刷新清单 |
| `source=repo` | 全局目录就是插件仓库本身，升级跟随插件更新，跑安装刷新清单即可 |

## 2. 预览

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --global --upgrade --dry-run
```

Windows 没有 `bash` 时用：

```
pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/install.ps1" -Global -Upgrade -DryRun
```

三类结果分别解释给用户：

| 输出 | 含义 |
| --- | --- |
| 更新 | 装完之后没被改过，会直接覆盖成新版 |
| 跳过 | 内容和新版已经一致 |
| 你改过 X → 备份到 `.backup/<时间戳>/` 后覆盖 | 全局模块被本地改过，旧版先备份再覆盖 |

## 3. 执行

```bash
bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --global --upgrade
```

**不要顺手加 `--force`**：它跳过「是否被改过」的判断，代价一样但少了确认这一步。

## 4. 处理「用户改过全局模块」的情况

如果汇总里出现备份提示：

1. 告诉用户旧版在 `$GH/.backup/<时间戳>/`，可以随时取回。
2. 问一句他想保留什么。真想长期定制的话，**不要改全局模块**——
   把偏离写进项目的 `.agents/project-profile.md` 第 8 节 `overrides`，
   全局模块保持原样，下次升级就不会冲突。

## 5. 收尾

- 强调：升级只影响全局目录，**不需要去任何项目重跑 install**。
- 说清这次升了哪些文件、备份了几个。
