# 在 Claude Code 里使用这套规范

Claude Code 不读 `AGENTS.md`，只读 `CLAUDE.md`。所以仓库根目录放了一个 `CLAUDE.md`，内容只有一行：

```markdown
@AGENTS.md
```

这不是随手写的桥接，是 Claude Code 官方推荐的做法：让多个 agent 工具共用同一份指令，而不是各维护一份。

## 加载链

```
CLAUDE.md（1 行）
  └─ @AGENTS.md → AGENTS.md 全文被展开进上下文
       └─ 分流表告诉 Claude：改 Java 时去读 .agents/lang-java.md
            └─ Claude 用 Read 工具按需读，读一个算一次
```

关键点：**只有 `AGENTS.md` 被自动展开，`.agents/` 下的 10 个模块不会。**

这正是分层加载要的效果。如果 10 个模块也全展开，上下文会被 1000 多行占满，模型反而只记得住开头——和"一份 400 行万能文件"是同一个问题。

## 方式一：插件市场（推荐）

本仓库同时是一个 Claude Code 插件市场。`.claude-plugin/` 下有 `plugin.json`（插件清单）和 `marketplace.json`（市场清单），skill 在 `skills/ai-dev-standards/`。

```bash
# 添加市场，再装插件
claude plugin marketplace add 999bug/ai-dev-standards
claude plugin install ai-dev-standards@ai-dev-standards
```

Claude Code v2.1.292+ 可以合并成一条：

```bash
claude plugin install ai-dev-standards --marketplace 999bug/ai-dev-standards
```

更新：

```bash
claude plugin update ai-dev-standards@ai-dev-standards
```

**发布侧没有提交表单**：把 `marketplace.json` 推进仓库就算发布，谁 clone 到谁就能装。插件清单里的 `version` 决定用户何时收到更新——改了规范就要 bump 它，否则老用户不会自动更新。

如果想进 Anthropic 官方目录（`claude.ai` 和 Cowork 里能搜到），要从 `claude.ai/directory/manage` 提交，需要付费的 claude.ai 计划。官方市场 `claude-plugins-official` 不接受门户提交，只能通过 Anthropic 的合作伙伴渠道谈。

## 方式二：克隆后自己跑安装器

不想装插件的话，直接克隆仓库跑脚本，效果一样——装进项目的是同一批文件。

```bash
# 1. 装到项目
git clone https://github.com/999bug/ai-dev-standards.git
cd ai-dev-standards
./install.sh /path/to/your-project --with-hooks

# 2. 在项目里启动 Claude Code
cd /path/to/your-project
claude
```

`--with-hooks` 装的 `commit-msg` 是 git 层面的钩子，Claude Code 里跑 `git commit` 一样会被拦。它和 Claude Code 自己的 hooks（`.claude/settings.json`）是两套东西，互不冲突。

还有一种最直接的方式——把整个插件目录放进用户的 skills 目录，Claude Code 启动时会自动加载：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.claude/skills/ai-dev-standards
```

Windows 上是 `C:\Users\<用户名>\.claude\skills\ai-dev-standards`。这种方式不走市场，也不会自动更新，`git pull` 才拿到新版。

## 验证是否生效

在对话里问：

> 你现在遵守哪些规则？我改 Java 代码时你会读哪个文件？

正确的话应该能说出 `AGENTS.md` 的三档规则（红线 / 默认 / 建议），并提到 `.agents/lang-java.md`。说不出来说明 `CLAUDE.md` 没被读到——检查它是否在项目根目录、`@AGENTS.md` 是否被改写成了带反引号的字面量。

## 五个注意点

**1. 不要在新项目里跑 `/init`**

`/init` 会生成或覆盖 `CLAUDE.md`，把 `@AGENTS.md` 冲掉。要初始化别的配置就手动编辑这个文件。

**2. 导入递归最深 4 跳**

官方限制。本套只有 1 跳（CLAUDE.md → AGENTS.md），离上限很远。如果以后想在模块里再互相 import，记得算上这个深度。

**3. 反引号里的 `@` 不会触发导入**

导入解析会跳过行内代码和围栏代码块。所以文档里写 `@README`（带反引号）是字面量，写 @README（不带）才会真导入。别在 `CLAUDE.md` 里随手写带 `@` 的路径。

**4. 指向项目外的导入会弹审批框**

`CLAUDE.md` 里 `@` 的路径如果解析到工作目录之外（例如 `@~/.claude/my-rules.md`），Claude Code 第一次会弹窗要求批准，拒绝后不再出现。本套的 `@AGENTS.md` 在项目内，不会触发。

**5. `CLAUDE.local.md` 是另一回事**

用于放不应提交的个人偏好，加载方式和 `CLAUDE.md` 相同。想加临时规则放那里，记得把它加进 `.gitignore`，别改 `CLAUDE.md`。

## 两个可选增强

**如果 Claude 不主动读 `.agents/` 模块**，把 `CLAUDE.md` 改成：

```markdown
@AGENTS.md

> `.agents/` 下的模块按 AGENTS.md 第 3 节分流表按需读取，不要一次性全读。
```

原因：`AGENTS.md` 里的分流表是表格，模型未必会把它当成"现在就去读文件"的指令。加一句显式要求更稳。

**定期跑指令审计**（Claude Code v2.1.283+）：

```
/doctor prompt-audit
```

它会检查 `CLAUDE.md` 和 `AGENTS.md` 里有没有过期指令、引用了不存在的文件、互相矛盾的规则。装了规范之后跑一次，之后规则改多了也值得再跑。

## 和 WorkBuddy 的差别

| | Claude Code | WorkBuddy |
| --- | --- | --- |
| 入口文件 | `CLAUDE.md` | `AGENTS.md`（并通过 `CLAUDE.md` 兼容） |
| 是否自动读模块 | 否，靠分流表 + 模型主动 Read | 同 |
| 承诺完成后的门禁 | git hooks + CI | 同 |
| 额外机制 | `/doctor prompt-audit` 审计指令 | skill 可按需触发安装器 |

两边共用同一份 `AGENTS.md` 和 `.agents/`，不需要维护两套。改规则只改仓库，两个工具同时生效。
