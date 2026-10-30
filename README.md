# agent-kit：通用 AI 开发规范

一套可复制的规范文件，放进任意新项目根目录即生效。目标是**让 AI 按你的意图开发**，而不是按它的默认习惯。

## 三步使用

```bash
# 1. 复制到项目根目录（11 个文件）
cp AGENTS.md <project>/AGENTS.md
cp -r .agents <project>/.agents

# 2. 填 profile（唯一需要改的文件）
vi <project>/.agents/project-profile.md

# 3. 开工。开场第一句给足信息：
#    "先读 AGENTS.md 和 .agents/project-profile.md，再按分流表加载模块。"
```

## 可选：提交后刷新 CodeGraph 索引

项目里有 `.codegraph/`（已建索引）时，装一个 post-commit 钩子，提交后自动 `codegraph sync`，让下一次结构查询看到刚提交的代码：

```bash
mkdir -p <project>/.githooks
cp templates/githooks/post-commit <project>/.githooks/post-commit
chmod +x <project>/.githooks/post-commit
cd <project> && git config core.hooksPath .githooks
```

钩子的四个设计要点（也是常见踩坑）：

- 只在 `.codegraph/` 存在时执行，没建索引的项目不受影响。
- **找不到 `codegraph` 命令、超时、同步失败，都只提示、不阻塞提交**——提交已经完成，不能因为索引失败让流水线/脚本误判。
- 钩子的 `PATH` 常常和 IDE 里不同，所以留了 `CODEGRAPH_BIN`（可传绝对路径或整条命令，如 `npx -y codegraph`）。
- `SKIP_CODEGRAPH_SYNC=1 git commit ...` 可临时跳过；默认 120 秒超时。

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
| `templates/githooks/post-commit` | 可选安装 | 提交后 `codegraph sync`；失败/超时/缺命令一律只提示不阻塞 |

## 设计原则（改动前先读）

1. **分层加载**：入口 ≤150 行，模块按任务加载。一份 400 行的"万能文件"会让模型只记住开头几条。
2. **规则分三档**：`【红线】` 无例外、`【默认】` 可被 profile 覆盖、`【建议】` 自行权衡。不分档的规范等于没有规范。
3. **触发条件优先**：每条规则都能回答"什么时候适用"。写不出触发条件的规则是废话，应删。
4. **不写会腐烂的事实**：版本号、路径、IP、账号一律进 profile，规范里只写"以 pom/pyproject 为准"。
5. **事故驱动**：新规则来源于真实踩过的坑，不是收集口号。加规则时尽量带上"为什么"。
6. **可验证**：能写成命令验证的，就给命令；不能的，至少给反例。

## 工具兼容

- `AGENTS.md` 是跨工具事实标准（Codex / Cursor / Jules 等直接读根目录）。
- Claude Code 只认 `CLAUDE.md`：放一个，内容写一行 `@AGENTS.md` 即可（或直接软链）。
- 有的工具要求小写 `agent.md`：`git mv AGENTS.md agent.md` 或建软链，不要维护两份。
- 需要目录级规则时，可在子目录放 `AGENTS.md` 补差异，但**不要在子文件里重复根文件的内容**。

## 扩展方式

加一种语言：复制 `lang-java.md` 的结构（版本 → 类型与空值 → 并发 → 异常 → 日志 → 依赖 → 测试 → 反例），只写这门语言**特有的坑**，通用纪律不要抄。

加一个平台（k8s、Serverless、移动端）：在 `.agents/` 下新增 `release-*.md`，并在 `AGENTS.md` 第 2、3 节的分流表里登记触发条件——不登记就永远不会被加载。

## 已知边界

- 模块不会自动加载，靠两件事保证：`AGENTS.md` 里的分流表 + 你在开场的明确指令。首次使用建议显式说一次。
- 规范越长，遵守率越低。加规则前先想"删掉哪条"。
- 它约束不了工具链没覆盖的地方：真正的门禁还是 CI（邮箱检查、敏感词扫描、构建与测试）。

## 经验来源（可追溯）

规则不是凭空写的，每条都能追到具体事故或文档：

| 来源 | 贡献的模块 |
| --- | --- |
| 内部项目 dumpmgr（Spring Boot / Java 21 / 虚拟线程 / Commvault 中间件） | `lang-java.md` 的并发、超时重试、缓存、JSON；`integration.md` 大部分；提取报告见 `reviews/2026-10-30-dumpmgr-java.md` |
| 内部项目 i2bb（大数据备份恢复，遗留代码 + AI 全量开发 Kudu 子系统） | `legacy.md` 全部；`integration.md` 的长任务与分布式协作；`discipline.md` 的长任务工程记录；提取报告见 `reviews/2026-10-30-i2bb-java.md` |
| 公司《代码提交规范 V2.5》（`CodeCommitGuide.md`） | `commit.md` |
| 开源项目 kudu-crud（Spring Boot / Vue / Docker / Actions） | `release-github.md`、`release-docker.md`、`discipline.md` 的匿名与脱敏 |

`reviews/` 目录放的是**待审批的提取报告**：从项目里挖到经验 → 先出报告 → 审批通过才合并进 `.agents/`。

last-verified: 2026-10-30
