# 变更记录

版本号是插件的更新依据：`plugin.json` 里的 `version` 不变，装了插件的用户就收不到新版。
发版流程见 `scripts/release.sh`。

## [1.13.1] - 2026-11-12

### 新增

- **升级流程拆成「插件 / 规范本体」两步**：README 与 `references/claude-code.md` 说明 `claude plugin update` 只更新插件缓存里的命令、安装器与模板，不会碰 `~/.ai-dev-standards/`；重进会话后再跑 `/ai-dev-standards:upgrade` 才刷全局目录。顺序反了会拿旧模板比对、判定「内容一致」全部跳过。附版本核对命令、shell 直跑写法与 clone 例外。
- **补齐 WorkBuddy 的更新流程**：`docs/other-agents.md`、`docs/manual-install.md`、`SKILL.md`、插件 skill 入口与 README 一致说明两层更新——先 `git pull` skill 副本（新开一段对话生效），再用新 skill 的 `install.sh --global --upgrade` 刷全局目录；项目侧不用动。WorkBuddy 没有命名空间斜杠命令，可在对话里说「升级 AI 开发规范」触发。
- 常见问题表新增两条排查：「插件升了、规范还是旧版」「skill / 插件升了、规范还是旧版」。

### 改进

- **README 重写为「这是什么 → 安装 → 卸载」**：表格对齐，移除 1.12.x 旧结构升级小节（完整流程保留在 `docs/manual-install.md` 第 7、8 节）。

### 修复

- `commands/upgrade.md` 里 `source=repo` 原写「升级跟随插件更新」，容易被读成 `plugin update` 就够；改为 `git pull` 更新规范本体，并补「`source` 只描述规范本体位置，插件缓存始终单独更新」与 `source=copy` 的分流。
- 修「升级只跑一次」的歧义表述，改成「只升全局这一处，不用每个项目重跑」。

## [1.13.0] - 2026-11-12

### 破坏性变更

- **规范从「每个项目装一份」改为「全局装一次」**。1.12.x 及更早版本把 `AGENTS.md`、14 个
  模块、`CLAUDE.md` 和钩子复制进每个项目：改一条规则要同步 N 个仓库，升级要跑 N 次。
  现在规范本体装到 `~/.ai-dev-standards/`（可用 `AI_DEV_STANDARDS_HOME` 覆盖），项目里
  只留 `AGENTS.md`（约二十行指针）、`CLAUDE.md`（一行 `@AGENTS.md`）和
  `.agents/project-profile.md`。升级只跑一次 `--global --upgrade`，项目侧不需要再动。
- **删掉六个安装开关**：`--minimal`、`--with-check`、`--with-ci`、`--all-modules`、
  `--modules=`、`--shared-hooks`。模块全量装在全局目录，按项目裁剪失去意义；项目级
  CI 自检门禁在新结构下也不成立（CI runner 上没有全局目录）。命中旧参数会明确报错，
  不静默忽略。
- **旧项目不会自动迁移**。在 1.12.x 项目里跑初始化，安装器只检测并打印精确的清理命令
  （`git rm` / `rm -f`），**不删除任何文件**；`project-profile.md` 不在清理范围。

### 新增

- **`install.sh --global` / `install.ps1 -Global`**：把 `AGENTS.md`、14 个模块、
  `scripts/`、`templates/` 共 22 个文件装到全局目录，写 `.standards-version`
  （版本 + 每个文件的 sha256 + `source`）。幂等：已是最新时输出「写入 0 个文件」。
  全局目录可以直接是本仓库（clone 到 `~/.ai-dev-standards`），此时不复制、升级走 `git pull`。
- **项目初始化只写 3 个文件 + 2 个钩子**：`AGENTS.md` 指针指向全局目录（用
  `${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}` 表达，不写死绝对路径、不把用户名
  带进仓库）、`CLAUDE.md` 一行 `@AGENTS.md`、`.agents/project-profile.md` 按探测结果
  填初稿，钩子进 `.git/hooks/`。
- **`templates/project/`**：项目侧指针模板。指针里给了一条可直接执行的 `cat` 命令，
  避免模型凭记忆拼路径；读不到时明确要求停下并提示安装，不许凭记忆执行规范。

### 修复

- **全局升级会备份你改过的模块**。`--global --upgrade` 按清单 sha256 判断：没改过的
  直接覆盖；改过的先复制到 `.backup/<时间戳>/` 再覆盖，汇总里逐条列出，不静默丢改动。
- **`session-context.sh` 的三态判断**：已接入（报「未定」数）/ 全局装了但本项目没初始化 /
  全局也没装。以前只有「装过 / 没装过」，新结构下缺了中间态会误导用户重装。
- **`check.sh` 第 6 项改口径**：对账模块数与「全局 N 个文件」（`module_count + 8`），
  取消已不存在的「写入 N 个文件」。
- **路径比较用物理路径**：Windows 下 `F:/x` 与 `/f/x` 是同一个目录，按字符串比会把
  「全局目录就是本仓库」误判成两份拷贝。

