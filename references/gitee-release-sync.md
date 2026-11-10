# GitHub Release 产物同步到 Gitee：通用流程与操作手册

> 适用场景：以 GitHub Releases 为权威发布源、以 Gitee Releases 为国内分发镜像的开源项目。
> 适用产物：APK / zip / jar / 静态包 / 安装包 + `.sha256` 校验文件。API 与额度核对日期 2026-11-10。
> 配套规范：[`.agents/release-gitee.md`](../.agents/release-gitee.md) 是装进目标项目的规则条目；本文件是留在规范仓库的完整操作手册，不装进目标项目。

**30 秒结论**：不要指望「仓库镜像」把发布包带过去。Gitee 的仓库镜像只同步分支、标签、提交记录，**Release 附件不在同步范围内**。正确做法是：GitHub 侧只构建一次 → 把产物作为 CI artifact 复用 → 在同一个发布 workflow 里加一个镜像 job，调 Gitee OpenAPI 创建同名 Release 并上传附件。两端拿到的是同一份字节，不是重新构建出来的「另一份包」。

---

## 0. 这份文档怎么用

- 第 1–3 节是**认知与选型**，决定你这个项目该用哪套方案。
- 第 4–5 节是**标准操作流程**：一次性准备 + 每次发版，照做即可。
- 第 6 节是**可直接搬走的 workflow 模板**，配第 6.2 节的参数替换表套到新项目。
- 第 7–8 节是**API 速查与失败兜底**，同步 job 挂了时用。
- 第 9–12 节是**验证、坑、回滚、迁移 Checklist**，换项目时逐项过一遍。

文中 `<...>` 是参数占位符，6.2 节给出替换规则。令牌、口令一律用 `<your-token>` 代指，实际操作时用交互式输入从密码管理器取，绝不写进任何文件、命令行历史或提交记录。

---

## 1. 先分清三层同步对象

「同步到 Gitee」其实是三件互相独立的事，混在一起是最常见的翻车原因：

| 层 | 内容 | 常见手段 | 是否等于「发布包同步」 |
|---|---|---|---|
| L1 代码 | 分支、提交、tag | `git push` 双远端、Gitee 仓库镜像 | 否 |
| L2 Release 元数据 | 版本号、标题、说明、关联分支 | Gitee 网页 / OpenAPI 创建 | 否 |
| L3 Release 附件 | APK、zip、jar、安装包、`.sha256` | Gitee 网页上传 / OpenAPI `attach_files` | **是** |

结论：

- **Gitee 官方仓库镜像只覆盖 L1**。配好之后分支和 tag 都过去了，用户却下载不到包，就是这个原因（配套规范第 10 节的反例清单里有记录）。
- 分发链路真正要的是 **L2 + L3**，必须自己调 API 或手工上传。
- 如果只需要「国内能下载到包」，**L1 可以完全不做**：Gitee 建一个空公开仓库、初始化默认分支即可，`target_commitish` 指向这个分支就够了，代码不必落地 Gitee。

---

## 2. 方案选型

| 方案 | 做法 | 优点 | 代价 | 适用 |
|---|---|---|---|---|
| A 纯手工 | 网页新建 Release、拖文件上传 | 零配置 | 每次发版易漏、易传错包、无法保证两端同一份字节 | 一年发一两次的试验项目 |
| B 双远端 + 手工 | `git remote add gitee` 推代码和 tag，网页补附件 | 代码同步自动化 | L3 仍是手工；要维护两套远端凭据 | 只做代码备份，不做分发 |
| C Gitee 仓库镜像 + 手工 | 平台自动同步 L1，网页补 L3 | L1 全自动 | 仍解决不了附件；容易误以为「已经同步好了」 | 只要求代码可见 |
| **D GitHub Actions + Gitee OpenAPI（推荐）** | 复用同一份 CI artifact，自动建 L2 并上传 L3 | 字节一致、可校验、可幂等、失败有明确日志 | 需配一个令牌和几个变量 | **任何需要持续国内分发的项目** |

选型要点：

