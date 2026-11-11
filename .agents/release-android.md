# Android 发布与签名规范

**加载时机**：打 APK、配 release 签名、发到 GitHub Releases 或应用商店、做应用内更新。
**边界**：本模块自带完整的签名与发布顺序，单独装也能走通。tag 策略、Release 正文、Pages 这些通用动作见 `release-github.md`（若项目已装）；本地验证见 `lang-android.md`。

## 0. 一条不可逆的红线

**签名密钥丢失等于用户数据丢失。**

- **【红线】keystore 文件与两个口令（keystore 口令、key 口令）从第一个 Release 起就备份到离机安全位置**（密码管理器 + 离线副本）。只留在开发机上，硬盘一坏就永久回不去。
- 为什么不能换密钥：覆盖安装要求新包与已装包签名相同。换了 keystore，用户只能卸载重装；若应用是 `allowBackup="false"` 且没有导出功能，卸载 = 全部数据永久消失。
- **【红线】`*.jks` / `*.keystore` / `keystore.properties` 永不入库，口令不进命令行参数、不进脚本、不进文档、不进聊天记录**。生成时交互式输入，CI 里用 secret。

## 1. 签名配置：条件式，别把本地卡死

release 签名只在四个值齐备时启用，缺一个就走 debug / unsigned 路径——本地没密钥的人照样能编译：

```kotlin
// app/build.gradle.kts
val keystorePath = System.getenv("ANDROID_KEYSTORE")
val storePass = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val keyAlias = System.getenv("ANDROID_KEY_ALIAS")
val keyPass = System.getenv("ANDROID_KEY_PASSWORD")

signingConfigs {
    create("release") {
        if (listOf(keystorePath, storePass, keyAlias, keyPass).all { !it.isNullOrBlank() }) {
            storeFile = file(keystorePath!!)
            storePassword = storePass
            this.keyAlias = keyAlias
            keyPassword = keyPass
        }
    }
}
```

- **【默认】密钥路径与口令从环境变量读，不写进 `build.gradle.kts`**。
- **【红线】CI 必须验签**：`apksigner verify --print-certs`，并显式拒绝 debug 证书（`CN=Android Debug`）。产出 unsigned 包或 debug 签名包时，宁可失败也不能发出去。

## 2. 生成 keystore（一次性）

在**仓库外的目录**执行，口令交互式输入：

```bash
keytool -genkeypair -v \
  -keystore "$HOME/<app>-keys/release.jks" \
  -alias <alias> -keyalg RSA -keysize 2048 -validity 10000
```

- `validity` 给足（10000 天约 27 年）：应用商店要求密钥有效期覆盖应用生命周期。
- 口令直接回车会沿用 keystore 口令；两个不同就分别记。
- 生成后立刻做两件事：写进密码管理器、`git status` 确认它没被加进仓库。

## 3. CI 里的四个 secret

| Secret | 内容 |
| --- | --- |
| `SIGNING_KEYSTORE_BASE64` | keystore 文件的 base64 单行文本 |
| `SIGNING_KEYSTORE_PASSWORD` | keystore 口令 |
| `SIGNING_KEY_ALIAS` | key 别名 |
| `SIGNING_KEY_PASSWORD` | key 口令（与 keystore 相同也要单独填） |

```powershell
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))
gh secret set SIGNING_KEYSTORE_BASE64 --body $b64

# 口令用安全输入，避免留在 PowerShell 历史里
$sec = Read-Host "Keystore password" -AsSecureString
gh secret set SIGNING_KEYSTORE_PASSWORD --body ([Net.NetworkCredential]::new("", $sec).Password)
```

- **【默认】流水线开头先检查四个 secret 齐备**，缺哪个报哪个名字，不要产出「看起来成功」的 unsigned 包。
- **【红线】secret 值读不回来，只能覆盖**。写之前核对变量——填错只能重新生成 keystore，回到第 0 节。

## 4. 版本号

