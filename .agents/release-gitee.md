# Gitee Release 镜像规范

**加载时机**：把 GitHub Release 的产物同步到 Gitee、给现有发布 workflow 加镜像 job、调 Gitee OpenAPI 建 Release / 传附件、镜像失败后补传。
**边界**：本模块只管**发布产物的国内分发**。版本号、tag 与回滚策略由项目自己的发布规范决定；镜像怎么构建、怎么分层不在这里。完整 workflow 模板、参数表与两种系统的人工补传脚本，见规范仓库的《Gitee Release 同步操作手册》。

## 0. 动手前

- **【红线】先读现有发布 workflow**。镜像 job 用 `needs:` 挂在唯一的发布 job 后面，不要另起一条会打 tag 的流水线；两条并发会撞版本号。
- **【默认】先确认分工**：GitHub Releases 是权威发布源，Gitee Releases 只是分发镜像。只要用户会去下载产物，就必须做 L2 + L3（见第 1 节），不能只配仓库镜像。
- **【默认】令牌、owner、repo、默认分支先核对一遍**再改 CI。参数以项目自己的配置为准，不凭记忆填。

## 1. 三层同步对象：别把「仓库镜像」当发布同步

| 层 | 内容 | 谁负责 |
| --- | --- | --- |
| L1 代码 | 分支、提交、tag | `git push` 双远端 / 平台仓库镜像 |
| L2 Release 元数据 | 版本号、标题、说明、关联分支 | 网页或 OpenAPI 创建 |
| L3 Release 附件 | 安装包、zip、jar、`.sha256` | 网页上传或 OpenAPI `attach_files` |

- **【红线】平台仓库镜像只覆盖 L1，不含 Release 附件**。配好之后分支和 tag 都过去了、用户却下载不到包，就是把它当成了发布同步。
- **【默认】分发链路真正要的是 L2 + L3**。只要求「国内能下载到包」时，L1 可以完全不做：Gitee 建一个公开空仓库、初始化默认分支即可，`target_commitish` 指向它。
- **【默认】方案选型**：一年发一两次的试验项目可纯手工；任何需要持续国内分发的项目用 **CI 复用 artifact + 调 OpenAPI**（第 5 节）。双远端 / 仓库镜像 + 网页补附件都会漏 L3，且不能保证两端同一份字节。

## 2. 三条硬原则

1. **【红线】产物只构建一次**。镜像端绝不重新构建，否则签名、时间戳、哈希都可能偏差。CI 里用 `upload-artifact` / `download-artifact` 传同一份；人工补传时从**已发布的 GitHub Release** 下载，不要本地再打一次包。
2. **【红线】先自检再写入，写完要验返回体**。调 API 前查令牌、产物、同名 Release；每次写入后解析 `id` / `browser_download_url`，缺失就报错退出。只判断 HTTP 200 不算成功。
3. **【红线】不复用 tag、不覆盖同名 Release**。同名一律拒绝，回退靠发更高版本号，不靠 `--clobber` 或删了重建。

- **【红线】凭据不进 workflow、README、文档、命令行历史或提交记录**。令牌只放 Secrets，文档里一律 `<your-token>`，本地自检用交互式读取。
- **【红线】镜像失败不回滚、不重跑整个 workflow**。GitHub 侧已发布成功，重跑必然撞同名 tag；只补镜像这一步（第 7 节）。
- **【建议】校验文件与主产物一起传**，两端用 `.sha256` 证明字节一致，别只比文件名和大小。

## 3. 一次性准备

- **【默认】Gitee 建公开仓库**：私有仓库的附件下载通常要登录，不适合分发。初始化默认分支即可，不要求把代码推过去。
- **【默认】默认分支名显式配置**（常见 `master`，手动选 `main` 就要写对）。默认分支与 GitHub 不一致时 `target_commitish` 会关联失败，报 404。
- **【默认】私人令牌只勾 `projects`**，设有效期并记轮换提醒。先用 `/api/v5/user` 自检返回预期登录名，再配进 CI。
- **【默认】Secret / Variable 分开**：令牌进 Secret，owner / repo / 默认分支进 Variables，换仓库不用改 workflow。
- **【默认】最小权限**：发布 job `contents: write`；镜像 job `contents: read` + `actions: read`（要下载 artifact）；客户端读公开 Release 不需要令牌。

## 4. 每次发版

