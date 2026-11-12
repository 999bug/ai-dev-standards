---
name: ai-dev-standards
description: Installs a layered AI development standards kit once into a global directory (~/.ai-dev-standards) and initializes each project with only a pointer AGENTS.md, a one-line CLAUDE.md, and .agents/project-profile.md. Use when the user asks to set up AI coding conventions, adopt AGENTS.md across multiple projects, avoid reinstalling standards per repository, or asks why a project has no AGENTS.md / .agents setup.
---

# AI 开发规范（安装器）

## 用途

一套分层规范：`AGENTS.md` 做入口（≤150 行）按任务分流，`.agents/` 放 14 个模块，配套 `commit-msg` 钩子与自检脚本，把「规范」从文档里的红线变成会失败的提交。

**装法分两层，别装反：**

- **全局一次**：规范本体、模块、钩子模板、脚本都放 `~/.ai-dev-standards/`（`AI_DEV_STANDARDS_HOME` 可改）。所有项目共用，升级也只升这一处。
- **每个项目一次**：只写 `AGENTS.md`（指针）、`CLAUDE.md`（一行）、`.agents/project-profile.md`，外加 `.git/hooks/` 下两个钩子。

项目里必须有入口文件，否则 Codex / Cursor / Claude Code 读不到——这是工具约定，绕不过去。但入口只是一个二十行的指针，真正的内容在全局目录。

## 获取

**Claude Code 插件（推荐）**：装插件后执行 `/ai-dev-standards:install`，详见 [`references/claude-code.md`](references/claude-code.md)。

**克隆后自己跑**：

```bash
git clone https://github.com/999bug/ai-dev-standards.git
```

