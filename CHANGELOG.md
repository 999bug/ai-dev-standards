# 变更记录

版本号是插件的更新依据：`plugin.json` 里的 `version` 不变，装了插件的用户就收不到新版。
发版流程见 `scripts/release.sh`。

## [1.10.0] - 2026-11-09

### 新增

- **Android 开发规范 `lang-android.md`**：把「改完怎么证明没改坏」写成可执行的四层——
  编译、单测、装机走主路径、设备端集成，并说明每层抓什么、哪一层不能省。补上版本基线的
  三种报错（Gradle JDK 过低 / AAR 元数据 / SDK location）、`exec-out` 截图的 MSYS 路径坑、
  模拟器卡死先杀进程而不是反复 `adb reboot`、Room 改表三件套（升版本 + Migration + 测试，
  禁止 `fallbackToDestructiveMigration`），以及 Compose 窄屏与深色、`aapt2 dump badging`
  核对合并后的权限。
- **Android 发布规范 `release-android.md`**：keystore 与两个口令从第一个 Release 起离机备份
  （换密钥 = 只能卸载重装 = `allowBackup=false` 时数据全丢）、条件式签名配置（缺变量时本地
  仍可出包）、CI 四个 secret、`versionCode` 单调递增、先验签再上传、`.sha256` 只证明字节完整
  不证明来源。升级策略按「产品承诺」分成三档，明确加 `INTERNET` / `REQUEST_INSTALL_PACKAGES`
  必须同一次改动里改隐私说明；要做自更新给到清单字段与 `PackageInstaller` 最小骨架。
- **探测与裁剪接上 Android**：按 `AndroidManifest.xml` 判定，Android 工程不再被
  `build.gradle` 误判成普通 Java 项目；`compileSdk` 兼容三种写法（含 AGP 8.6+ 跨行的
  `release(37)`），Kotlin 版本依次查版本目录、classpath、plugins 块。装 Android 时连带
  `release-android.md`，因为出签名包是必经步骤。profile 模板补 `languages.kotlin`。

### 修复

- `install.sh` 汇总里的模块总数写死成 `/11`，加模块后必然过期；改为按 `.agents/*.md`
  实际数量统计。`install.ps1` 原本就是动态的，两边行为现在一致。

## [1.9.1] - 2026-11-04

### 新增

- **Java 规范禁止行尾注释**：注释独立成行放在被解释语句上一行。`int x = calc(); // 说明`
  这类写法在行宽变化或格式化后容易被挤走，写在方法调用参数中间还会把一句调用割裂；
  工具指令（`// NOSONAR` / `// noinspection`）例外，必须贴同一行才生效。
- 同名类冲突的写法同步修正：不再用行尾注释说明原因，改为上一行独立注释；
  第 2 节与反例清单都补了 Avro / Kudu `Schema` 同名的 ✗/✓ 对照。

## [1.9.0] - 2026-11-04

### 新增

- **Java 规范补「导入与命名」一节**：禁止用全限定类名（FQN）代替 import，
  `com.foo.Bar` 只在同名类冲突时于唯一出现处使用并注明原因。同时管住通配导入、
  未使用 import、静态导入滥用，补命名惯例与缩略语大小写（`parseHttpUrl` / `userId`）。
- 该节标明是**格式与可读性**要求：不影响编译运行，但影响读代码与 review，
  因此条目用【默认】/【建议】，不占红线（红线只留给会出故障的规则）。

### 变更

- `lang-java.md` 章节号顺延（空值 → 3 … 反例清单 → 12），反例清单补上
  「声明和调用各背一遍包名」的 ✗/✓ 对照；README 的 `lang-*.md` 内容描述同步。

## [1.8.1] - 2026-11-04

### 修复

- **没有 `pom.xml` / `build.gradle` 的 Java 项目识别不出来**（例如用 `build/build.sh` 打包的
  老项目），安装时漏掉 `lang-java.md`。探测改为按源码后缀递归兜底：先扫常见源码目录，
  扫不到就全仓库扫到 8 层，跳过 `.git` / `node_modules` / `build` / `target` / `dist` / `out`。
  Java / Python / Vue 都适用，结构不规范（源码埋在 `module/src/main/java` 这种深路径）也能识别。
- 顺带上报 `build/build.sh` 这类自带构建脚本的位置（`build_script`），供 profile 参考。

## [1.8.0] - 2026-11-04

### 新增

- **首次安装按探测结果自动填 profile 初稿**：安装器把项目名、描述、语言版本、包管理器、
  构建/测试/启动命令、框架、提交风格、部署目标、registry、敏感信息位置直接写进
  `.agents/project-profile.md`，剩下 `type` / `visibility` / `verify_*` 才需要人确认。

### 变更

- `project-profile.md` 模板精简：去掉 `domestic_mirror`、`release_assets`、`retention`、
  `verify_smoke` / `verify_version` / `verify_ui` 等低频字段，语言块按实际探测结果启用或
  注释掉示例行，避免示例值被当成项目事实。
- `--upgrade` / `-Upgrade` 不再改动 `.agents/project-profile.md`（sh 与 ps1 同步）：
  升级只更新规范，项目档案和手写结论保持原样；要按新模板重整就手动跑
  `/ai-dev-standards:profile`。汇总里会明确提示这一点。