- 只要用户会去下载产物，就选 D；A/C 只适合没有分发需求的场景。
- D 不建议拆成「另一条独立流水线」：同一仓库只允许一条流水线打 tag，两条并发会撞版本号。镜像 job 用 `needs: <发布 job>` 挂在现有发布 workflow 后面。
- 产物类型不影响选型：镜像 job 只认 artifact 目录，换产物只需改产物 glob 与发布 job 的构建命令。

---

## 3. 端到端流程总览

```text
[一次性准备]
  Gitee 建公开空仓库 → 生成私人令牌(projects) → 存进 GitHub Secrets / Variables
        ↓
[每次发版]
  改版本号并提交 → 手动触发发布 workflow
        ↓
  Job A: 测试 / lint / 构建 / 验签 / 生成 .sha256
        ↓
  Job A: 上传产物为 artifact  +  创建 GitHub Release（权威）
        ↓
  Job B (needs: A): 下载同一份 artifact
        ↓
  Job B: 检查令牌/产物/同名 Release → 调 API 建 Gitee Release → 逐个上传附件 → 校验 download_url
        ↓
[验证] 两端附件齐全 → 哈希一致 → 客户端 latest 命中 → 下载链路可用
        ↓
[异常] Job B 失败：GitHub 已发布成功，不重跑、不重打 tag，按第 8 节人工补传
```

三条硬原则：

1. **产物只构建一次**。镜像端绝不重新构建，否则签名、时间戳、哈希都可能出现偏差。CI 里优先用 `actions/upload-artifact` + `actions/download-artifact` 传递，人工兜底时从已发布的 GitHub Release 下载，而不是本地再打一次包。
2. **先自检再写入**。每次调 API 前检查令牌、产物存在、同名 Release 不存在；每次写入后检查返回结构（`id` / `browser_download_url`），失败立刻退出，不要「上传完当成成功」。
3. **不复用 tag**。同名 Release 一律拒绝覆盖，回退靠发更高版本号，不靠 `--clobber` 或删了重建。

---

## 4. 一次性准备（只做一次）

### 4.1 建 Gitee 仓库

1. 在 Gitee 新建**公开**仓库（私有仓库的附件下载通常需要登录，不适合分发）。
2. 初始化默认分支即可，**不需要把代码推过去**。记下默认分支名：Gitee 新建仓库常见为 `master`，若你手动选的是 `main`，后面 `target_commitish` 必须显式写对，否则建 Release 会关联失败。
3. 记下 `owner` 与 `repo`，后面所有 API 路径都用这两个值。

### 4.2 生成私人令牌

1. Gitee → 设置 → 私人令牌 → 生成新令牌。
2. 权限只勾 `projects`（创建 Release、上传附件所需的最小范围），不要给全部权限。
3. 设有效期并记进日历提醒轮换；令牌明文只放密码管理器，**绝不写进 workflow、文档、README、聊天或提交历史**。
4. 自检令牌是否有效（返回自己的登录名即通过）。用交互式读取，避免令牌进 shell 历史：

```bash
read -rsp 'Gitee token: ' GITEE_TOKEN; echo
curl -sS "https://gitee.com/api/v5/user?access_token=${GITEE_TOKEN}" | jq -r '.login'
unset GITEE_TOKEN
```

### 4.3 在 GitHub 仓库配置 Secrets / Variables

`Settings → Secrets and variables → Actions`：

| 类型 | 名称 | 值 | 说明 |
|---|---|---|---|
| Secret | `GITEE_TOKEN` | `<your-token>` | 唯一必须保密的项 |
| Variable | `GITEE_OWNER` | `<gitee-owner>` | 用 Variables 而非写死，换仓库不用改 workflow |
| Variable | `GITEE_REPO` | `<gitee-repo>` | 同上 |
| Variable | `GITEE_BRANCH` | `main` / `master` | 必须与 4.1 的默认分支一致 |

用 `gh` CLI 配置（Secret 走 stdin，令牌不出现在命令行历史里）：

```bash
read -rsp 'Gitee token: ' TOKEN; echo
printf '%s' "$TOKEN" | gh secret set GITEE_TOKEN --repo <gh-owner>/<gh-repo>
unset TOKEN

gh variable set GITEE_OWNER --repo <gh-owner>/<gh-repo> --body '<gitee-owner>'
gh variable set GITEE_REPO  --repo <gh-owner>/<gh-repo> --body '<gitee-repo>'
gh variable set GITEE_BRANCH --repo <gh-owner>/<gh-repo> --body 'main'

gh secret list --repo <gh-owner>/<gh-repo>   # 确认已写入；值不可再读出，只能覆盖
```

