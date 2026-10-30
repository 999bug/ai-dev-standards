# AI 开发规范

一套可复制的规范文件，装进任意新项目根目录即生效。目标是**让 AI 按你的意图开发**，而不是按它的默认习惯。

`AGENTS.md` 做入口（≤150 行）按任务分流，`.agents/` 放 10 个模块；配套 `commit-msg` 钩子与 CI 自检，把「规范」从文档里的红线变成会失败的提交与流水线。

## 安装

克隆本仓库，跑一条命令即可装到任意项目：

```bash
git clone https://github.com/999bug/ai-dev-standards.git
cd ai-dev-standards

./install.sh /path/to/your-project --dry-run       # 先看会写哪些文件
./install.sh /path/to/your-project --with-hooks --with-ci
```

Windows 用同目录下的 `install.ps1`（参数见下表，写法为 `-Target` / `-WithHooks` / `-WithCi` / `-Force` / `-DryRun`）。

| 选项 | 作用 |
| --- | --- |
| （无） | `AGENTS.md` + `CLAUDE.md` + `.agents/` 10 个模块 + `scripts/check.sh` |
| `--with-ci` | 加 `.github/workflows/check.yml`，每次 push / PR 自动自检 |
| `--with-hooks` | 加 git 钩子并设置 `core.hooksPath`，提交格式不对直接拒绝 |
| `--force` | 覆盖已存在文件 |
| `--dry-run` | 只预览，不落盘 |

**默认不覆盖已存在的文件**，装过一次后再跑是幂等的（写入 0，全部跳过）。要覆盖必须显式加 `--force`——目标项目可能已经改过某个模块，盲目覆盖等于抹掉别人的工作。

## 装完必做：填 profile

`.agents/project-profile.md` 里全是「未定」，逐项确认。

**这是整套体系能否生效的关键。** 一份没填完的 profile 比没有 profile 更危险：AI 会拿示例值当事实，用"看起来合理"的默认值代替项目实际情况，然后一路错下去。

字段说明与常见错误见 [`references/profile-guide.md`](references/profile-guide.md)。

验证安装：

```bash
cd <project> && bash scripts/check.sh
```

五项全绿才算装好。

## 会话开场模板

模块不会自动加载，全靠开场这一句把分流表的开关打开。三种场景，挑一条改改就用：

```text
# 新项目 / 首次进入
先读 AGENTS.md 和 .agents/project-profile.md，再按分流表加载本项目需要的模块。
profile 里如果还有未定项，先列出来问我，不要猜。

# 接手老项目
先读 AGENTS.md 和 .agents/project-profile.md，再读 .agents/legacy.md。
这是老项目，先按 legacy.md 第 0 节跑一遍体检，把结论报给我再动手。

# 只修一个 bug
先读 AGENTS.md，按分流表加载对应语言模块。
本次只修这个 bug，不顺手重构、不改样式、不升依赖；发现别的问题先报告。
```

## 作为 WorkBuddy skill 使用

仓库根目录有 `SKILL.md`，所以整个仓库就是一个 skill。安装到本地 skills 目录后，在任意项目里说「给这个项目装 AI 开发规范」即可自动执行：

```bash
git clone https://github.com/999bug/ai-dev-standards.git ~/.workbuddy/skills/ai-dev-standards
```

Windows 上是 `C:\Users\<用户名>\.workbuddy\skills\ai-dev-standards`。装完重启 WorkBuddy 生效。

两种用法共用同一份模板，不需要维护两份。

## 手动装钩子（可选）

`install.sh --with-hooks` 会自动装。手工装的话：

```bash
cd <project> && git config core.hooksPath <本仓库>/templates/githooks
```

或者复制进项目，让配置跟着仓库走：

```bash
mkdir -p <project>/templates/githooks
cp <本仓库>/templates/githooks/* <project>/templates/githooks/
chmod +x <project>/templates/githooks/*
cd <project> && git config core.hooksPath templates/githooks
```

两个钩子作用不同：

- **`commit-msg`**：按 `.agents/commit.md` 校验提交信息格式。类型大小写、是否带单号、有没有 AI 署名，不合格直接拒绝提交——把规范从"文档里的红线"变成"推不上去"。
- **`post-commit`**：项目里有 `.codegraph/` 时，提交后自动 `codegraph sync`。

