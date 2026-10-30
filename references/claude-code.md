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

## 使用步骤

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