## [1.7.0] - 2026-11-04

### 新增

- **安装器按项目裁剪模块**：语言模块只在探测到该语言时装（`pom.xml` → Java、
  `pyproject.toml` → Python、`package.json` + `vue` → Vue），`release-github` 只在用了
  GitHub（workflows 或 github remote）时装，`release-docker` 只在有 `Dockerfile`/`compose` 时装。
  `AGENTS.md` 的分流表会同步删掉未装模块的行，不留悬空引用。
- `--all-modules` / `-AllModules` 保留旧的全量行为；`--modules=a,b` 手动指定。
- 安装汇总增加「模块：N/11（与项目无关，跳过 …）」，dry-run 也能看到裁剪结果。

### 变更

- 纯 Java 项目从 15 个文件降到 11 个（7 个模块）；前端 + GitHub + Docker 为 13 个。
- 裁剪判断复用 `scripts/detect-profile.sh`，安装器和 profile 生成不再各判断一套。

## [1.6.0] - 2026-11-04

### 新增

- `/ai-dev-standards:profile`：一键生成 project-profile。`scripts/detect-profile.sh` 先探测
  语言版本、构建/测试命令、部署目标、提交风格、目录结构与 git 身份，再只问四个必须由人
  决定的选择（仓库性质、提交风格、推送策略、是否现在跑验证），其余自动写入。
- 安装命令结束后直接进入生成流程，不再让用户对着 28 个「未定」逐项查。
- 探测脚本对邮箱脱敏：只输出「是不是 noreply」和来源（仓库级 / 全局），不打印真实地址。

### 变更

- `project-profile.md` 模板与 `references/profile-guide.md` 把「一键生成」列为默认填法，
  手填和 `/init` 产物出初稿降为备选。
- SessionStart 提醒在仍有「未定」时直接给出 `/ai-dev-standards:profile`。
- 安装器收尾提示改为「生成 profile」而不是「填 profile」。

## [1.5.0] - 2026-11-04

### 破坏性变更

- **去掉 SessionStart 自动安装**。以前装完插件、在任意 git 仓库开一次会话就会自动写入 15 个文件，
  其中还包括会改变提交行为的 git 钩子。这和规范自己的第一条红线「先诊断、后动手」冲突，
  而且插件装成 `user` scope 时会影响所有仓库。安装改为显式命令：`/ai-dev-standards:install`。
- SessionStart hook 保留，但只输出两三行上下文（是否已装、还有几处「未定」、按分流表加载模块），
  不再写任何文件，也不再自动执行 `codegraph init`。

### 新增

- `/ai-dev-standards:install` 与 `/ai-dev-standards:upgrade` 两个插件命令。
- `install.sh --upgrade` / `install.ps1 -Upgrade`：按 `.agents/.standards-version` 里记录的
  sha256 判断文件是否被本地改过，没改过的更新、改过的另存为 `<文件>.new`。
- `install.sh --shared-hooks` / `install.ps1 -SharedHooks`：钩子写进项目的 `.githooks/`
  并设置 `core.hooksPath`，让门禁跟着仓库走，团队 clone 后直接生效。
- 安装清单 `.agents/.standards-version`，记录版本与每个文件的 hash。
- `scripts/check.sh` 第 6 项数字对账（模块数、默认安装文件数）、第 7 项插件清单自洽
  （plugin.json 版本 == CHANGELOG 首条、hooks 引用的脚本存在、命令有 description）。
- `scripts/release.sh`：一条命令改版本、补 CHANGELOG、跑自检、打 tag。
- `LICENSE-MIT`：脚本部分改用 MIT，文档仍是 CC BY 4.0。

### 修复

- **重复安装不再重写钩子**。之前每次跑都会重写两个钩子，输出「写入 2 个文件」，
  和文档里写的「写入 0，全部跳过」不符；现在内容相同就真跳过。
- `check.sh` 之前漏检 `docs/*.md`（两个最长的文档），往里面塞真实邮箱都能全绿。
- `check.sh` 第 4 项之前只认反引号里的路径，README 用的 markdown 链接整片漏检。
- 冲突文件不再把本地改动后的 hash 写进安装清单，避免下一次 `--upgrade` 静默覆盖。

## [1.4.0] - 2026-11-03

- `project-profile.md` 支持按映射表从 `/init` 产物生成初稿。

## [1.3.0] - 2026-11-03

- 新增 `.agents/task-workflow.md`：长任务拆分、台账与交接、子代理任务书。

## [1.2.0] - 2026-10-30

- 钩子改为链式调用：已有的自定义钩子保留为 `.local`，由规范钩子接着执行，不再停用。
- 自检脚本改为按需安装（`--with-check`），默认不写 `scripts/`。
- 钩子改为默认安装，落到 `.git/hooks/`；`post-commit` 增加 codegraph 索引同步。

## [1.1.0] - 2026-10-30

- 插件自带 SessionStart hook，首次在项目里开会话时自动安装规范。

## [1.0.0] - 2026-10-30

- 首个版本：`AGENTS.md` 入口 + `.agents/` 模块 + 安装器 + 插件市场分发。