1. 版本号递增、tag 与产物版本一致、目标 tag 两端都不存在；本地构建 / 测试 / lint 通过，产物已验签并生成 `.sha256`。
2. 触发唯一的发布 workflow：发布 job 上传 artifact + 创建 GitHub Release（权威）。
3. 镜像 job（`needs:` 发布 job）下载**同一份** artifact：检查配置与产物 → 列出已有 Release 并拒绝同名 → 创建 Gitee Release → 逐个上传附件并校验 `browser_download_url`。
4. 按第 8 节验证。**【红线】不凭「流水线绿了」宣布发布成功**。

- **【默认】镜像 job 不设 `continue-on-error`**：失败即标红，让「国内镜像缺失」看得见。只有 Gitee 确实是可有可无的备份时才允许设，且必须打明确日志。
- **【默认】镜像失败的处置策略写进项目发布文档**，别让值班的人临场猜。

## 5. workflow 骨架的关键点

自己写镜像 job 时必须包含（完整可搬的模板见操作手册）：

- `needs: <发布 job>` + `download-artifact`：保证两端同一份字节。
- 配置自检：令牌为空、artifact 为空、产物 glob 不匹配（含 `.sha256`）任一命中就 `exit 1`。
- 幂等：先 `GET /releases` 确认返回是数组，再拒绝同名；Release 超过单页数量时要翻页或定期清理，否则漏判。
- 创建后解析 `id` 判空；上传后解析 `browser_download_url` 判空。
- `target_commitish` 显式写配置的分支变量，不依赖默认值；tag 表达式按触发方式改（`inputs.version` 或 `github.ref_name`）。
- 产物目录只放主产物与校验文件，别把日志、报告混进去。

## 6. API 速查

基址 `https://gitee.com/api/v5/repos/{owner}/{repo}/releases`（官方参数以 API 文档为准）。

| 动作 | 方法与路径 | 关键点 |
| --- | --- | --- |
| 列出 Release | `GET /releases` | `access_token`、`page`、`per_page`；幂等检查靠它 |
| 创建 Release | `POST /releases` | `tag_name` / `name` / `body` / `target_commitish` 必填，`prerelease` 用小写 `false` / `true` |
| 上传附件 | `POST /releases/{release_id}/attach_files` | multipart `file`；返回 `browser_download_url` 才算成功 |
| 最新 Release | `GET /releases/latest` | 返回**最后创建**的，不是语义版本最高的 |
| 令牌自检 | `GET https://gitee.com/api/v5/user` | 完整路径，不含 repos 前缀 |

- **【默认】`latest` 不能当版本排序用**：平台没有「设为 latest」的 API，别补发旧版本；客户端自己再比一次版本号并保留 GitHub 回退链路。
- **【默认】按状态码定位**：`401` 令牌无效 / 过期，`404` owner/repo 写错或令牌无该仓库权限，`422` 同名 tag 或参数不合法，`413` 附件超限。
- **【默认】额度按官方帮助页实测**：单附件与仓库附件总量都有限额，总量含仓库附件；接近上限时清理旧 Release 附件，别把产物提交进 git。

## 7. 失败兜底：只补镜像

**触发条件**：GitHub Release 已创建成功，镜像 job 失败（令牌过期、限流、上传超时、附件超限等）。

- **【红线】不重跑整个 workflow、不删 GitHub Release 重发、不本地重新构建**。版本号一经发布就不可复用。
- **【默认】从已发布的 GitHub Release 或该次 Actions run 的 artifact 下载产物**，再按第 5 节的顺序手动建 Release、传附件、验下载地址，最后用 `.sha256` 核对完整性。
- **【默认】PowerShell 里必须写 `curl.exe`**：`curl` 是 `Invoke-WebRequest` 的别名，不支持 `-F` / `--data-urlencode`。
- **【默认】API 始终失败时走网页手工上传**：填与 GitHub 相同的 tag 与标题，选对分支，把产物和校验文件一起拖进去，并在发布记录里注明「人工补传」。
- **【默认】令牌轮换后**：更新 Secret → `/api/v5/user` 自检 → 触发一次补传验证。

## 8. 验证（两端各查一遍）

- [ ] 两端 Release 同名 tag，附件文件名与数量一致，均可下载
- [ ] 两端哈希一致且与 `.sha256` 相符；需要签名的产物证书指纹一致
- [ ] `GET /releases/latest` 返回的 `tag_name` 是本次版本且带附件
- [ ] 客户端「检查更新」命中镜像源并能调起安装器；镜像不可用时能回退 GitHub