### 4.4 权限清单

| 位置 | 权限 | 用途 |
|---|---|---|
| 发布 job | `contents: write` | 创建 GitHub Release |
| 镜像 job | `contents: read` + `actions: read` | 读代码 / 下载 artifact |
| Gitee 令牌 | `projects` | 创建 Release、上传附件 |
| 客户端读取 | 无需令牌 | 公开仓库的 `releases/latest` 匿名可读 |

---

## 5. 每次发版的标准操作

以下按 `workflow_dispatch` 手动触发方式描述；若你的项目是「推 tag 触发」，把第 3–4 步换成 `git tag -a vX.Y.Z -m "Release vX.Y.Z" && git push origin vX.Y.Z`，其余不变。

1. **改版本号**：内部版本号单调递增，对外版本名与 tag 严格一致（`v` + 版本名）。改过数据库 schema 时先备好 Migration。同步更新 `README.md` 与发布文档里的版本号。
2. **本地门禁**：跑项目自己的构建 + 测试 + lint，例如 `./gradlew :app:testDebugUnitTest :app:lintDebug :app:assembleRelease`。
3. **提交并推送到主分支**（发布流水线以触发时的代码为准）。
4. **触发发布**：`Actions → Release → Run workflow`，填 `version`，格式 `vX.Y.Z`。
5. **发布 job 依次做**：校验 tag 格式与未被占用 → 校验签名配置齐备 → 构建与验签（拒绝 unsigned / debug 证书）→ 生成 `.sha256` → 上传 artifact → 创建 GitHub Release 并挂附件。
6. **镜像 job 接着做**（`needs: 发布 job`）：下载同一份 artifact → 检查令牌与产物 → 列出已有 Release 并拒绝同名 → 创建 Gitee Release → 逐个上传附件并校验 `browser_download_url`。
7. **按第 9 节验证**。不要以「流水线绿了」作为发布成功的证据。

关于镜像 job 失败的处理策略（两种都可行，选一种写进项目文档）：

| 策略 | 后果 | 建议 |
|---|---|---|
| 不设 `continue-on-error`，失败即 workflow 标红 | GitHub 侧已发布成功，但国内镜像缺失这件事**看得见** | **推荐**：分发完整性优先，且日志能直接定位 |
| 设 `continue-on-error: true` 并打明确日志 | 主链路不红，但镜像缺失容易被忽略 | 仅在 Gitee 只是「可有可无的备份」时用 |

无论哪种，**GitHub Release 都不会被回滚**，同步失败一律按第 8 节补传，绝不重跑整个 workflow（会撞同名 tag）。

---

## 6. 可复用的 workflow 模板

### 6.1 镜像 job（挂在你现有的发布 workflow 后面）

这是给新项目套用的参数化骨架，`<...>` 按 6.2 节替换。挂到现有发布 workflow 里，不要另起一条打 tag 的流水线。