也可以直接 clone 到全局位置，省掉复制：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.ai-dev-standards
```

## 全局安装（先做这个）

```bash
cd ai-dev-standards
./install.sh --global --dry-run     # 先预览：22 个文件
./install.sh --global
```

Windows：

```powershell
.\install.ps1 -Global -DryRun
.\install.ps1 -Global
```

幂等：已是最新时输出「写入 0 个文件」。你改过全局模块的话，`--upgrade` 会先备份到 `.backup/<时间戳>/` 再覆盖。

## 项目初始化（每个项目一次）

```bash
./install.sh /path/to/your-project --dry-run    # 正常只有 3 个文件 + 2 个钩子
./install.sh /path/to/your-project
```

| 选项 | 作用 |
| --- | --- |
| （无） | 写 `AGENTS.md` 指针、`CLAUDE.md`、`.agents/project-profile.md`，钩子进 `.git/hooks/` |
| `--no-hooks` | 不装 git 钩子 |
| `--force` | 覆盖已存在的文件（默认不覆盖，只跳过并报告） |
| `--dry-run` | 只预览，不落盘 |

**默认不覆盖已有文件。** 项目原来就有 `AGENTS.md` 或 `CLAUDE.md` 时，安装器只提示、不落盘——那可能是人家自己的规范，覆盖等于抹掉别人的工作。

**旧结构（1.12.x 及更早）只报告不删。** 预览里如果出现 `.agents/commit.md` 之类的模块副本，说明这个项目装的是老版本。安装器会打印清理清单和命令然后退出，**不会删任何文件**；用户清理完再重跑一次，`project-profile.md` 不受影响。

**项目侧不需要升级。** 那里只有指针和 profile，内容固定。`--upgrade` 只会作用于全局目录。

## 安装后必做：补齐 profile

`.agents/project-profile.md` 是整套体系唯一需要按项目改的文件。**首次初始化时已经按探测结果填好初稿**（project、语言、构建命令、提交风格等），只剩 `type` / `visibility` / `verify_*` 需要人确认。

```
/ai-dev-standards:profile
```

它只问四个必须由人决定的选择（仓库性质、提交风格、推送策略、是否现在验证），其余自动写入。

**这是整套体系能否生效的关键。** 一份没填完的 profile 比没有 profile 更危险：AI 会拿示例值当事实，用"看起来合理"的默认值代替项目实际情况，然后一路错下去。探测不到的字段留「未定」并列清单，不许猜。

**升级不碰这个文件**——项目事实和手写结论不该被模板更新覆盖。映射表见 [`references/profile-guide.md`](references/profile-guide.md)。

## 验证

新会话里问一句，答得出就是生效了：

> 按你读到的规范回答：① 改 Java 代码前要先读哪个文件？② 提交信息的类型有哪些？

答案应是 `lang-java.md` 和 `NF/BF/IM/SC/CU/RF/Doc/OT/Tag`。答不出来先查全局目录可不可读：

```bash
cat "${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}/AGENTS.md" | head -3
```

改规范仓库本身时跑自检：

```bash
bash scripts/check.sh
```

七项全绿：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合、数字对账、插件清单。

## 安装后怎么用

模块**不会自动加载**。项目 `AGENTS.md` 指针会把模型引到全局 `AGENTS.md`，再按分流表按需读模块。

装了 Claude Code 插件时，会话启动会自动输出一行状态（`hooks/session-context.sh`，只读不写）。没装插件的项目仍然要显式说：

> 先读全局的 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。

三件事决定了这套体系的行为，详见 [`references/how-it-works.md`](references/how-it-works.md)：

1. **分层加载**：`AGENTS.md` 是唯一入口（≤150 行），按第 2、3 节的分流表决定加载哪个模块。400 行的"万能文件"会让模型只记住开头几条。
2. **规则分三档**：`【红线】` 无例外、`【默认】` 可被 profile 覆盖、`【建议】` 自行权衡。不分档等于没有优先级。
3. **门禁两层**：提交时 `commit-msg` 拦格式，改规范时 `check.sh` 拦断链与失效引用。

## 扩展

加语言或平台模块时，新文件必须在 `AGENTS.md` 第 2、3 节的分流表登记，否则永远不会被加载——`scripts/check.sh` 会拦住这种疏漏。写法见 [`references/extending.md`](references/extending.md)。

全局安装会自动带上所有模块，不需要改安装器；但项目侧不会因此多出文件。

## 目录结构

```
ai-dev-standards/
├── AGENTS.md                    入口（装到全局目录）
├── CLAUDE.md                    Claude Code 的兼容入口（仓库自用）
├── .agents/                     14 个按任务加载的模块
│   ├── project-profile.md       项目事实模板（初始化时复制进项目）
│   ├── commit.md · discipline.md · integration.md · legacy.md · task-workflow.md
│   └── lang-{java,android,python,vue}.md · release-{android,github,docker,gitee}.md
├── .claude-plugin/              插件与市场清单（版本号唯一来源）
├── commands/                    插件命令：install · upgrade
├── hooks/                       SessionStart 上下文提醒（只读）
├── scripts/check.sh             七项自检
├── scripts/detect-profile.sh    只读探测，给 profile 填初稿
├── scripts/release.sh           改版本 + 补 CHANGELOG + 跑自检
├── templates/
│   ├── githooks/                commit-msg · post-commit（初始化时复制进项目）
│   ├── project/                 项目侧的 AGENTS.md 指针与 CLAUDE.md 模板
│   └── github/check.yml         CI 模板（留给要自己搭门禁的项目）
├── references/                  profile 填写 · 运作原理 · 扩展写法 · Claude Code 用法 · Gitee 发布同步手册
├── install.sh / install.ps1     安装器
└── reviews/                     待审批的经验提取报告
```

## 常见问题

| 现象 | 原因 |
| --- | --- |
| 初始化时报「全局规范未安装」 | 先跑 `--global`。命令层会自动串起来，手动跑脚本要分两步 |
| 初始化时列出 `.agents/commit.md` 等模块 | 旧结构。安装器只报告不删，按打印的命令清理后重跑 |
| `check.sh` 报"引用了不存在的文件" | 文档里写了不存在的 `.md` 文件名。改文件名或删引用，不要加白名单绕过 |
| `check.sh` 报"模块没有登记" | 新增了 `.agents/*.md` 但没在 AGENTS.md 分流表登记 |
| `check.sh` 报"文档里的数字过期" | 「N 个模块」「全局 N 个文件」和仓库实际不一致，按提示改成实际值 |
| 提交被 `commit-msg` 拒绝 | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC` |
| AI 还是不看规范 | 指针没被读到。查全局目录是否可读、工具是否允许读工作区外文件 |
| 同事 clone 后读不到规范 | 规范跟着机器走。让对方也跑一次 `--global` |

## 许可

文档 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，脚本 MIT，见 `LICENSE` 与 `LICENSE-MIT`。