- **【红线】`versionCode` 单调递增**。它是 Android 判断新旧的唯一依据，必须是整数；`versionName` 只给人看。
- **【默认】`versionName` 与 git tag 对齐**（tag `v1.2.3` ↔ `versionName 1.2.3`），否则用户报障时对不上号。
- **【红线】应用内更新日志是编译进 APK 的静态列表，CI 递增版本号不会替它补条目**。构建前校验「更新日志首条 == 本次要发的版本号」，不一致直接失败——否则用户装上新版，看到的还是上一版的说明。
- **【默认】版本号由 CI 从最高 tag 推导时，人不要再手改构建文件**。手改会和已发布 tag 脱节，下一次自动递增又从老值算起。
- **【红线】不复用版本号或 tag**。`gh release upload --clobber` 会让同一个版本号对应两份不同内容。
- **【红线】不做「降级安装」**：Android 不允许安装更低 `versionCode` 的包。所谓回滚，是发一个 `versionCode` 更大的旧功能版本。

## 5. 发布流水线

顺序固定，任一步失败就停：

1. 单元测试（`testDebugUnitTest`）
2. 构建 release APK（`assembleRelease`）
3. `apksigner verify` 验签，拒绝 debug 证书
4. 生成 `.sha256`
5. 校验目标 tag 未被占用
6. 创建 Release，上传 APK 与 `.sha256` 两个附件

- **【红线】先验签再上传**。顺序反了等于把未签名包推到用户手里。
- **【默认】用 `workflow_dispatch` 手动触发**；版本号可手填（跳 minor / major 时）或留空由 CI 按最高 tag + patch+1 递增。不要每次 push 都产出一个 Release。
- **【默认】发布流水线的 `concurrency` 设 `cancel-in-progress: false`**，发版不能互相打断。

## 6. 产物与校验

- 命名固定：`<App>-<versionName>-release.apk` + 同名 `.sha256`。文件名随版本变形，升级脚本就没法写。
- 用户侧校验：

```powershell
Get-FileHash .\App-1.2.3-release.apk -Algorithm SHA256
```

```bash
sha256sum -c App-1.2.3-release.apk.sha256
```

- **【红线】`sha256` 只证明字节完整，不证明来源**。身份边界是 APK 签名，由系统在安装时校验。别把 `.sha256` 当防篡改。
- **【默认】README 写清最低支持的系统版本**（`minSdk`），别让用户下载完才发现装不上。

## 7. 升级策略：先划产品红线，再谈技术

「应用内自动更新」不是技术选型，是**产品承诺**问题：它要求 `INTERNET` 权限。如果应用对外承诺过「不联网 / 数据不出设备」，加权限之前得先改承诺。

| 方案 | App 需要联网 | 用户操作 | 国内可用 | 工程量 |
| --- | --- | --- | --- | --- |
| 手动下载覆盖安装 | 不需要 | 自己找包、自己装 | 是 | 极低 |
| 应用商店（含 Play） | 不需要 | 商店提示 / 无感 | 国内需逐家上架 | 中 |
| 自建清单 + `PackageInstaller` | **需要 `INTERNET`** | 下载 → 授权 → 确认安装 | 是 | 高 |

- **【默认】分阶段**：内测期手动发 APK → 面向公众优先交商店 → 确实绕不开商店才做自更新。
- **【红线】加 `INTERNET` 或 `REQUEST_INSTALL_PACKAGES` 时，同一次改动里同步改隐私说明、README 的安全边界章节、Manifest 变更记录**。权限加了文档没改，就是文档与实现不符。
- `REQUEST_INSTALL_PACKAGES` 是敏感权限，国内商店上架通常要求说明用途。

## 8. 真要做自更新：最小设计

服务端只需要一个静态 JSON：

```json
{
  "versionCode": 2,
  "versionName": "1.1.0",
  "minSupportedVersionCode": 1,
  "apkUrl": "https://example.com/App-1.1.0-release.apk",
  "sha256": "<64 位十六进制>",
  "sizeBytes": 14217690,
  "changelog": "修复跨午夜记录日期错误",
  "force": false
}
```

- `versionCode` 是**唯一**用于比较的字段。不要拿 `versionName` 比大小：字符串比较里 `"1.10.0" < "1.9.0"`。
- `minSupportedVersionCode` 与 `force` 是两套策略，选一个，不要都实现。
- `sha256` 与 `sizeBytes` 用来挡半包和 CDN 缓存错内容。

客户端七步：

1. 读 `BuildConfig.VERSION_CODE`
2. 拉清单（带 `If-None-Match`，别每次冷启动都下 JSON）
3. 比较 `versionCode`
4. 下到 `cacheDir`，边下边算 sha256，下完比对长度与摘要
5. `packageManager.canRequestPackageInstalls()` 检查「安装未知应用」授权（API 26+）
6. `PackageInstaller` 开会话写入 APK
7. 监听 `STATUS_PENDING_USER_ACTION` 拉起系统确认界面；成功 / 失败分别上报