四个设计要点（也是常见踩坑）：

- `post-commit` 只在 `.codegraph/` 存在时执行，没建索引的项目不受影响。
- **找不到 `codegraph` 命令、超时、同步失败，都只提示、不阻塞提交**——提交已经完成，不能因为索引失败让流水线/脚本误判。
- 钩子的 `PATH` 常常和 IDE 里不同，所以留了 `CODEGRAPH_BIN`（可传绝对路径或整条命令，如 `npx -y codegraph`）。
- 临时跳过：`SKIP_CODEGRAPH_SYNC=1` / `SKIP_COMMIT_MSG_CHECK=1`；同步默认 120 秒超时。

## 自检：让规范检查自己

```bash
bash scripts/check.sh
```

五项检查，每一项都对应一次真实踩过的坑：

| 检查 | 挡住的问题 |
| --- | --- |
| `AGENTS.md` ≤ 150 行 | 入口膨胀成"万能文件"，模型只记得住开头 |
| 无明文邮箱 | 真实邮箱推上公开仓库就洗不掉 |
| `.agents/*.md` 都在分流表登记 | 新增模块忘了登记 → 永远不会被加载 |
| 引用的 `.md` 文件存在 | 文档指向一个不存在的文件（本仓库自己就断过两次） |
| 代码块成对闭合 | 漏一个 ``` 让后面全文变成代码 |

本仓库已配 `.github/workflows/check.yml`，每次 push / PR 自动跑，并额外扫描提交历史里的非匿名邮箱。目标项目用 `--with-ci` 会装上同一份。

## 文件清单

| 文件 | 什么时候被读 | 内容 |
| --- | --- | --- |
| `AGENTS.md` | 每次会话 | 优先级、工作方式、自动探测、分流表、10 条跨语言红线、文案语言、完成定义、交付要求 |
| `.agents/project-profile.md` | 每次会话 | **每个项目唯一要改的文件**：项目类型、语言版本、提交身份、部署目标、AI 作用域、验证命令、例外 |
| `.agents/commit.md` | 写 commit、定分支、打 tag | 公司《代码提交规范 V2.5》精简版：`[NF]/[BF]/[IM]` 类型与单号、三段式格式、粒度禁令、分支、Tag、关键代码评审 |
| `.agents/discipline.md` | 提交、碰凭据、收尾 | Git 红线、匿名与脱敏、自测闭环、多会话并行 |
| `.agents/integration.md` | 对接外部系统、调 SDK | HTTP 200 陷阱、签名与编码、字段类型契约、时间戳单位、连接半开与断线缓冲、SDK 有状态实例、批量写入与类型映射 |
| `.agents/legacy.md` | 接手老项目、加功能、重构巨型类 | 体检 grep、找接缝、处理器+注册表、迁移只搬不改、grep 验收、不变量清单、老 Java 高频坑 |
| `.agents/lang-java.md` | 改 Java 时 | JDK 特性、Optional 与拆箱、虚拟线程与锁、超时预算、缓存、异常、日志、JSON、线程池 |
| `.agents/lang-python.md` | 改 Python 时 | 虚拟环境、类型注解、异常链、asyncio、日志、pytest |
| `.agents/lang-vue.md` | 改前端时 | 组合式 API、状态、请求层、key、SPA 回退、base、可访问性 |
| `.agents/release-github.md` | 发版、改 workflow | 触发策略、版本号、tag、Release、Pages、权限与 Secrets、回滚 |
| `.agents/release-docker.md` | 改镜像/部署 | 镜像命名、多阶段与分层、healthcheck、挂载、compose、国内镜像、离线包 |
| `CLAUDE.md` | Claude Code 会话 | 只有一行 `@AGENTS.md`，让只认 CLAUDE.md 的工具也能读到同一份规范 |
| `install.sh` / `install.ps1` | 安装时 | 把上面这些装到目标项目，默认不覆盖已有文件 |
| `templates/githooks/commit-msg` | 提交时 | 按 `commit.md` 校验格式，不合格拒绝提交 |
| `templates/githooks/post-commit` | 提交后 | `codegraph sync`；失败/超时/缺命令一律只提示不阻塞 |
| `templates/github/check.yml` | 目标项目的 CI | 自检 + 历史邮箱扫描，`--with-ci` 时安装 |
| `scripts/check.sh` | 本地或 CI | 五项自检，见上节 |
| `SKILL.md` | agent 会话 | 作为 WorkBuddy skill 使用时的入口 |
| `references/` | 按需查阅 | profile 填写指南、运作原理、扩展模块写法 |
| `reviews/` | 新增规则前 | 待审批的经验提取报告，格式见 `reviews/README.md` |

## 设计原则（改动前先读）

1. **分层加载**：入口 ≤150 行，模块按任务加载。一份 400 行的"万能文件"会让模型只记住开头几条。
2. **规则分三档**：`【红线】` 无例外、`【默认】` 可被 profile 覆盖、`【建议】` 自行权衡。不分档的规范等于没有规范。
3. **触发条件优先**：每条规则都能回答"什么时候适用"。写不出触发条件的规则是废话，应删。
4. **不写会腐烂的事实**：版本号、路径、IP、账号一律进 profile，规范里只写"以 pom/pyproject 为准"。
5. **事故驱动**：新规则来源于真实踩过的坑，不是收集口号。加规则时尽量带上"为什么"。
6. **可验证**：能写成命令验证的，就给命令；不能的，至少给反例。

## 工具兼容

- `AGENTS.md` 是跨工具事实标准（Codex / Cursor / Jules 等直接读根目录）。
- Claude Code 只认 `CLAUDE.md`：本仓库已提供，内容是一行 `@AGENTS.md`。安装时会一起带上。
- 有的工具要求小写 `agent.md`：`git mv AGENTS.md agent.md` 或建软链，不要维护两份。
- 需要目录级规则时，可在子目录放 `AGENTS.md` 补差异，但**不要在子文件里重复根文件的内容**。

## 扩展方式

加一种语言：复制 `lang-java.md` 的结构（版本 → 类型与空值 → 并发 → 异常 → 日志 → 依赖 → 测试 → 反例），只写这门语言**特有的坑**，通用纪律不要抄。

加一个平台（k8s、Serverless、移动端）：在 `.agents/` 下新增 `release-*.md`，并在 `AGENTS.md` 第 2、3 节的分流表里登记触发条件——不登记就永远不会被加载（`scripts/check.sh` 会拦住这种疏漏）。

详细写法见 [`references/extending.md`](references/extending.md)。

## 已知边界

- 模块不会自动加载，靠两件事保证：`AGENTS.md` 里的分流表 + 你在开场的明确指令。首次使用建议显式说一次。
- 规范越长，遵守率越低。加规则前先想"删掉哪条"。
- 它约束不了工具链没覆盖的地方：真正的门禁还是 CI（邮箱检查、敏感词扫描、构建与测试）。本仓库的 `check.yml` 是最小实现，可直接抄。

## 经验来源（可追溯）

规则不是凭空写的，每条都能追到具体事故或文档：

| 来源 | 贡献的模块 |
| --- | --- |
| 内部项目 dumpmgr（Spring Boot / Java 21 / 虚拟线程 / Commvault 中间件） | `lang-java.md` 的并发、超时重试、缓存、JSON；`integration.md` 大部分 |
| 内部项目 i2bb（大数据备份恢复，遗留代码 + AI 全量开发 Kudu 子系统） | `legacy.md` 全部；`integration.md` 的长任务与分布式协作；`discipline.md` 的长任务工程记录 |
| 公司《代码提交规范 V2.5》（`CodeCommitGuide.md`） | `commit.md` |
| 开源项目 kudu-console（Spring Boot / Vue / Docker / Actions） | `release-github.md`、`release-docker.md`、`discipline.md` 的匿名与脱敏 |
| 本仓库自身（首次提交把真实公司邮箱推上了公开仓库） | `templates/githooks/commit-msg`、`scripts/check.sh` 的邮箱检查、`.github/workflows/check.yml` |

`reviews/` 目录放的是**待审批的提取报告**：从项目里挖到经验 → 先出报告 → 审批通过才合并进 `.agents/`。命名格式与合并原则见 `reviews/README.md`。

## 许可

本作品采用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) 许可协议，可自由复制、修改、商用，需保留署名。全文见 `LICENSE`。

```
ai-dev-standards by saul, licensed under CC BY 4.0
https://github.com/999bug/ai-dev-standards
```

last-verified: 2026-10-30