## [1.12.1] - 2026-11-11

### 新增

- **Gitee 镜像：「发布完成」的判据是清单，不是 Release 创建**。`release-gitee.md` 第 2 节由三条
  硬原则扩为四条。平台 API 强制「先建 Release 拿到 `release_id` 才能传附件」，这段窗口期里最新
  版已经可见、附件却没齐，客户端会推着一个点不动的下载按钮；反过来「暂时没准备好」又被当成
  「源不可用」时，用户会被导流去跨境下载几十 MB。规则改为：附件全部校验通过后**最后写清单**
  （如 `latest.json`），清单的 `version` 等于本次 tag 才算发完；有应用内更新链路的项目客户端
  **只读清单，不调 `releases/latest`**（匿名请求会被限流返回 403）。第 4 节把清单写入落到发版
  步骤末尾，并补「清单可单独重跑」（`manifest_only`），补写清单时不必重跑整条流水线。第 6 节
  `latest` 条款改为「只作人工核对」，第 8 节验证清单改为以清单为准。
- **Gitee 镜像：模块自带可执行骨架**。第 5 节补一段 52 行的压缩 YAML（自检 → 幂等 → 建
  Release → 传附件 → 最后写清单），与上面六条要点一一对应；完整模板、参数替换表与两套人工
  补传脚本仍留在操作手册。此前目标项目只装模块、拿不到模板，只能照着要点重写 job，而「产物只
  构建一次」「先自检再写入」这些红线恰好在重写时最容易丢。

### 修复

- `README.md` 的 Gitee 小节把「核心误区」补成两条：仓库镜像不含 Release 附件之外，还有
  「Release 建好就算发完了」——清单才是切换点，客户端也只读清单。

## [1.12.0] - 2026-11-11

### 新增

- **外部对接：第三方响应的「不存在」有四种形态**。`integration.md` 第 1 节补两条红线：解析前
  先判 JSON 类型（成功分支不一定是对象，Gitee contents 对不存在的文件返回 `[]`，在数组上取
  `.sha` 直接抛错，配上 `set -euo pipefail` 会终止整步）；「先查再写」的幂等逻辑必须让
  `404` / `[]` / `null` / `{"message":"not found"}` 都能落到创建分支。另补验证口径：验证脚本
  必须复刻客户端的 HTTP 行为，`curl` 默认不跟随重定向而多数 HTTP 客户端默认跟随，验一个 302
  的接口会拿到重定向页并误判成「内容损坏」；返回体像 HTML / 登录页时先怀疑重定向、反爬、
  缓存。README 模块表同步。
- **Android：字体缩放是第三个验证维度**。`lang-android.md` 第 5 节把「窄屏 + 深色模式」扩为
  三档，补红线：`sp` 随 `fontScale` 放大而 `dp` 不变，「文字行数 × 字体缩放」的容器写死
  `height` 必然被裁（48dp 加到 72dp 只是把裁切入场推后），改用 `heightIn(min = …)` 或按
  `fontScale > 1.3f` 分档；横向滚动的 chips 只保证「能滑到」，不保证「首屏完整可见」。第 3 节
  补 `wm size` 改的是像素不是 dp（先按 `wm density` 换算，验完 `wm size reset`），以及
  `MSYS_NO_PATHCONV=1` 这条根因级规则——它同时解释 `screencap`、`adb push`、`run-as cat`
  三类路径改写现象。第 6、7 节同步。
- **Android 发布：版本可用 ≠ 制品可用**。`release-android.md` 第 8 节新增一节：第三方 `latest`
  返回的是「发布意图」不是「可下载事实」，客户端必须区分「没拿到版本信息 / 有版本但制品未就绪
  （可重试）/ 源不可用」三态，最糟的中间态是「提示有新版本却没有下载按钮」；就绪判据取最后上传
  的校验文件（`assets` 同含安装包与 `.apk.sha256`）；「暂时没准备好」不能和「源不可用」共用兜底
  分支，否则会把用户导流去跨境下载；唯一主源替换第一次单独灰度；判断新版本的请求不走可缓存层。
  第 4 节补「应用内更新日志是编译进 APK 的静态列表，构建前校验首条 == 本次版本」，并声明版本号
  由 CI 推导时不要手改构建文件。第 9 节加两条验收。
- **GitHub 发布：失败分阶段补救与 CI 回写版本号**。`release-github.md` 第 8 节补「流水线失败
  ≠ 产物没发布」——失败常落在最后新增的一步，前面的外部副作用已不可回滚，先 `gh release view`
  查产物再决定补什么；新增的收尾步骤默认会失败一次，要设计成可独立重跑。第 2 节按「版本号是否
  影响产物身份或运行时行为」二分（影响就回写源码，不影响只算 tag），并给出 CI 写主分支的四个
  条件与重跑非幂等。第 10 节补网络报错不等于操作没生效：先 `fetch` 核实远端，见 `cannot lock
  ref` / `non-fast-forward` 立即停手。
