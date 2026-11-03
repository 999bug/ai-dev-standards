# 在其他 agent 里使用

这套规范的文件是通用的，**同一个项目只需要装一次**。各工具的差别只在入口文件：有的直接读 `AGENTS.md`，有的要一个桥接文件。

先按 [手动安装](manual-install.md) 把规范装进项目，再回来看对应工具那一节。

## 总览

| 工具 | 入口文件 | 装完还要做什么 | 官方文档 |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` | 无（安装器已带上） | [插件文档](https://code.claude.com/docs/en/plugin-marketplaces) |
| WorkBuddy | `AGENTS.md` | 可作为 skill 安装 | [技能文档](https://codebuddy.cn/docs/workbuddy/From-Beginner-to-Expert-Guide/Function-Description/Skills-Market) |
| Codex | `AGENTS.md` | 无 | [AGENTS.md 文档](https://developers.openai.com/codex/guides/agents-md) |
| opencode | `AGENTS.md` | 无 | [Rules 文档](https://opencode.ai/docs/rules/) |
| Cursor | `AGENTS.md` | 无 | [Rules 文档](https://cursor.com/docs/rules) |
| GitHub Copilot | `AGENTS.md` | 无 | [自定义指令](https://docs.github.com/en/copilot/concepts/response-customization) |
| Gemini CLI | `GEMINI.md`（默认） | 加一个桥接文件 | [仓库与文档](https://github.com/google-gemini/gemini-cli) |

## WorkBuddy

两种用法，选一种。

### 方式一：作为 skill 安装（推荐）

整个仓库就是一个 skill（根目录有 `SKILL.md`）。放到用户级技能目录：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.workbuddy/skills/ai-dev-standards
```

Windows 是 `C:\Users\<用户名>\.workbuddy\skills\ai-dev-standards`。

只给某个团队/项目用，就放到项目级目录，随仓库提交：

```bash
git clone https://github.com/999bug/ai-dev-standards.git <项目>/.workbuddy/skills/ai-dev-standards
```

新开一段对话生效，然后说：

```text
给这个项目装 AI 开发规范
```

它会先预览、再安装，最后提醒你填 `.agents/project-profile.md`。

### 方式二：直接装文件

```bash
git clone https://github.com/999bug/ai-dev-standards.git
cd ai-dev-standards
./install.sh /path/to/your-project --with-ci
```

WorkBuddy 会把项目根的 `AGENTS.md` 作为项目规范读进上下文，不需要额外入口文件。

### 验证

新会话里问：

> 改这个项目的 Java 代码前，你会先读哪个文件？

应该回答 `.agents/lang-java.md`。答不出来说明 `AGENTS.md` 没被读到。

## Codex

Codex 原生读 `AGENTS.md`，装完直接能用。

它启动时会构建指令链，按优先级合并：

1. 全局：`~/.codex/AGENTS.md`（或个人目录下的 `AGENTS.override.md`）
2. 项目：从仓库根目录逐层往下到当前目录，每层最多一个 `AGENTS.md` 或 `AGENTS.override.md`
3. 越靠近当前目录的文件优先级越高；合并总大小受 `project_doc_max_bytes` 限制（默认 32 KiB）

所以：

- **不要把项目事实写进 `~/.codex/AGENTS.md`**。全局只放个人偏好（回复语言、提交习惯），项目事实留在 `.agents/project-profile.md`。
- 本套入口只有 150 行，离 32 KiB 上限很远，不需要调参数。
- 子目录需要额外规则时，在子目录放一个 `AGENTS.md` 补差异，不要重复根文件内容。

验证：`codex` 里问「按你读到的规范，改 Java 前先读哪个文件」，应回答 `.agents/lang-java.md`。

## opencode

opencode 原生读 `AGENTS.md`，没有时回退到 `CLAUDE.md`，所以装完不需要额外配置。

- 项目级：项目根的 `AGENTS.md`
- 全局级：`~/.config/opencode/AGENTS.md`（放个人偏好，不要放项目事实）
- 也可以启动时向上逐层查找

两个注意点：

1. **不要跑 `/init`**。它会扫描仓库并改写 `AGENTS.md`，容易把手工维护的入口冲掉。
2. 默认不需要 `instructions` 配置。`.agents/` 的模块本来就该按分流表按需读，一次性全塞进上下文会挤掉真正重要的内容。

验证：`opencode` 里问「这个项目的提交信息类型有哪些」，应回答 `NF/BF/IM/SC/CU/RF/Doc/OT/Tag`。

## Cursor

Cursor 支持项目根和子目录的 `AGENTS.md`，不需要转成 `.cursor/rules/*.mdc`。

- 一套项目规则只维护一个地方。用了 `AGENTS.md` 就别再往 `.cursor/rules/` 里抄一份，两边会漂移。
- `.cursor/rules/*.mdc` 适合需要 `globs` 按文件路径生效的规则；本项目靠 `AGENTS.md` 第 3 节的分流表决定读哪个模块，不需要 globs。

验证：在 Cursor 里问「改这个项目的 Vue 代码要读哪个模块」，应回答 `.agents/lang-vue.md`。

## GitHub Copilot

Copilot 把 `AGENTS.md`、`CLAUDE.md`、`GEMINI.md` 都识别为 agent instructions，装完即用。

- 仓库级自定义指令写在 `.github/copilot-instructions.md`，它和 `AGENTS.md` 是两套来源。团队主要用 Copilot 时才考虑补这一份，不要两边各写一份规则。
- 不同 IDE / 版本对 agent instructions 的支持不完全一致，遇到不生效先看官方支持矩阵。

验证：Copilot Chat 里问「这个项目的完成定义是什么」，应能说出构建通过、测试通过、本地实测、文档同步、工作区干净。

## Gemini CLI

Gemini CLI 默认读的是 `GEMINI.md`，不是 `AGENTS.md`。加一个一行的桥接文件即可：

```markdown
@AGENTS.md
```

Gemini CLI 支持 `@file.md` 导入，`AGENTS.md` 会被展开进上下文。原有 `GEMINI.md` 有内容的话，把这一行放在最前面，其余不动。

部分版本支持在设置里直接指定上下文文件名（`context.fileName` 可以传数组）。如果不想多一个文件，可以改成：

```json
{
  "context": { "fileName": ["AGENTS.md", "GEMINI.md"] }
}
```

字段名和可用性随版本变化，以你装的版本文档为准。两种方式选一种，不要同时用。

验证：`gemini` 里问「改 Java 前先读哪个文件」，应回答 `.agents/lang-java.md`。

## 通用注意点

**只认小写 `agent.md` 的工具**：改名或建软链，只留一份。

```bash
git mv AGENTS.md agent.md
ln -s agent.md AGENTS.md
```

**不要在多个工具里各存一份规则**。改规则只改项目里的 `AGENTS.md` 和 `.agents/`，所有工具一起生效；也不要把 `.agents/` 的内容复制到别的入口文件里。

**换工具不用重装**。已经装过的项目，新工具只要能读到入口文件就能用，`install.sh` 再跑也只会跳过。

## 验证清单

不管用哪个工具，新开会话问这三个问题，都能答对才算接上了：

1. 改 Java 代码前要先读哪个文件？→ `.agents/lang-java.md`
2. 提交信息的类型有哪些？→ `NF/BF/IM/SC/CU/RF/Doc/OT/Tag`
3. 这个项目的构建命令是什么？→ `.agents/project-profile.md` 里填的那个

第 3 题答的是示例值而不是你填的值，说明 profile 还没填完。
