#Requires -Version 7.0
<#
.SYNOPSIS
    把 AI 开发规范装到目标项目（Windows / PowerShell 7 版本）。

.DESCRIPTION
    本脚本就在仓库根目录，clone 下来直接跑即可。
    与 install.sh 行为一致：不覆盖已存在的文件，除非显式加 -Force；
    升级用 -Upgrade，只覆盖「装完之后没被改过」的文件。

.PARAMETER Target
    目标项目目录，默认当前目录。

.PARAMETER Minimal
    只装 AGENTS.md + .agents/，项目根只多 2 个条目，不装钩子。
    适合不用 Claude Code 的场景——它不装 CLAUDE.md，Claude Code 会读不到规范。
    与 -NoHooks / -WithCheck / -WithCi 互斥。

.PARAMETER NoHooks
    不装 git 钩子。钩子默认是装的，装到 .git/hooks/。

.PARAMETER WithCheck
    额外装 scripts/check.sh（七项自检）。默认不装。

.PARAMETER WithCi
    额外安装 .github/workflows/check.yml。会自动带上 scripts/check.sh，因为 CI 跑的就是它。

.PARAMETER WithHooks
    兼容旧写法保留；钩子现在是默认行为，不需要显式指定。

.PARAMETER Upgrade
    升级已装的规范：按 .agents/.standards-version 里的 sha256 判断文件是否被本地改过。
    没改过的覆盖为新版，改过的另存为 <文件>.new。

.PARAMETER AllModules
    不裁剪，.agents/ 下的模块全装（旧行为）。

.PARAMETER Modules
    只装指定模块，如 -Modules commit.md,lang-java.md。

.PARAMETER SharedHooks
    钩子写进项目的 .githooks/ 并设置 core.hooksPath，跟仓库一起提交，团队 clone 后直接生效。

.PARAMETER Force
    覆盖已存在的文件。