- **Gitee 镜像：验证用的 curl 必须跟重定向**。`release-gitee.md` 第 8 节补 `-sL` 与打印
  `url_effective`——平台把 `raw` 路径 302 到 CDN，不加 `-L` 拿到的是重定向页，容易被当成清单
  损坏。

### 修复

- `release-android.md` 第 5 节原写「`workflow_dispatch` 手动触发，参数是版本号」，与「版本号
  留空、由 CI 从最高 tag 递增」的常见做法冲突，改为「可手填（跳 minor / major）或留空由 CI
  递增」。
- `AGENTS.md` 与 `README.md` 的 `last-verified` 更新到 2026-11-11。

## [1.11.1] - 2026-11-10

### 新增

- **双推国内 registry 的兼容与门禁**：`release-docker.md` 第 6 节补上 buildx 默认附加 OCI
  attestation 的问题——阿里云 ACR 个人版以 `unknown manifest class`（或清单里出现
  `platform: unknown/unknown`）拒绝，表现为推 ghcr 成功、推 ACR 失败，构建步骤需显式
  `provenance: false`；要保留证明链路就换支持 OCI 1.1 的企业版仓库，不要同一个版本号两边硬推。
  同节记下浮动工具链漂移：`setup-buildx` 默认装最新 buildx，同一份 workflow 隔几个月会产出
  另一种 manifest，「以前能推、现在不能推」多半是这条而不是配置写错。第 10 节高频坑补三行
  （绿勾但镜像缺失 / `unknown manifest class` / 浮动工具链漂移）。

### 修复

- `release-docker.md` 第 6 节原写「国内同步放独立步骤并 `continue-on-error`：失败只标红，
  不阻塞发版」，既与 1.11.0 已修的分发支路条款相反，也与实测结果不符：`continue-on-error`
  下 job 结论仍是成功、整条 run 是绿的，ACR 缺镜像没人发现。改为国内同步前置于 tag / Release、
  **失败即中止本次发布**——宁可不发版，也不发一个国内仓库拉不到的版本；前置时两者都还没生成，
  重跑不会撞版本号。同时把「未配 secrets 跳过」与「配了但失败」分开：前者 `exit 0`，后者
  `::error::` + `exit 1`，不再用 `::warning::` + `exit 0` 把失败吞掉。
- `release-github.md` 第 6 节按是否依赖 Release 产物拆成两种落法：不依赖的（镜像双推）前置
  门禁、失败中止发布；必须依赖的（附件镜像）只能后置、失败标红 + 人工补传。第 9 节回滚条款
  限定为「已发布之后」，消掉与容器侧的互相矛盾。README 模块表补「双推国内 registry 的门禁与
  兼容」。

## [1.11.0] - 2026-11-10

### 新增

- **Gitee Release 镜像规范 `.agents/release-gitee.md`**：把「GitHub 权威发布 + Gitee 国内分发」
  写成可执行规则。先分清 L1 代码 / L2 Release 元数据 / L3 Release 附件三层，明确平台仓库镜像
  只覆盖 L1、附件必须由 CI 调 OpenAPI 单独上传；方案选型收敛到「复用同一份 artifact + 镜像 job
  挂在唯一发布 workflow 后面」。三条硬原则：产物只构建一次、先自检再写入并验返回体、不复用
  tag / 不覆盖同名 Release。补齐一次性准备、每次发版 SOP、API 速查、失败只补镜像、两端验证、
  回滚约束、高频坑与迁移 Checklist。
- **完整操作手册 `references/gitee-release-sync.md`**：留在规范仓库、不装进目标项目。含可直接
  搬走的 `mirror-gitee` job 模板与参数替换表、Gitee OpenAPI 速查、Git Bash 与 Windows 两套人工
  补传脚本、验证清单、限制与回滚。原文档里的实例仓库、账号与项目私有文档引用已全部抽象掉。
- **探测与裁剪接上 Gitee 场景**：`detect-profile.sh` 增 `gitee_mirror` 事实，只认 workflow 里
  调了 Gitee API / 用了 `GITEE_TOKEN` 或存在 gitee 远端，不打印远端 URL；两个安装器据此装
  `release-gitee.md` 并连带 `release-github.md`（镜像 job 必须挂在现有发布 workflow 后面）。
  `AGENTS.md` 第 2、3 节登记新模块，未装时分流表对应行照样会被删掉。
- **README 增加手册索引与场景说明**，模块数 13 → 14、默认全量 17 → 18；SKILL、
  commands/install、docs/manual-install、references 里的计数同步对账。

### 修复

- `release-github.md` 第 6 节原写「可选步骤用 `continue-on-error: true`（例如同步国内镜像）」，
  与实测结论相反：分发支路失败应标红让缺口可见，但不回滚、不重跑主链路，按规范人工补传。
  同时去掉边界行对未安装模块的悬空引用，裁剪后目标项目的 `check.sh` 第 4 项不再有断链风险。
- `docs/manual-install.md` 的全量模块数停在 11（1.10.0 后就不对），改为 14。

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
