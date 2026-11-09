# Android 开发规范

**加载时机**：改 Kotlin / Compose / Room / Gradle 脚本，或在模拟器、真机上验证 Android 改动。
**边界**：本模块管「改完怎么证明没改坏」。出签名包、发版、应用内升级见 `release-android.md`。

## 0. 动手前先读三处

- **【红线】版本基线读文件，不凭印象**。AGP、Gradle、Kotlin、`compileSdk` / `targetSdk` / `minSdk` 互相约束，答案在 `gradle/libs.versions.toml`（有的话）或 `app/build.gradle.kts`。按「一般都用这个版本」去改，最常见的后果是 `checkDebugAarMetadata` 报一串 AAR 元数据错误。
- **【默认】构建一律走 `./gradlew`**，不用系统 `gradle`：wrapper 锁定版本，系统装的那个永远对不上。
- **【默认】`local.properties` 只属于这台机器**（`sdk.dir` 指向本机 SDK）。它必须进 `.gitignore`，永远不入库。

## 1. 环境对不上时的三个信号

| 报错 | 真实原因 | 处理 |
| --- | --- | --- |
| `Unsupported class file major version` | Gradle 用的 JDK 低于 AGP 要求 | 换 Gradle JDK（Android Studio：Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK），不是改 `sourceCompatibility` |
| `checkDebugAarMetadata` 一片 AAR 元数据错误 | 某个依赖要求的 AGP / compileSdk 高于工程配置 | 升 AGP 与 compileSdk，或降依赖；别照着单条报错逐个改 |
| `SDK location not found` | 缺 `local.properties` 或 `ANDROID_HOME` | 补 `sdk.dir` 或设环境变量；不要把它提交进仓库 |

## 2. 四层验证，从快到慢

按代价排序。**能靠上一层抓到的，不要留到下一层**。

| 层 | 命令 | 抓什么 |
| --- | --- | --- |
| L1 编译 | `./gradlew :app:assembleDebug` | 语法、资源、Manifest 合并、依赖解析 |
| L2 单元测试 | `./gradlew :app:testDebugUnitTest` | 纯逻辑：时间换算、mapper、状态机 |
| L3 装机走主路径 | `./gradlew :app:installDebug` + 手动点 | 界面真的长对了、数据真的落盘 |
| L4 设备端集成 | `./gradlew :app:connectedDebugAndroidTest` | Room 迁移、真实 SQLite 行为、跨进程 |

- **【默认】改 Gradle 脚本或依赖版本后跑一次 `clean` 全量构建**。增量构建会复用旧依赖解析结果，把问题藏起来。
- **【红线】不把「编译过了」当验证完成**。L1 通过只说明能出包，不说明按钮点下去有反应。
- **【默认】L3 的价值只有两个**：看界面、看数据。逻辑正确性该在 L2 用测试证明。
- 单测报告在 `app/build/reports/tests/<变体>/index.html`，失败先看报告再看终端输出。

## 3. 设备与观察手段

```bash
adb devices                  # 谁在线
adb -s <serial> shell ...    # 多设备时每条命令都要指定，否则报 "more than one device"

adb logcat -s AndroidRuntime                        # 只看崩溃
adb logcat --pid=$(adb shell pidof <applicationId>) # 只看自己的进程
adb exec-out screencap -p > shot.png                # 截图
```

- **【红线】Git Bash（MSYS）下不要用 `adb shell screencap -p /sdcard/x.png` 再 pull**：`/sdcard` 会被当成 Windows 路径转换，报 `Error opening file: D:/.../sdcard/x.png`。用 `exec-out` 重定向。
- **【默认】模拟器卡死（截图不更新、`adb shell` 超时）先重启模拟器，不要反复 `adb reboot`**：

```bash
adb kill-server
taskkill //F //IM emulator.exe
taskkill //F //IM qemu-system-x86_64.exe
```

`//F` 的双斜杠是给 Git Bash 抵消路径转换；macOS / Linux 用 `pkill -f emulator`。

## 4. Room：改表是最容易翻车的地方

- **【红线】改实体必须三件套一起上**：`version` + 1、写 `Migration(旧, 新)` 并加进 `databaseBuilder`、补一个迁移测试。缺一样，升级安装的用户启动即崩在 `Room cannot verify the data integrity`。
- **【红线】不用 `fallbackToDestructiveMigration()` 兜底**。它会静默清库——用户看不到报错，只发现记录没了。
- **【默认】schema 导出目录（`app/schemas/`）入库**，它是迁移测试和后续 diff 的依据。
- 开发期为省事卸载重装可以，但那不叫「迁移通过」，别拿它当验收。

**看数据**：首选 Android Studio 的 `App Inspection → Database Inspector`，能直接跑 SQL、开 Live updates。命令行兜底（debug 包可 `run-as`）：

```bash
adb exec-out run-as <applicationId> cat databases/<db>.db > local.db
adb exec-out run-as <applicationId> cat databases/<db>.db-wal > local.db-wal
```

- **【默认】WAL 模式下必须连 `-wal` 一起拉**，只拉主库会丢最近写入的数据。

## 5. Compose 与资源

- **【默认】改界面要两个维度各看一次**：窄屏（约 360dp）与深色模式。只在大屏浅色下点过，等于没验。
- **【默认】截图留证**，交付说明里能贴就贴；「我点过了，没问题」不算证据。
- **【默认】改图标或应用名后卸载重装再确认**。启动器有图标缓存，覆盖安装经常显示旧图标。
- **【默认】权限变更后用 `aapt2 dump badging <apk>` 核对实际声明**。Manifest 合并会把依赖库的权限一起并进来——你可能凭空多出定位、网络权限。

## 6. 改哪类代码，验什么

| 改动 | 必验 | 容易漏 |
| --- | --- | --- |
| 时间 / 时区换算 | L2 单测；跨午夜、跨时区各一例 | 算错不抛异常，只会让统计默默错 |
| Compose 界面 / 导航 | L3 手动走一遍 + 截图 | 深色模式、窄屏 |
| Room 实体 / 字段 | 先升版本 + 写迁移，再 L3 | 不写迁移 = 升级用户启动崩溃 |
| 图标 / 资源 / Manifest | `installDebug` 后看桌面；`aapt2 dump badging` 看权限 | 图标有桌面缓存 |
| Gradle 脚本 / 依赖 | `clean` 后全量构建 | 增量构建掩盖依赖解析问题 |

## 7. 最小验收清单

- [ ] `:app:assembleDebug` 通过，没有新增 warning
- [ ] 改了逻辑就补了对应单测并通过（不是「应该没问题」）
- [ ] 主路径在模拟器或真机上手动走过
- [ ] 碰了数据库：Database Inspector 里确认数据真的落盘
- [ ] 碰了界面：窄屏与深色模式各截一张图
- [ ] 工作区干净：没有调试 `println`、临时脚本、`build/` 产物进库

## 8. 反例清单

踩到坑按「现象 → 根因 → 修复 → 教训」追加一行，别只留在聊天记录里。

- 待补充