- **【默认】未验证项如实记录**：CI 只保证附件上传成功，下载 URL 在真实国内网络下能否免登录直连，要首次发版后真机端到端验证。
- **【建议】客户端拒绝 `text/html` 响应**并校验文件魔数与最小体积——私有仓库或登录态过期时会下载到登录页。

## 9. 回滚与约束

- **【默认】不删 tag、不覆盖附件、不复用版本号**。回退靠发更高版本号的回退版本，别让用户降级安装。
- **【默认】同步失败不回滚 GitHub Release**：镜像缺失只是分发缺口，补传即可。
- **【默认】定期清理旧 Release 的附件**（tag 保留），删除前确认没有用户仍依赖该版本。
- **【默认】签名密钥不随镜像流程轮换**：换密钥意味着用户卸载重装，非必要不动。

## 10. 高频坑（反例清单）

| 现象 | 根因 | 修复 / 教训 |
| --- | --- | --- |
| 仓库镜像配好了，代码和 tag 都过去，附件却没有 | 平台镜像只同步 L1 | 附件必须由 CI 调 API 单独上传；「镜像仓库」≠「镜像发布产物」 |
| `releases/latest` 返回旧版本 | latest 是「最后创建」，不是版本最高 | 按版本递增正常发版、不补发旧版本；客户端自己比一次版本号 |
| 建 Release 报 404 / 关联失败 | owner/repo 写错，或把 GitHub 的 `main` 当成 Gitee 默认分支 | 显式配置分支变量；先 `GET /releases` 确认仓库可访问 |
| 建 Release 报 422 | 同名 tag 已存在，或 `prerelease` 写成 `False` / `1` | 拒绝覆盖；布尔值用小写 `false` / `true` |
| 上传返回 200 但页面看不到附件 | 只判断状态码，没解析返回体 | 以 `browser_download_url` 为成功凭据，缺失就报错退出 |
| 上传 401 / 413 | 令牌过期或权限不足 / 超出附件额度 | 轮换令牌并确认 `projects`；拆包或清理旧 Release 附件 |
| PowerShell 里 `curl -F` 报参数错误 | `curl` 是 `Invoke-WebRequest` 别名 | 一律写 `curl.exe` |
| 下载到的是登录页而不是安装包 | 私有仓库 / 未登录时网关返回 HTML | 用公开仓库；客户端校验魔数与最小体积 |
| 镜像失败后重跑整个 workflow | 以为「重试一次就好」 | GitHub 侧已发布，重跑必撞 tag；只补镜像这一步 |
| Release 超过单页数量后幂等检查失效 | 列出接口只取了第一页 | 翻页或定期清理旧 Release |
| 两端哈希不一致 | 镜像端重新构建或人工传错包 | 只复用同一份 artifact |
| 产物目录混入日志、报告 | `for file in dist/*` 全量上传 | 上传前限定产物与校验文件，构建垃圾不进 artifact |

## 11. 迁移到新项目的 Checklist

1. [ ] 明确分工：GitHub 为权威源，Gitee 只做分发镜像；确认代码是否需要同步（不需要就别配仓库镜像）。
2. [ ] 建公开仓库并初始化默认分支，记录 owner / repo / 分支名。
3. [ ] 生成只含 `projects` 权限的令牌，存密码管理器并设轮换提醒；配 Secret 与 Variables，自检通过。
4. [ ] 确认发布 workflow 唯一，镜像 job 用 `needs` 挂在后面。
5. [ ] 发布 job 把产物 + `.sha256` 打成 artifact；镜像 job 下载同一份。
6. [ ] 替换 job id / artifact 名 / 产物 glob，按触发方式改好 tag 表达式。
7. [ ] 补齐自检：令牌非空、产物存在、同名 Release 不存在、`id` 与 `browser_download_url` 判空。
8. [ ] 明确镜像失败的告警策略与人工补传步骤，写进项目发布文档。
9. [ ] 客户端若依赖 `releases/latest`，自己做版本号比较兜底并保留 GitHub 回退链路。
10. [ ] 核对产物大小与附件额度，定下旧 Release 清理节奏。
11. [ ] 首次发版后按第 8 节做两端验证 + 真机端到端验证，把未验证项如实记进发布记录。
