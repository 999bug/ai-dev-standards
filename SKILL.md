---
name: ai-dev-standards
description: Installs and maintains a layered AI development standards kit into a project repository — AGENTS.md entry, .agents/ task modules, commit-msg hook, CI self-check gate, and a self-check script. Use when the user asks to set up AI coding conventions for a project, initialize or adopt AGENTS.md, apply the same standards across multiple projects, or asks why a project has no AGENTS.md / .agents setup.
---

# AI 开发规范（安装器）

## 用途

把一个可复制的分层规范体系装进任意项目：`AGENTS.md` 做入口（≤150 行）按任务分流，`.agents/` 放 11 个模块，配套 `commit-msg` 钩子与 CI 自检，把「规范」从文档里的红线变成会失败的提交与流水线。

规范化必须落地到项目根目录，才能被 Codex / Cursor / Claude Code 等工具读到——只在对话里讲规则是没用的。

## 获取

**Claude Code 插件（推荐）**：装插件后执行 `/ai-dev-standards:install`，详见 [`references/claude-code.md`](references/claude-code.md)。

**克隆后自己跑**：

```bash
git clone https://github.com/999bug/ai-dev-standards.git
```

或在 GitHub 页面点 **Code → Download ZIP** 解压。不需要安装到任何全局目录，克隆下来就能用。

## 安装到目标项目

```bash
cd ai-dev-standards
./install.sh /path/to/your-project --dry-run          # 先预览
./install.sh /path/to/your-project --with-ci
```

Windows：

```powershell
.\install.ps1 -Target F:\code\my-project -DryRun
.\install.ps1 -Target F:\code\my-project -WithCi
```

| 选项 | 作用 |
| --- | --- |
| （无） | `AGENTS.md` + `CLAUDE.md` + `.agents/` 11 个模块，并把 git 钩子装进 `.git/hooks/` |
| `--with-check` | 加 `scripts/check.sh`（七项自检） |
| `--with-ci` | 加 `.github/workflows/check.yml`，会自动带上 `check.sh` |
| `--no-hooks` | 不装 git 钩子（默认是装的） |
| `--shared-hooks` | 钩子装进项目里的 `.githooks/` 并设 `core.hooksPath`，跟仓库一起提交 |
| `--upgrade` | 升级已装的规范：没改过的更新，改过的另存为 `.new` |
| `--minimal` | 只装 `AGENTS.md` + `.agents/`，项目根只多 2 个条目 |
| `--force` | 覆盖已存在文件（默认不覆盖，只跳过并报告） |
| `--dry-run` | 只预览，不落盘 |

**默认不覆盖已存在的文件**：目标项目可能已经改过 `AGENTS.md` 或某个模块，直接覆盖等于抹掉别人的工作。装过一次后再跑不会重写任何东西（写入 0）。

**升级用 `--upgrade`，不要用 `--force`**：安装器在 `.agents/.standards-version` 里记了每个文件的 sha256，hash 对得上才覆盖，对不上就写成 `<文件>.new`，你的改动不会丢。

## 安装后必做：生成 profile

`.agents/project-profile.md` 是整套体系唯一需要按项目改的文件。**不要让人对着 28 个「未定」逐项查**，让 AI 跑一遍：

```
/ai-dev-standards:profile
```

`scripts/detect-profile.sh` 探测构建命令、语言版本、部署目标、提交风格、目录结构，然后只问四个必须由人决定的选择（仓库性质、提交风格、推送策略、是否现在验证），其余自动写入。

**这是整套体系能否生效的关键。** 一份没填完的 profile 比没有 profile 更危险：AI 会拿示例值当事实，用"看起来合理"的默认值代替项目实际情况，然后一路错下去。探测不到的字段留「未定」并列清单，不许猜。

手填或从 `/init` 产物出初稿也可以，映射表见 [`references/profile-guide.md`](references/profile-guide.md)。

## 验证

新会话里问一句，答得出就是生效了：

> 按你读到的规范回答：① 改 Java 代码前要先读哪个文件？② 提交信息的类型有哪些？

答案应是 `.agents/lang-java.md` 和 `NF/BF/IM/SC/CU/RF/Doc/OT/Tag`。

装了 `--with-check` 的话也可以跑自检：

```bash
cd /path/to/your-project
bash scripts/check.sh
```

七项全绿：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合、数字对账、插件清单。

## 安装后怎么用

模块**不会自动加载**。`AGENTS.md` 会被入口文件展开，`.agents/` 下的模块靠分流表按需读。

装了 Claude Code 插件时，会话启动会自动输出一行提醒（`hooks/session-context.sh`，只读不写），不需要再手动说开场白。没装插件的项目仍然要显式说：

> 先读 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。

三件事决定了这套体系的行为，详见 [`references/how-it-works.md`](references/how-it-works.md)：

1. **分层加载**：`AGENTS.md` 是唯一入口（≤150 行），按第 2、3 节的分流表决定加载哪个模块。400 行的"万能文件"会让模型只记住开头几条。
2. **规则分三档**：`【红线】` 无例外、`【默认】` 可被 profile 覆盖、`【建议】` 自行权衡。不分档等于没有优先级。
3. **门禁三层**：提交时 `commit-msg` 拦格式，提交前 `check.sh` 拦断链，push 后 CI 拦历史邮箱。

## 扩展

加语言或平台模块时，新文件必须在 `AGENTS.md` 第 2、3 节的分流表登记，否则永远不会被加载——`scripts/check.sh` 会拦住这种疏漏。写法见 [`references/extending.md`](references/extending.md)。

## 目录结构

```
ai-dev-standards/
├── AGENTS.md                    入口（装到项目的根目录）
├── CLAUDE.md                    Claude Code 的兼容入口
├── .agents/                     11 个按任务加载的模块
│   ├── project-profile.md       项目事实（每个项目唯一要改的文件）
│   ├── commit.md · discipline.md · integration.md · legacy.md · task-workflow.md
│   └── lang-{java,python,vue}.md · release-{github,docker}.md
├── .claude-plugin/              插件与市场清单（版本号唯一来源）
├── commands/                    插件命令：install · upgrade
├── hooks/                       SessionStart 上下文提醒（只读）
├── scripts/check.sh             七项自检
├── scripts/release.sh           改版本 + 补 CHANGELOG + 跑自检 + 打 tag
├── templates/
│   ├── githooks/                commit-msg · post-commit
│   └── github/check.yml         CI 模板
├── references/                  profile 填写 · 运作原理 · 扩展写法 · Claude Code 用法
├── install.sh / install.ps1     安装器
└── reviews/                     待审批的经验提取报告
```

## 常见问题

| 现象 | 原因 |
| --- | --- |
| `check.sh` 报"引用了不存在的文件" | 文档里写了不存在的 `.md` 文件名。改文件名或删引用，不要加白名单绕过 |
| `check.sh` 报"模块没有登记" | 新增了 `.agents/*.md` 但没在 AGENTS.md 分流表登记 |
| `check.sh` 报"文档里的数字过期" | 「N 个模块」「写入 N 个文件」和仓库实际不一致，按提示改成实际值 |
| 提交被 `commit-msg` 拒绝 | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC` |
| AI 还是不看规范 | 开场没说加载，见上面「安装后怎么用」 |
| 安装时大量文件被跳过 | 目标项目已装过。用 `--upgrade` 更新，或 `--force` 强制覆盖 |

## 许可

文档 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，脚本 MIT，见 `LICENSE` 与 `LICENSE-MIT`。
