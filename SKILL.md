---
name: ai-dev-standards
description: Installs and maintains a layered AI development standards kit into a project repository — AGENTS.md entry, .agents/ task modules, commit-msg hook, CI self-check gate, and a self-check script. Use when the user asks to set up AI coding conventions for a project, initialize or adopt AGENTS.md, apply the same standards across multiple projects, or asks why a project has no AGENTS.md / .agents setup.
agent_created: true
---

# AI 开发规范（安装器）

## 用途

把一个可复制的分层规范体系装进任意项目：`AGENTS.md` 做入口（≤150 行）按任务分流，`.agents/` 放 10 个模块，配套 `commit-msg` 钩子与 CI 自检，把「规范」从文档里的红线变成会失败的提交与流水线。

规范化必须落地到项目根目录，才能被 Codex / Cursor / Claude Code 等工具读到——只在对话里讲规则是没用的。

## 获取

```bash
git clone https://github.com/999bug/ai-dev-standards.git
```

或在 GitHub 页面点 **Code → Download ZIP** 解压。不需要安装到任何全局目录，克隆下来就能用。

## 安装到目标项目

```bash
cd ai-dev-standards
./install.sh /path/to/your-project --dry-run          # 先预览
./install.sh /path/to/your-project --with-hooks --with-ci
```

Windows：

```powershell
.\install.ps1 -Target F:\code\my-project -DryRun
.\install.ps1 -Target F:\code\my-project -WithHooks -WithCi
```

| 选项 | 作用 |
| --- | --- |
| （无） | `AGENTS.md` + `CLAUDE.md` + `.agents/` 10 个模块 + `scripts/check.sh` |
| `--with-ci` | 加 `.github/workflows/check.yml`，每次 push / PR 自动自检 |
| `--with-hooks` | 加 git 钩子并设置 `core.hooksPath`，提交格式不对直接拒绝 |
| `--force` | 覆盖已存在文件（默认不覆盖，只跳过并报告） |
| `--dry-run` | 只预览，不落盘 |

**默认不覆盖已存在的文件**：目标项目可能已经改过 `AGENTS.md` 或某个模块，直接覆盖等于抹掉别人的工作。装过一次后再跑是幂等的（写入 0，全部跳过）。

## 安装后必做：填 profile

`.agents/project-profile.md` 里全是「未定」，必须逐项确认。

**这是整套体系能否生效的关键。** 一份没填完的 profile 比没有 profile 更危险：AI 会拿示例值当事实，用"看起来合理"的默认值代替项目实际情况，然后一路错下去。

填的时候：

1. 从项目里读事实，不要问已知的东西——`pom.xml` 的 `java.version`、`package.json` 的依赖、`.github/workflows/` 的触发方式
2. 能推断的直接填，推断不了的一次性列出来问
3. 优先补这四个：`build_command`、`test_command`、`git_user_email`（开源项目一律匿名）、`push_policy`

字段说明见 [`references/profile-guide.md`](references/profile-guide.md)。

## 验证

```bash
cd /path/to/your-project
bash scripts/check.sh
```

五项全绿才算装好：入口行数、明文邮箱、模块登记、交叉引用、代码块闭合。

## 安装后怎么用

模块**不会自动加载**。每次开工第一句要显式说：

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
├── .agents/                     10 个按任务加载的模块
│   ├── project-profile.md       项目事实（每个项目唯一要改的文件）
│   ├── commit.md · discipline.md · integration.md · legacy.md
│   └── lang-{java,python,vue}.md · release-{github,docker}.md
├── scripts/check.sh             五项自检
├── templates/
│   ├── githooks/                commit-msg · post-commit
│   └── github/check.yml         CI 模板
├── references/                  profile 填写 · 运作原理 · 扩展写法
├── install.sh / install.ps1     安装器
└── reviews/                     待审批的经验提取报告
```

## 常见问题

| 现象 | 原因 |
| --- | --- |
| `check.sh` 报"引用了不存在的文件" | 文档里写了不存在的 `.md` 文件名。改文件名或删引用，不要加白名单绕过 |
| `check.sh` 报"模块没有登记" | 新增了 `.agents/*.md` 但没在 AGENTS.md 分流表登记 |
| 提交被 `commit-msg` 拒绝 | 格式不符合 `.agents/commit.md`。类型是 `Doc` 不是 `DOC` |
| AI 还是不看规范 | 开场没说加载，见上面「安装后怎么用」 |
| 安装时大量文件被跳过 | 目标项目已装过。确认后用 `--force`，或只补缺失模块 |

## 许可

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，可自由复制、修改、商用，需保留署名。全文见 `LICENSE`。
