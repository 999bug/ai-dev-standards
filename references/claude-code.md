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

关键点：**只有 `AGENTS.md` 被自动展开，`.agents/` 下的 14 个模块不会。**

这正是分层加载要的效果。如果 14 个模块也全展开，上下文会被 1000 多行占满，模型反而只记得住开头——和"一份 400 行万能文件"是同一个问题。

## 方式一：插件市场（推荐）

本仓库同时是一个 Claude Code 插件市场。`.claude-plugin/` 下有 `plugin.json`（插件清单）和 `marketplace.json`（市场清单），skill 在 `skills/ai-dev-standards/`，命令在 `commands/`。

```bash
# 添加市场，再装插件
claude plugin marketplace add 999bug/ai-dev-standards
claude plugin install ai-dev-standards@ai-dev-standards --scope local
```

Claude Code v2.1.292+ 可以合并成一条：

```bash
claude plugin install ai-dev-standards --marketplace 999bug/ai-dev-standards
```

装完**退出会话再重进**，然后在项目里执行：

```text
/ai-dev-standards:install
```

命令分两步：先确认全局目录（`~/.ai-dev-standards/`）装了没有、是不是最新，再初始化当前项目——写 `AGENTS.md` 指针、`CLAUDE.md`、`.agents/project-profile.md`，钩子进 `.git/hooks/`。两步都先 `--dry-run` 给你看要写什么。

更新规范要两步：先升插件，再升规范本体。

```bash
claude plugin update ai-dev-standards@ai-dev-standards
# 退出会话重进，新命令才会加载；第三方市场默认不开自动更新
```

```text
/ai-dev-standards:upgrade
```

`claude plugin update` 只把新版命令、安装器和模板复制进插件缓存，**不会**碰 `~/.ai-dev-standards/`——规范本体是安装器第一次运行时写进去的产物，而 Claude Code 没有 post-install 钩子。顺序反了会拿旧模板比对、判定「内容一致」全部跳过。

只升全局目录。项目侧没有模块副本，不需要升级。你改过的全局模块会先备份到 `.backup/<时间戳>/` 再覆盖，**不要用 `--force` 代替**。

全局目录若就是 clone 的仓库（`source=git` / `source=repo`），`git -C ~/.ai-dev-standards pull --ff-only` 即可更新规范本体，不必跑 upgrade 命令。

### 发布侧：改版本 → 打 tag

没有提交表单：把 `marketplace.json` 推进仓库就算发布。插件清单里的 `version` 决定用户何时收到更新——内容变了不 bump，老用户永远拿到旧版。

```bash
bash scripts/release.sh 1.6.0
```

这条命令会改 `plugin.json` 的版本、在 `CHANGELOG.md` 顶部插入待填条目、跑 `scripts/check.sh`，最后打印 `claude plugin tag` 的命令。tag 由你手动打，脚本不碰 git。

`claude plugin tag` 是官方命令，会校验 `plugin.json` 与 marketplace 条目里的版本一致，再打 `{name}--v{version}` 的 tag。`check.sh` 第 7 项会在版本与 CHANGELOG 不一致时直接失败，所以忘了 bump 在本地就会被拦。

完整流程（目录结构、市场清单字段、别人怎么找到、装不上的排错）见 [`../docs/plugin-publishing.md`](../docs/plugin-publishing.md)。

如果想进 Anthropic 官方目录（`claude.ai` 和 Cowork 里能搜到），要从 `claude.ai/directory/manage` 提交，需要付费的 claude.ai 计划。官方市场 `claude-plugins-official` 不接受门户提交，只能通过 Anthropic 的合作伙伴渠道谈。目录要求一个 512–2048 px 的方形 PNG 图标，放在 `.claude-plugin/icon.png`。

## 方式二：克隆后自己跑安装器

不想装插件的话，直接克隆仓库跑脚本，效果一样。

```bash
git clone https://github.com/999bug/ai-dev-standards.git

# 1. 全局装一次（所有项目共用）
./ai-dev-standards/install.sh --global

# 2. 项目初始化一次
./ai-dev-standards/install.sh /path/to/your-project

# 3. 在项目里启动 Claude Code
cd /path/to/your-project
claude
```

装进 `.git/hooks/` 的 `commit-msg` 是 git 层面的钩子，Claude Code 里跑 `git commit` 一样会被拦。它和 Claude Code 自己的 hooks（`.claude/settings.json`）是两套东西，互不冲突。

完整步骤见 [`../docs/manual-install.md`](../docs/manual-install.md)。

## 方式三：放进 skills 目录