```yaml
  mirror-gitee:
    name: Mirror release to Gitee
    needs: <RELEASE_JOB_ID>            # 挂到现有发布 job 后面，不要另起一条打 tag 的流水线
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
    env:
      TAG: ${{ inputs.version }}       # 手动触发；若用 tag 触发改为 ${{ github.ref_name }}
      GITEE_TOKEN: ${{ secrets.GITEE_TOKEN }}
      GITEE_OWNER: ${{ vars.GITEE_OWNER }}
      GITEE_REPO: ${{ vars.GITEE_REPO }}
      GITEE_BRANCH: ${{ vars.GITEE_BRANCH || 'master' }}
    steps:
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: <ARTIFACT_NAME>
          path: dist

      - name: Check configuration and artifacts
        run: |
          set -euo pipefail
          if [ -z "${GITEE_TOKEN}" ]; then echo "::error::Missing secret: GITEE_TOKEN"; exit 1; fi
          if ! find dist -maxdepth 1 -type f | grep -q .; then
            echo "::error::Artifact is empty"; exit 1
          fi
          # 改成你的产物 glob；校验文件也要一起传
          for pattern in '<ASSET_GLOB>' '<ASSET_GLOB>.sha256'; do
            if ! find dist -maxdepth 1 -type f -name "$pattern" | grep -q .; then
              echo "::error::Missing asset matching $pattern"; exit 1
            fi
          done

      - name: Create Gitee release and upload attachments
        run: |
          set -euo pipefail
          API="https://gitee.com/api/v5/repos/${GITEE_OWNER}/${GITEE_REPO}/releases"

          # 幂等：先列出，同名一律拒绝；返回不是数组说明令牌/权限有问题
          existing=$(curl -sS "${API}?access_token=${GITEE_TOKEN}&page=1&per_page=100")
          if ! printf '%s' "$existing" | jq -e 'type == "array"' > /dev/null; then
            echo "::error::Cannot list Gitee releases: $existing"; exit 1
          fi
          if printf '%s' "$existing" | jq -e --arg tag "$TAG" 'any(.[]; .tag_name == $tag)' > /dev/null; then
            echo "::error::Gitee release $TAG already exists; refusing to overwrite"; exit 1
          fi

          created=$(curl -sS -X POST "$API" \
            --data-urlencode "access_token=${GITEE_TOKEN}" \
            --data-urlencode "tag_name=${TAG}" \
            --data-urlencode "name=${TAG}" \
            --data-urlencode "body=Mirror of https://github.com/${GITHUB_REPOSITORY}/releases/tag/${TAG}" \
            --data-urlencode "target_commitish=${GITEE_BRANCH}" \
            --data-urlencode "prerelease=false")
          release_id=$(printf '%s' "$created" | jq -r '.id // empty')
          if [ -z "$release_id" ]; then
            echo "::error::Gitee release creation failed: $created"; exit 1
          fi
          echo "Created Gitee release id=$release_id for $TAG"

          for file in dist/*; do
            [ -f "$file" ] || continue
            response=$(curl -sS -X POST "${API}/${release_id}/attach_files" \
              -F "access_token=${GITEE_TOKEN}" \
              -F "file=@${file}")
            url=$(printf '%s' "$response" | jq -r '.browser_download_url // empty')
            if [ -z "$url" ]; then
              echo "::error::Attachment upload failed for $(basename "$file"): $response"; exit 1
            fi
            echo "Uploaded $(basename "$file"): $url"
          done
          echo "Mirror complete: https://gitee.com/${GITEE_OWNER}/${GITEE_REPO}/releases/tag/${TAG}"
```

模板里几个不能省的设计：

- `needs` + artifact 传递：保证两端同一份字节。
- 列出再创建：同名拒绝，避免重跑覆盖；**Release 超过 100 个时 `per_page=100` 会漏判**，要么翻页、要么定期清理旧 Release。
- 每次上传校验 `browser_download_url`：只有返回了下载地址才算成功。
- `target_commitish` 显式指定：不要依赖默认值。
- 不在 workflow 里写任何令牌明文，全部走 Secrets。

### 6.2 参数替换表

| 占位符 | 含义 | 替换规则 / 示例值 |
|---|---|---|
| `<RELEASE_JOB_ID>` | 现有发布 job 的 id | 例：`release` |
| `TAG` 表达式 | tag 来源 | `${{ inputs.version }}`（手动填版本号）；推 tag 触发则改为 `${{ github.ref_name }}` |
| `<ARTIFACT_NAME>` | 发布 job 上传的 artifact 名 | 例：`release-assets` |
| `<ASSET_GLOB>` | 主产物文件名匹配 | 例：`app-*-release.apk` / `*.zip` |
| `<gh-owner>/<gh-repo>` | GitHub 仓库 | 例：`<your-org>/<your-repo>` |
| `<gitee-owner>/<gitee-repo>` | Gitee 仓库 | 例：`<gitee-owner>/<gitee-repo>` |
| `GITEE_BRANCH` | Gitee 默认分支 | `master` / `main`，以 4.1 记下的为准 |
| `GITEE_TOKEN` | 私人令牌 | 同名 Secret，值不公开 |