```kotlin
val installer = context.packageManager.packageInstaller
val params = PackageInstaller.SessionParams(
    PackageInstaller.SessionParams.MODE_FULL_INSTALL
).apply {
    setAppPackageName(context.packageName) // 包名不匹配的 APK 会被拒
}
val sessionId = installer.createSession(params)
installer.openSession(sessionId).use { session ->
    session.openWrite("base.apk", 0, apk.length()).use { out ->
        apk.inputStream().use { it.copyTo(out) }
        session.fsync(out)
    }
    session.commit(statusSender) // statusSender 来自 PendingIntent
}
```

- **【红线】别再用 `ACTION_INSTALL_PACKAGE`**：API 29 起废弃，照抄老教程必踩坑，直接用 `PackageInstaller`。
- **【默认】接受系统弹确认框**：普通应用无法静默安装（那是设备所有者 / 系统应用的能力）。弹框是正常流程，不是失败。
- **【默认】每次都要重新检查授权**：用户随时可能在系统设置里关掉「安装未知应用」。

### 版本可用 ≠ 制品可用

第三方 `latest` 返回的是「发布意图」，不是「可下载事实」：Release 可能刚建好、附件还在逐个上传，或附件根本没传成功。

- **【红线】客户端必须区分三态**：**没拿到版本信息** / **有版本但制品未就绪（可重试）** / **源不可用**。三者的文案与交互不能混用；最糟的中间态是「提示有新版本，却没有下载按钮」或「点下去在下另一个源的包」。
- **【默认】就绪判据取「最后上传的那个文件」**：`assets` 同时含安装包与 `.apk.sha256` 才算就绪（校验文件后传，可当完成标记）。未就绪就退避重查，别因此回退到更差的源。
- **【红线】「暂时没准备好」不能和「源不可用」共用一个兜底分支**。共用会把用户导流去跨境下载几十 MB，比「检查不到更新」更糟。
- **【默认】唯一主源 / 唯一分发通道的替换，第一次单独发一版灰度验证**，不与功能发布捆在一起——新链路的写入步骤从没在真实 CI 跑过，第一次失败概率最高。
- **【默认】判断「有没有新版本」的请求不走任何可缓存层**：文件 CDN 的 `raw` 路径缓存时长不可控，加时间戳并 `useCaches = false`，否则发完版客户端可能长时间读到旧版本。

## 9. 发布前检查清单

- [ ] 四个签名 secret 齐备，keystore 有离机备份
- [ ] `versionCode` 递增，`versionName` 与 tag 一致
- [ ] 应用内更新日志首条 == 本次版本号
- [ ] `./gradlew :app:testDebugUnitTest :app:assembleDebug` 本地通过
- [ ] 改了表：`version` 已升、`Migration` 已写、迁移测试通过、schema 已入库
- [ ] 真机做过一次「旧版 → 新版」覆盖安装，数据完整
- [ ] 流水线验签通过，没有 debug 证书
- [ ] Release 附件可下载，本地 `Get-FileHash` 或 `sha256sum -c` 与 `.sha256` 一致
- [ ] 上一版客户端实机点一次「检查更新」：能看到新版本，且点下去真能下、能装上
- [ ] README / CHANGELOG / 文档里的版本号已同步
- [ ] 回滚方案已写：发一个更高 `versionCode` 的回退版本

## 10. 高频坑

| 现象 | 原因 |
| --- | --- |
| 覆盖安装报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 新旧包签名不一致：换过 keystore，或发出去的是 debug 包 |
| 升级后一启动就崩，日志是 `Room cannot verify the data integrity` | 改了表没写 `Migration` |
| Release 里是 unsigned 包 | 签名环境变量缺失却没拦住，流水线没有验签步骤 |
| 用户装完发现还是旧版本 | `versionCode` 忘了递增，Android 不认为这是新包 |
| 自更新下载完装不上 | 没申请 `REQUEST_INSTALL_PACKAGES`，或用户关了「安装未知应用」 |
| 同一版本两台机器内容不同 | 复用了 tag + `--clobber` 覆盖附件 |