把整个仓库放进用户的 skills 目录，Claude Code 启动时会自动加载：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.claude/skills/ai-dev-standards
```

Windows 上是 `C:\Users\<用户名>\.claude\skills\ai-dev-standards`。这种方式不走市场，也不会自动更新，`git pull` 才拿到新版。

## 插件自带的 SessionStart 提醒（只读）

装完插件后，每次在 git 仓库里开新会话，会看到两三行，按接入状态分三种：

```text
# 本项目已接入
[ai-dev-standards] 本仓库已接入（规范在 ~/.ai-dev-standards，3 处「未定」待确认）。
  一键填充：/ai-dev-standards:profile（探测项目事实，只问几个必须人决定的选择）
  改代码前先读 ~/.ai-dev-standards/AGENTS.md，再按第 3 节分流表加载模块，不要一次性全读。

# 全局装了，但本项目还没初始化
[ai-dev-standards] 全局规范已装（~/.ai-dev-standards），但本仓库还没初始化。
  初始化：/ai-dev-standards:install（只写 3 个文件 + 2 个钩子）

# 全局也没装
[ai-dev-standards] 还没装这套规范。
  安装：/ai-dev-standards:install（全局装一次，之后每个项目初始化一次）
```

### 原理

插件根目录有 `hooks/hooks.json`，声明了一个 `SessionStart` hook：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-context.sh\" || true",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

`session-context.sh` 只读不写，按顺序判断：

1. 当前是不是 git 仓库 —— 不是就退出（临时目录、家目录不该被塞提示）
2. 有 `.agents/project-profile.md` —— 已接入，报还剩几处「未定」，给出全局规范路径
3. 没有 profile，但全局目录存在 —— 提示这个仓库还没初始化，给出 install 命令
4. 全局目录也没有 —— 提示先装全局

stdout 会进入 Claude 的上下文，所以这条提醒是真的会被读到的，不需要你每次手动说开场白。

### 为什么不自动安装

1.1.0 到 1.4.0 的版本把安装挂在这个 hook 上：会话启动时自动写入整套文件（15 个），包括两个会改变提交行为的 git 钩子。这有三个问题：

| 问题 | 说明 |
| --- | --- |
| 违背规范自己的红线 | `AGENTS.md` 第一条是「先诊断、后动手」。工具自己不遵守，规范就没有说服力 |
| 作用域失控 | 插件默认装成 `user` scope，于是每个 clone 下来看一眼的仓库都会被写 |
| 不可审计 | 用户看不到会写什么，也来不及拒绝 |

现在安装是显式动作：`/ai-dev-standards:install`。这和 1.4.0 的"自动安装"相比只多一步，但它把决定权还给了用户。

### 三个容易误解的点

**① 需要 1.5.0 及以上。** 1.4.0 及更早装的还是自动安装行为，`/ai-dev-standards:install` 命令也不存在。确认版本：

```bash
claude plugin list
```

**② 装完插件不会立刻生效。** `plugin install` 只把文件复制到 `~/.claude/plugins/cache/`，不执行任何脚本——Claude Code 没有 post-install 钩子。必须退出会话再重进，命令和 hook 才会加载。

**③ 项目已有 `CLAUDE.md` 或 `AGENTS.md` 时要手动接一下。** 安装器不覆盖已有文件，会跳过并提示。但那样规范读不到：`CLAUDE.md` 要在第一行加 `@AGENTS.md`；`AGENTS.md` 要在开头加一段指向全局目录的说明（安装器会把该写什么打出来）。

### 开关

```bash
# profile 填满后不再提醒（仍有「未定」时保留告警）
AI_DEV_STANDARDS_QUIET=1 claude

# 本次会话完全静默
AI_DEV_STANDARDS_SKIP=1 claude
```

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

**4. 读项目外的文件会弹审批框**

`CLAUDE.md` 里 `@` 的路径如果解析到工作目录之外（例如 `@~/.claude/my-rules.md`），Claude Code 第一次会弹窗要求批准，拒绝后不再出现。

新结构下项目 `CLAUDE.md` 只导入项目内的 `AGENTS.md`，不触发这个框。但指针会让模型用 Read 工具去读 `~/.ai-dev-standards/AGENTS.md`——这属于读工作区外文件，**第一次也会弹一次审批**。批准一次即可，同一路径之后不再问。如果用户拒绝了，模型读不到规范，只剩指针里那几行约束。

**5. `CLAUDE.local.md` 是另一回事**

用于放不应提交的个人偏好，加载方式和 `CLAUDE.md` 相同。想加临时规则放那里，记得把它加进 `.gitignore`，别改 `CLAUDE.md`。

## 两个可选增强

**如果 Claude 不主动读全局模块**，在项目 `AGENTS.md` 末尾加一句：

> 按全局 AGENTS.md 第 3 节分流表按需读取模块，不要一次性全读；模块与全局 AGENTS.md 同目录。

原因：分流表是表格，模型未必会把它当成"现在就去读文件"的指令。加一句显式要求更稳。

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
| 承诺完成后的门禁 | 项目内 git hooks + 规范仓库自检 | 同 |
| 额外机制 | 插件命令安装 + SessionStart 上下文提醒 | skill 可按需触发安装器 |

两边读同一份全局 `AGENTS.md` 和 `.agents/`，不需要维护两套。改规则只改全局目录，两个工具同时生效。