若产物不是 APK（zip / jar / 静态包 / 安装包），只需换 `<ASSET_GLOB>` 和发布 job 的构建命令，镜像 job 完全不用改；附件有多个时保持 `for file in dist/*` 即可，注意目录里不要混入日志、报告等构建垃圾。

---

## 7. Gitee OpenAPI 速查

基址：`https://gitee.com/api/v5/repos/{owner}/{repo}/releases`（官方参数以 [API 文档](https://gitee.com/api/v5/swagger) 为准，2026-11-10 核对）。

| 动作 | 方法与路径 | 关键参数 |
|---|---|---|
| 列出 Release | `GET /releases` | `access_token`、`page`、`per_page` |
| 创建 Release | `POST /releases` | `access_token`、`tag_name`、`name`、`body`、`target_commitish`、`prerelease` |
| 上传附件 | `POST /releases/{release_id}/attach_files` | `access_token`、`file`（multipart） |
| 最新 Release | `GET /releases/latest` | `access_token`（公开仓库可省略） |
| 令牌自检 | `GET https://gitee.com/api/v5/user`（完整路径，不含 repos 前缀） | `access_token` |

细节与约束：

- 创建 Release 时 `tag_name` / `name` / `body` / `target_commitish` 都是必填；`prerelease` 用小写 `false` / `true`。
- 创建返回 JSON 里的 `id` 是后续上传附件用的 `release_id`，必须解析出来并判空。
- 上传附件返回 `browser_download_url`，把它当成「上传成功」的唯一凭据；只判断 HTTP 200 不够。
- `releases/latest` 返回的是**最后创建**的 Release，不是语义版本最高的一个。平台没有「设为 latest」的 API，所以不要补发旧版本；客户端应自己再比一次版本号兜底。
- 常见状态码：`401` 令牌无效 / 过期，`404` owner 或 repo 写错、令牌无该仓库权限，`422` 同名 tag 或参数不合法，`413` 附件超限。

附件额度（[官方帮助页](https://help.gitee.com/repository/release/create)，2026-11-10 核对）：单附件与仓库附件总量都有限额，且总量统计包含仓库附件与 Release 附件；推荐项目 / GVP 有更高分档。额度会调整，接近上限时以官方帮助页为准并实测，项目文档里若记过旧分档，按官方页优先。长期发版要定期清理旧 Release 的附件，别把安装包提交进 git（git 单文件与单仓上限更低）。

---

## 8. 失败兜底：人工补传

**触发条件**：GitHub Release 已创建成功，`mirror-gitee` 失败（令牌过期、限流、上传超时、附件超限等）。

**前置纪律**：

- 不要重跑整个 workflow，会撞同名 tag 并失败在第一步。
- 不要删掉 GitHub Release 重发；版本号一经发布就不可复用。
- 从**已发布的 GitHub Release** 下载产物，或从该次 Actions run 的 artifact 下载，不要本地重新构建。

### 8.1 Git Bash / Linux / macOS（curl + jq，与 CI 一致，优先用这套）

```bash
read -rsp 'Gitee token: ' GITEE_TOKEN; echo   # 交互输入，不进 shell 历史
OWNER='<gitee-owner>'
REPO='<gitee-repo>'
TAG='vX.Y.Z'
BRANCH='main'
GH_REPO='<gh-owner>/<gh-repo>'
API="https://gitee.com/api/v5/repos/${OWNER}/${REPO}/releases"

# 0. 令牌自检
curl -sS "https://gitee.com/api/v5/user?access_token=${GITEE_TOKEN}" | jq -r '.login'

# 1. 下载 GitHub 侧已发布的产物（需要 gh 已登录）
mkdir -p dist
gh release download "$TAG" --repo "$GH_REPO" --dir dist
ls -l dist

# 2. 同名 Release 检查
existing=$(curl -sS "${API}?access_token=${GITEE_TOKEN}&page=1&per_page=100")
printf '%s' "$existing" | jq -e 'type == "array"' > /dev/null || { echo "ERROR: cannot list releases"; exit 1; }
if printf '%s' "$existing" | jq -e --arg tag "$TAG" 'any(.[]; .tag_name == $tag)' > /dev/null; then
  echo "ERROR: release $TAG already exists; do not overwrite"; exit 1
fi

# 3. 创建 Gitee Release
created=$(curl -sS -X POST "$API" \
  --data-urlencode "access_token=${GITEE_TOKEN}" \
  --data-urlencode "tag_name=${TAG}" \
  --data-urlencode "name=${TAG}" \
  --data-urlencode "body=Mirror of https://github.com/${GH_REPO}/releases/tag/${TAG}" \
  --data-urlencode "target_commitish=${BRANCH}" \
  --data-urlencode "prerelease=false")
release_id=$(printf '%s' "$created" | jq -r '.id // empty')
[ -n "$release_id" ] || { echo "ERROR: create failed: $created"; exit 1; }

# 4. 逐个上传附件
for file in dist/*; do
  [ -f "$file" ] || continue
  response=$(curl -sS -X POST "${API}/${release_id}/attach_files" \
    -F "access_token=${GITEE_TOKEN}" \
    -F "file=@${file}")
  url=$(printf '%s' "$response" | jq -r '.browser_download_url // empty')
  [ -n "$url" ] || { echo "ERROR: upload failed for $(basename "$file"): $response"; exit 1; }
  echo "Uploaded $(basename "$file"): $url"
done

# 5. 用 GitHub 侧生成的校验文件核对产物完整性
#    依赖 GNU sha256sum 格式「<hash>  <filename>」；若你的校验文件只存哈希，改为手工比对
(cd dist && sha256sum -c ./*.sha256)
unset GITEE_TOKEN
```

### 8.2 Windows PowerShell（用 `curl.exe`，不要写 `curl`）

`curl` 在 PowerShell 里是 `Invoke-WebRequest` 的别名，不支持 `-F` / `--data-urlencode`；必须显式写 `curl.exe`（Windows 10 1803+ 自带，或自行安装）。multipart 交给 curl.exe 处理，比用 `Invoke-RestMethod` 手工拼 boundary 稳得多。

```powershell
$sec   = Read-Host "Gitee token" -AsSecureString
$token = [Net.NetworkCredential]::new('', $sec).Password
$owner  = '<gitee-owner>'
$repo   = '<gitee-repo>'
$tag    = 'vX.Y.Z'
$branch = 'main'
$ghRepo = '<gh-owner>/<gh-repo>'
$api    = "https://gitee.com/api/v5/repos/$owner/$repo/releases"
$dist   = Join-Path $PWD 'dist'

# 0. 令牌自检
(curl.exe -sS "https://gitee.com/api/v5/user?access_token=$token" | ConvertFrom-Json).login

# 1. 下载 GitHub 产物
New-Item -ItemType Directory -Force -Path $dist | Out-Null
gh release download $tag --repo $ghRepo --dir $dist
Get-ChildItem -File $dist | Select-Object Name, Length

# 2. 同名 Release 检查
$existing = curl.exe -sS "${api}?access_token=${token}&page=1&per_page=100" | ConvertFrom-Json
if ($existing | Where-Object { $_.tag_name -eq $tag }) { throw "Release $tag already exists" }

# 3. 创建 Gitee Release
$created = curl.exe -sS -X POST $api `
  --data-urlencode "access_token=$token" `
  --data-urlencode "tag_name=$tag" `
  --data-urlencode "name=$tag" `
  --data-urlencode "body=Mirror of https://github.com/$ghRepo/releases/tag/$tag" `
  --data-urlencode "target_commitish=$branch" `
  --data-urlencode "prerelease=false" | ConvertFrom-Json
if (-not $created.id) { throw "Create failed: $($created | ConvertTo-Json -Compress)" }

# 4. 逐个上传附件
Get-ChildItem -File $dist | ForEach-Object {
  $resp = curl.exe -sS -X POST "$api/$($created.id)/attach_files" `
    -F "access_token=$token" `
    -F "file=@$($_.FullName)" | ConvertFrom-Json
  if (-not $resp.browser_download_url) { throw "Upload failed for $($_.Name)" }
  "Uploaded $($_.Name): $($resp.browser_download_url)"
}

# 5. 按 .sha256 文件逐个比对产物哈希
Get-ChildItem -File $dist -Filter '*.sha256' | ForEach-Object {
  $asset    = $_.FullName -replace '\.sha256$', ''
  $actual   = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash
  $expected = ((Get-Content -LiteralPath $_.FullName -Raw) -split '\s+')[0].Trim()
  if ($actual -ne $expected) { throw "Checksum mismatch for $([IO.Path]::GetFileName($asset))" }
  "OK $([IO.Path]::GetFileName($asset)) $actual"
}
Remove-Variable token -ErrorAction SilentlyContinue
```

### 8.3 最后兜底：网页手工上传

API 始终失败时，在 Gitee 仓库 → 发行版 → 创建发行版，填与 GitHub 相同的 tag、标题，选择 `target_commitish` 对应分支，把 `dist/` 里的产物和校验文件拖进去。完成后仍要走第 9 节验证，并在发布记录里注明「本次为人工补传」。

---

## 9. 验证清单

**发布前**

- [ ] `GITEE_TOKEN` 已配置，`/api/v5/user` 自检返回预期登录名
- [ ] `GITEE_OWNER` / `GITEE_REPO` / `GITEE_BRANCH` 与 Gitee 实际仓库、默认分支一致
- [ ] 版本号递增、tag 与版本名一致、目标 tag 两端都不存在
- [ ] 本地构建 + 测试 + lint 通过；产物已验签、已生成 `.sha256`
- [ ] 产物大小在 Gitee 附件额度内，仓库剩余附件容量够用

**发布后（两端各查一遍）**

- [ ] GitHub Release 与 Gitee Release 同名 tag，附件文件名与数量一致
- [ ] 两端附件均可下载；`Get-FileHash` / `sha256sum` 结果与 `.sha256` 一致，且两端哈希相同
- [ ] 需要签名的产物，两端证书指纹一致（否则无法覆盖安装）
- [ ] `GET /releases/latest` 返回的 `tag_name` 是本次版本，且带附件
- [ ] 客户端「检查更新」命中镜像源并能调起安装器；镜像不可用时能回退 GitHub

**未验证项要如实记录**：CI 只保证附件上传成功，附件下载 URL 在真实国内网络下能否免登录直连，需要首次发版后用真机端到端验证。

---

## 10. 限制与高频坑

| 现象 | 根因 | 修复 / 教训 |
|---|---|---|
| 仓库镜像配好了，代码和 tag 都同步，附件却没有 | 官方镜像只同步分支/标签/提交，不含 Release 附件 | 附件必须由 CI 调 OpenAPI 单独上传；「镜像仓库」≠「镜像发布产物」 |
| `releases/latest` 返回旧版本 | latest 是「最后创建」，不是语义版本最高 | 按版本递增正常发版、不补发旧版本；客户端自己再比一次版本号 |
| 建 Release 报 404 / 关联失败 | owner/repo 写错，或 `target_commitish` 用了 GitHub 的 `main` 而 Gitee 默认是 `master` | 显式配置分支变量；先 `GET /releases` 确认仓库可访问 |
| 建 Release 报 422 | 同名 tag 已存在，或 `prerelease` 写成 `False` / `1` | 拒绝覆盖、查已有 Release；布尔值用小写 `false` / `true` |
| 上传返回 200 但页面看不到附件 | 只判断了状态码，没解析 `browser_download_url` | 以返回的下载地址为成功凭据，缺失就报错退出 |
| 上传 401 | 令牌过期或权限不足 | 轮换令牌、确认勾了 `projects`；Secret 更新后重跑镜像 job |
| 上传 413 / 附件莫名失败 | 超过单附件或仓库总附件额度 | 拆包或清理旧 Release 附件；不要把产物提交进 git |
| PowerShell 里 `curl -F` 报参数错误 | `curl` 是 `Invoke-WebRequest` 别名 | 一律写 `curl.exe` |
| 下载到的是登录页而不是安装包 | 私有仓库 / 未登录时网关返回 HTML | 用公开仓库；客户端拒绝 `text/html` 响应并校验文件魔数与最小体积 |
| 镜像 job 失败后重跑整个 workflow | 以为能「重试一次就好」 | GitHub 侧已发布，重跑必然撞 tag；按第 8 节只补镜像这一步 |
| Release 超过 100 个后幂等检查失效 | 列出接口只取了第一页 | 翻页或定期清理旧 Release |
| 两端哈希不一致 | 镜像端重新构建或人工传错包 | 只复用同一份 artifact，从已发布 Release 下载而不是重新打包 |
| 产物目录混入日志、报告 | 上传循环对 `dist/*` 全量遍历 | 上传前限定产物与校验文件，构建垃圾不进 artifact |

---

## 11. 回滚与约束

- **不删 tag、不覆盖附件、不复用版本号**。需要回退时发一个更高版本号的回退版本，别让用户降级安装。
- **同步失败不回滚 GitHub Release**：镜像缺失只是国内分发缺口，补传即可。
- **令牌轮换**：Gitee 侧生成新令牌 → 更新 GitHub Secret → 用 `/api/v5/user` 自检 → 触发一次镜像补传验证。
- **容量回收**：定期删除旧 Release 的附件（tag 保留），避免总量触顶；删除前确认没有用户仍在依赖该版本。
- **签名密钥**：密钥轮换可能意味着用户卸载重装、本地数据全丢；非必要不轮换，按项目自己的签名与备份策略执行。

---

## 12. 迁移到新项目的 Checklist

换一个项目时，按顺序过一遍；勾完即可上线分发链路。

1. [ ] 明确分工：GitHub 为权威发布源，Gitee 只做分发镜像；**代码是否需要同步到 Gitee**（不需要就别配仓库镜像）。
2. [ ] 建 Gitee 公开仓库并初始化默认分支，记录 `owner` / `repo` / 默认分支名。
3. [ ] 生成只含 `projects` 权限的私人令牌，存密码管理器并设轮换提醒。
4. [ ] 在 GitHub 配 `GITEE_TOKEN` Secret 与 3 个 Variables，`/api/v5/user` 自检通过。
5. [ ] 确认发布 workflow 唯一，镜像 job 用 `needs` 挂在后面，不新开一条打 tag 的流水线。
6. [ ] 发布 job 把产物 + `.sha256` 打成 artifact；镜像 job 下载**同一份** artifact。
7. [ ] 按 6.2 节替换 `<RELEASE_JOB_ID>` / `<ARTIFACT_NAME>` / `<ASSET_GLOB>`，并按触发方式改好 `TAG` 表达式。
8. [ ] 补齐 CI 自检：令牌非空、产物存在、同名 Release 不存在、`id` 与 `browser_download_url` 判空。
9. [ ] 明确镜像失败的告警策略（推荐标红不回滚）与人工补传步骤（第 8 节），写进项目发布文档。
10. [ ] 客户端若依赖 `releases/latest`，必须自己做版本号比较兜底，并保留 GitHub 回退链路。
11. [ ] 核对产物大小与 Gitee 附件额度，定下旧 Release 清理节奏。
12. [ ] 首次发版后按第 9 节做两端验证 + 真机端到端验证，把「未验证项」如实记进发布记录。

---

## 13. 与规范模块的对应关系

| 内容 | 位置 |
|---|---|
| 装进目标项目的规则条目（红线、SOP、验证、回滚、坑） | [`.agents/release-gitee.md`](../.agents/release-gitee.md) |
| 什么时候该加载这份规范 | [`AGENTS.md`](../AGENTS.md) 第 2 节探测表与第 3 节分流表 |
| 安装器如何判断要不要装这份模块 | 探测脚本的 `gitee_mirror` 事实 + 两个安装器的裁剪分支 |
| 完整 workflow 模板与参数替换 | 本文件第 6 节 |
| API 速查与人工补传脚本 | 本文件第 7、8 节 |
| 项目自己的发布文档应记录什么 | 镜像失败策略、补传步骤、未验证项，写进项目的 [`README.md`](../README.md) 或发布指南 |

## 14. 参考

- Gitee API 文档：https://gitee.com/api/v5/swagger （创建 Release：`postV5ReposOwnerRepoReleases`；上传附件：`postV5ReposOwnerRepoReleasesReleaseIdAttachFiles`）
- Gitee 帮助中心「创建 Release」：https://help.gitee.com/repository/release/create
- Gitee 帮助中心「什么是 Release」：https://help.gitee.com/repository/release/intro
- GitHub Actions artifact 传递：`actions/upload-artifact` / `actions/download-artifact`
