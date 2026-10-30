# project-profile 填写指南

profile 是整套体系里唯一需要按项目改的文件。它不描述"规范"，只记录"这个项目的事实"——所以通用规范里才敢写"以 pom/pyproject 为准"。

## 填写的第一原则：读，不要问

能从这里读到的，就不要问用户：

| 字段 | 去哪读 |
| --- | --- |
| `languages.java` | `pom.xml` 的 `java.version` / `maven.compiler.release`，或 `build.gradle` 的 toolchain |
| `languages.python` | `pyproject.toml` 的 `requires-python`、`.python-version` |
| `languages.vue` | `package.json` 的 `vue` 版本 |
| `framework` | `pom.xml` / `package.json` 的依赖 |
| `package_manager` | 锁文件：`package-lock.json`、`pnpm-lock.yaml`、`poetry.lock`、`uv.lock` |
| `build_command` | `README`、`Makefile`、`build.sh`、`package.json` 的 `scripts` |
| `deploy_target` | `Dockerfile`、`docker-compose*.yml`、`.github/workflows/*.yml` |
| `release_trigger` | workflow 的 `on:` 段 |
| `registry` | workflow 里的 `docker push` 目标 |
| `ai_scope` | 项目目录结构，通常是源码目录，排除生成物与第三方代码 |

**只在读不到时才问，而且一次问完**，不要逐条追问。

## 各节要点

### 第 1 节 基本信息

`type` 决定三件事：提交身份、敏感信息尺度、发布链路。`oss` 和 `internal` 的默认值完全不同，填错会导致后续全部走偏。

`description` 写一句话：给谁解决什么问题。这句话后面会直接用作 GitHub 仓库描述。

### 第 2 节 技术栈

- 版本写实际值，不写 `8+`、`最新`。`java: 8+` 这种写法会让 AI 用 Java 8 的语法处理 Java 21 的代码。
- `build_command` / `test_command` **必须是真的能跑通的命令**，不是"应该是这个"。填之前先跑一遍。

### 第 3 节 提交身份与策略

- **oss**：邮箱一律用 `<GitHub数字ID>+<用户名>@users.noreply.github.com`。真实邮箱一旦推上公开仓库就洗不掉，历史改写代价极高。
- **internal**：用公司全局身份，写在这里而不是每次临时 `-c` 指定。
- `commit_style`：`company`（`[NF]/[BF]/[IM]` + 单号）或 `conventional`（`feat:` / `fix:`）。**看仓库已有提交的历史风格定，不要中途换**——混着来会让 `git log` 检索失效。
- `push_policy`：默认 `on-request`。`never` 用于"只提交不推送"的严格场景。

### 第 4 节 交付与发布

`version_scheme` 决定 tag 怎么打：
- `v1.0.<run_number>`：内部工具，不用维护版本文件
- 语义化 `vMAJOR.MINOR.PATCH`：对外发布
- 日期 `yyyy.mm.dd`：数据/内容类项目

`domestic_mirror`：国内机器拉 `ghcr.io` 常常超时，oss 项目默认配阿里云 ACR。

### 第 5 节 敏感信息

`never_commit` 只写**项目特有**的项。`.env`、`token`、`node_modules` 这些通用项已经在 `.agents/discipline.md` 里了，不用重复。

`internal_endpoints.allowed_in_docs`：内网地址能不能写进公开文档。默认 `false`。

### 第 6 节 作用域与验证

这一节最容易填成空话。规则：

- `ai_scope` 写**目录路径**，不写"前端代码""后端代码"这种描述
- `verify_*` 写**命令**，不写"跑一下测试"
- `test_port` 避开默认端口，否则和已在跑的实例抢端口

`verify_test_policy: compile-only` 只允许在项目明确这样约定时使用（例如测试依赖外部环境），且必须在第 8 节写明原因。

### 第 7 节 项目自有文档

项目里有 DEVELOPMENT、DEPLOY、ARCHITECTURE 这类文档时列在这里。它们的优先级高于通用规范——AI 要先读它们再动手。

### 第 8 节 覆盖与例外

通用规范里不适用、需要偏离的，逐条写清「规则 / 偏离 / 理由」。没有就写"无"。

**这一节存在的意义**：让偏离变成有记录的决定，而不是每次重新争论。

### 第 9 节 技术债与雷区

只写"会影响判断"的那几条。例如：
- 某个字段名与实际含义不符（`process_size` 存的是字节不是条数）
- 某个模块不能碰（第三方魔改过，升级会被覆盖）
- 某个测试必须连真实环境才能跑

## 三条红线

1. **不许猜。** 遇到 `未定` 就停下来问，不要拿示例值当事实。猜错一次构建脚本的代价，比多问一句高得多。
2. **不许写会腐烂的事实到通用规范里。** 版本号、路径、IP、账号只进 profile。
3. **填完要能验证。** `verify_*` 里的每条命令，填之前先跑一遍确认能通。

## 常见错误

| 错误 | 后果 |
| --- | --- |
| `java: 8+` | AI 以为项目是 Java 8，写出没有 `var` / record 的代码 |
| `build_command: ./build.sh` 但脚本没执行权限 | 每次构建都失败，然后 AI 开始绕路 |
| `commit_style` 与历史提交不符 | `git log --grep` 检索失效，changelog 生成不出来 |
| `ai_scope` 写成描述而非路径 | AI 不知道该改哪些目录，可能动到生成物 |
| 留着一堆「未定」就开工 | AI 按默认值猜，错误在几轮之后才暴露，返工成本最高 |