.PARAMETER DryRun
    只打印将要做什么，不落盘。

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -DryRun

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -Upgrade

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -SharedHooks -WithCi
#>
[CmdletBinding()]
param(
    [string]$Target = '.',
    [switch]$Minimal,
    [switch]$NoHooks,
    [switch]$WithCheck,
    [switch]$WithCi,
    [switch]$WithHooks,
    [switch]$Upgrade,
    [switch]$AllModules,
    [string[]]$Modules,
    [switch]$SharedHooks,
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot

# CI 里跑的就是 scripts/check.sh，要装 CI 就必须带上它
if ($WithCi) { $WithCheck = $true }

if ($Minimal -and ($WithCi -or $WithCheck -or $NoHooks)) {
    throw '-Minimal 与 -WithCheck / -WithCi / -NoHooks 互斥。-Minimal 本身就是只装核心，不需要再叠加这些开关。'
}

if (-not (Test-Path (Join-Path $repoRoot 'AGENTS.md')) -or
    -not (Test-Path (Join-Path $repoRoot '.agents'))) {
    throw "找不到模板文件，确认本脚本位于 ai-dev-standards 仓库根目录。`n当前目录: $repoRoot"
}
if (-not (Test-Path $Target)) {
    throw "目标目录不存在: $Target"
}
$target = (Resolve-Path $Target).Path.TrimEnd('\', '/')

if ($target -eq (Resolve-Path $repoRoot).Path.TrimEnd('\', '/')) {
    throw '目标目录就是本仓库，跳过。'
}

# 版本号只有一个来源：插件清单。-Upgrade 靠它写进安装清单。
$manifestJson = Join-Path $repoRoot '.claude-plugin/plugin.json'
$version = 'unknown'
if (Test-Path $manifestJson) {
    try {
        $version = (Get-Content $manifestJson -Raw | ConvertFrom-Json).version
    }
    catch { $version = 'unknown' }
}

$manifestPath = Join-Path $target '.agents/.standards-version'

$script:created = 0
$script:updated = 0
$script:skipped = 0
$script:conflicts = 0
$script:skipList = [System.Collections.Generic.List[string]]::new()
$script:conflictList = [System.Collections.Generic.List[string]]::new()
$script:managed = [System.Collections.Generic.List[string]]::new()
$script:preserved = [System.Collections.Generic.Dictionary[string, string]]::new()

function Get-RelPath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($target, $Path).Replace('\', '/')
}

function Get-Sha {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '' }
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# 安装清单里记录的、安装当时的 hash
$script:recorded = @{}
if (Test-Path $manifestPath) {
    foreach ($line in Get-Content -Path $manifestPath) {
        if ($line -match '^file (\S+) ([0-9a-fA-F]{64})$') {
            $script:recorded[$Matches[1]] = $Matches[2].ToLowerInvariant()
        }
    }
}

function Write-Payload {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -Path $Source -Destination $Destination -Force
}

function Write-File {
    param([string]$Source, [string]$Destination)

    $rel = Get-RelPath $Destination

    # 目标不存在：新增
    if (-not (Test-Path $Destination)) {
        if ($DryRun) {
            Write-Host "  [预览] 新增 $rel"
        }
        else {
            Write-Payload $Source $Destination
        }
        $script:created++
        $script:managed.Add($rel)
        return
    }

    # -Force：无条件覆盖
    if ($Force) {
        if ($DryRun) { Write-Host "  [预览] 覆盖 $rel" }
        else { Write-Payload $Source $Destination }
        $script:updated++
        $script:managed.Add($rel)
        return
    }

    # 内容相同：跳过，不打扰
    if ((Get-Sha $Source) -eq (Get-Sha $Destination)) {
        $script:skipped++
        $script:managed.Add($rel)
        return
    }

    # -Upgrade：只有「没被改过」才覆盖
    if ($Upgrade) {
        $rec = ''
        if ($script:recorded.ContainsKey($rel)) { $rec = $script:recorded[$rel] }

        if ($rec -and $rec -eq (Get-Sha $Destination)) {
            if ($DryRun) { Write-Host "  [预览] 更新 $rel" }
            else { Write-Payload $Source $Destination }
            $script:updated++
            $script:managed.Add($rel)
            return
        }

        if ($DryRun) {
            Write-Host "  [预览] 冲突 $rel -> $rel.new（本地有改动，不覆盖）"
        }
        else {
            Write-Payload $Source "$Destination.new"
            Write-Host "  本地已改动，新版写为 $rel.new（确认后可手动合并）"
        }
        $script:conflicts++
        $script:conflictList.Add($rel)
        # 没装进去，就不能把本地改动后的 hash 记进清单，否则下次 -Upgrade
        # 会误判成「没被改过」直接覆盖。保留上一次安装时的记录。
        if ($rec) { $script:preserved[$rel] = $rec }
        return
    }

    # 默认：已存在就跳过
    $script:skipped++
    $script:skipList.Add($rel)
    $script:managed.Add($rel)
}

function Write-Manifest {
    if ($DryRun) { return }
    if ($script:managed.Count -eq 0) { return }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# ai-dev-standards 安装清单，install.ps1 生成，不要手改。')
    $lines.Add('# 用途：-Upgrade 用这里的 sha256 判断文件是否被本地改过。')
    $lines.Add("version=$version")
    $lines.Add("installed=$(Get-Date -Format 'yyyy-MM-dd')")

    foreach ($rel in $script:managed) {
        $full = Join-Path $target $rel
        if (-not (Test-Path $full)) { continue }
        $lines.Add("file $rel $(Get-Sha $full)")
    }
    foreach ($entry in $script:preserved.GetEnumerator()) {
        $lines.Add("file $($entry.Key) $($entry.Value)")
    }

    $new = $lines -join "`n"
    $old = if (Test-Path $manifestPath) { Get-Content -Path $manifestPath -Raw } else { '' }
    if ($new.TrimEnd() -ne $old.TrimEnd()) {
        $parent = Split-Path -Parent $manifestPath
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Set-Content -Path $manifestPath -Value $new -NoNewline:$false -Encoding utf8
    }
}

# ---------- 模块裁剪：只装和这个项目有关的规范 ----------
# 跨语言、任何项目都用得上：项目档案、提交规范、纪律、任务工作流、外部对接、老系统方法论
$alwaysModules = @('project-profile.md', 'commit.md', 'discipline.md', 'task-workflow.md', 'integration.md', 'legacy.md')
$allModuleFiles = @(Get-ChildItem -Path (Join-Path $repoRoot '.agents') -Filter '*.md' -File | ForEach-Object { $_.Name })

$wanted = @()
if ($AllModules) {
    $wanted = $allModuleFiles
}
elseif ($Modules) {
    foreach ($item in $Modules) {
        foreach ($piece in ($item -split ',')) {
            $name = $piece.Trim()
            if (-not $name) { continue }
            if ($allModuleFiles -notcontains $name) {
                throw "未知模块: $name（可用模块见 .agents/ 目录）"
            }
            if ($wanted -notcontains $name) { $wanted += $name }
        }
    }
}
else {
    $wanted = @($alwaysModules)

    $hasJava = (Test-Path (Join-Path $target 'pom.xml')) -or
        (Test-Path (Join-Path $target 'build.gradle')) -or
        (Test-Path (Join-Path $target 'build.gradle.kts'))
    $hasPython = (Test-Path (Join-Path $target 'pyproject.toml')) -or
        (Test-Path (Join-Path $target 'requirements.txt')) -or
        (Test-Path (Join-Path $target 'setup.py'))
    $hasVue = $false
    $pkgJson = Join-Path $target 'package.json'
    if (Test-Path $pkgJson) {
        try { $hasVue = (Get-Content -Path $pkgJson -Raw) -match '"vue"' } catch { $hasVue = $false }
    }
    $hasGithub = Test-Path (Join-Path $target '.github/workflows')
    if (-not $hasGithub) {
        try {
            $remote = & git -C $target remote get-url origin 2>$null
            if ($remote -match 'github') { $hasGithub = $true }
        }
        catch { $hasGithub = $false }
    }
    $hasDocker = (Test-Path (Join-Path $target 'Dockerfile')) -or
        (Test-Path (Join-Path $target 'docker-compose.yml')) -or
        (Test-Path (Join-Path $target 'compose.yaml'))

    if ($hasJava) { $wanted += 'lang-java.md' }
    if ($hasPython) { $wanted += 'lang-python.md' }
    if ($hasVue) { $wanted += 'lang-vue.md' }
    if ($hasGithub) { $wanted += 'release-github.md' }
    if ($hasDocker) { $wanted += 'release-docker.md' }
}

$skippedModules = @($allModuleFiles | Where-Object { $wanted -notcontains $_ })

# 没装的模块不能留在 AGENTS.md 的分流表里，否则 AI 会照表去读不存在的文件
$agentsSource = Join-Path $repoRoot 'AGENTS.md'
$agentsTemp = $null
if ($skippedModules.Count -gt 0) {
    $lines = Get-Content -Path $agentsSource
    $tick = [char]96
    foreach ($m in $skippedModules) {
        $pattern = '^\|.*' + $tick + [regex]::Escape($m) + $tick
        $lines = $lines | Where-Object { $_ -notmatch $pattern }
    }
    $agentsTemp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $agentsTemp -Value $lines -Encoding utf8
    $agentsSource = $agentsTemp
}

Write-Host "模板来源: $repoRoot"
Write-Host "目标项目: $target"
Write-Host "规范版本: $version"
Write-Host ''

Write-Host '1. 核心规范'
Write-File $agentsSource (Join-Path $target 'AGENTS.md')
if ($agentsTemp -and (Test-Path $agentsTemp)) { Remove-Item -Path $agentsTemp -Force -ErrorAction SilentlyContinue }

$agentDir = Join-Path $repoRoot '.agents'
foreach ($f in Get-ChildItem -Path $agentDir -Filter '*.md' -File) {
    if ($wanted -notcontains $f.Name) { continue }
    Write-File $f.FullName (Join-Path $target ".agents/$($f.Name)")
}

if ($Minimal) {
    Write-Host ''
    Write-Host '2. 已跳过（-Minimal）：CLAUDE.md、scripts/check.sh、钩子、CI'
    Write-Host '   ! 没装 CLAUDE.md，Claude Code 将读不到这套规范。'
    Write-Host '     需要的话去掉 -Minimal 重跑，或手动建 CLAUDE.md 写一行 @AGENTS.md'
}
else {
    Write-Host '2. 工具入口'
    Write-File (Join-Path $repoRoot 'CLAUDE.md') (Join-Path $target 'CLAUDE.md')

    if ($WithCheck) {
        if ($WithCi) {
            Write-Host '3. 自检脚本（CI 依赖它，自动带上）'
        }
        else {
            Write-Host '3. 自检脚本'
        }
        Write-File (Join-Path $repoRoot 'scripts/check.sh') (Join-Path $target 'scripts/check.sh')
    }

    if ($WithCi) {
        Write-Host '4. GitHub Actions 门禁'
        Write-File (Join-Path $repoRoot 'templates/github/check.yml') (Join-Path $target '.github/workflows/check.yml')
    }

    if (-not $NoHooks) {
        Write-Host '5. git 钩子'

        $gitDir = $null
        try {
            $candidate = & git -C $target rev-parse --absolute-git-dir 2>$null
            if ($LASTEXITCODE -eq 0 -and $candidate) { $gitDir = $candidate.Trim() }
        }
        catch { $gitDir = $null }

        if (-not $gitDir) {
            Write-Host '  ! 目标不是 git 仓库，跳过钩子安装（装钩子需要仓库）'
        }
        elseif ($SharedHooks) {
            # .githooks/ 跟着仓库走：团队 clone 后不用各自装
            foreach ($h in @('commit-msg', 'post-commit')) {
                $src = Join-Path $repoRoot "templates/githooks/$h"
                if (-not (Test-Path $src)) { continue }
                Write-File $src (Join-Path $target ".githooks/$h")
            }
            if (-not $DryRun) {
                & git -C $target config core.hooksPath .githooks
                Write-Host '  已设 core.hooksPath=.githooks，钩子会跟仓库一起提交'
            }
        }
        else {
            $hookDir = Join-Path $gitDir 'hooks'

            # core.hooksPath 一旦设置，git 就完全不看 .git/hooks/ 了
            $configured = $null
            try { $configured = & git -C $target config core.hooksPath 2>$null } catch { $configured = $null }
            if ($configured) {
                Write-Host "  ! 该项目已配置 core.hooksPath=$configured"
                Write-Host '    git 会忽略 .git/hooks/，刚装的钩子不会生效。'
                Write-Host '    两种处理：git config --unset core.hooksPath（改回 .git/hooks/）'
                Write-Host '              或用 -SharedHooks 把钩子装进项目里的 .githooks/'
            }

            foreach ($h in @('commit-msg', 'post-commit')) {
                $src = Join-Path $repoRoot "templates/githooks/$h"
                $dst = Join-Path $hookDir $h
                if (-not (Test-Path $src)) { continue }

                if ($DryRun) {
                    if ((Test-Path $dst) -and ((Get-Sha $src) -eq (Get-Sha $dst))) {
                        $script:skipped++
                    }
                    else {
                        Write-Host "  [预览] .git/hooks/$h"
                        $script:created++
                    }
                    continue
                }

                if (-not (Test-Path $hookDir)) {
                    New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
                }

                # 已有钩子分三种情况处理，不静默停用用户的东西
                if (Test-Path $dst) {
                    $content = ''
                    try { $content = Get-Content -Path $dst -Raw -ErrorAction SilentlyContinue } catch { $content = '' }
                    $isOurs = $content -and ($content -match 'ai-dev-standards-hook')
                    $localCopy = "$dst.local"

                    if ($isOurs) {
                        # 已经是我们的：内容一样就不重写，这样重复安装才是真幂等
                        if ((Get-Sha $src) -eq (Get-Sha $dst)) {
                            $script:skipped++
                            continue
                        }
                        Write-Host "  更新 $h（$version）"
                        $script:updated++
                    }
                    elseif (Test-Path $localCopy) {
                        Write-Host "  已有 $h，原钩子保留在 $h.local，未重复备份"
                    }
                    else {
                        try {
                            Copy-Item -Path $dst -Destination $localCopy -Force
                            Write-Host "  已有自定义 $h，保留为 $h.local（规范钩子会接着执行它）"
                        }
                        catch {
                            Write-Host "  ! 已有 $h，无法保留原钩子，仍继续覆盖"
                        }
                    }
                }

                Copy-Item -Path $src -Destination $dst -Force
                $script:created++
            }
        }
    }
    else {
        Write-Host '4. 已跳过钩子（-NoHooks）'
    }
}

Write-Manifest

Write-Host ''
Write-Host '────────────────────────────'
Write-Host "写入 $script:created 个文件，更新 $script:updated 个，跳过 $script:skipped 个已存在的文件"
$skipNote = ''
if ($skippedModules.Count -gt 0) { $skipNote = "（与项目无关，跳过 $($skippedModules -join ' ')）" }
Write-Host "模块：$($wanted.Count)/$($allModuleFiles.Count)$skipNote"
if ((-not $DryRun) -and (Test-Path $manifestPath)) {
    Write-Host "安装清单: .agents/.standards-version（version=$version）"
}

if ($script:conflicts -gt 0) {
    Write-Host ''
    Write-Host "有 $script:conflicts 个文件本地改动过，新版另存为 .new："
    $script:conflictList | ForEach-Object { Write-Host "  $_" }
    Write-Host '手动 diff 合并后删掉 .new 即可。'
}

if ($script:skipList.Count -gt 0) {
    Write-Host ''
    Write-Host '以下文件已存在、内容与模板不同，未被覆盖：'
    $script:skipList | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
    Write-Host '只是版本旧了用 -Upgrade；确认要以模板为准请加 -Force 重跑。'
}

if (-not $DryRun) {
    Write-Host ''
    Write-Host '下一步（必须）：生成 .agents/project-profile.md'
    Write-Host '  文件里全是「未定」。别手填——装过插件的话跑：/ai-dev-standards:profile'
    Write-Host '  它会探测项目事实，只问你几个必须由人决定的选择。'
    Write-Host '  规范要求 AI 遇到未定项必须停下来问，不许拿示例值当事实。'
    Write-Host '  字段说明见 references/profile-guide.md'
    if ((Test-Path (Join-Path $target 'scripts/check.sh')) -and (-not $DryRun)) {
        Write-Host ''
        Write-Host "验证安装：cd `"$target`"; bash scripts/check.sh"
    }
}
