#Requires -Version 7.0
<#
.SYNOPSIS
    AI 开发规范：全局装一次，项目只初始化一次（Windows / PowerShell 7 版本）。

.DESCRIPTION
    两种模式：
      .\install.ps1 -Global [-Upgrade]    把规范装到全局目录（默认 ~/.ai-dev-standards）
      .\install.ps1 -Target <项目>         初始化项目（默认当前目录）

    全局目录装什么：AGENTS.md + .agents/ 全部模块 + scripts/ + templates/
    项目初始化装什么：AGENTS.md（指针）、CLAUDE.md（一行）、
                     .agents/project-profile.md、.git/hooks/ 下两个钩子

    与 install.sh 行为一致。唯一差别：PowerShell 版不做 profile 初稿探测，
    初始化出来的 project-profile.md 是模板本身，由 /ai-dev-standards:profile 填。

.PARAMETER Target
    目标项目目录，默认当前目录。

.PARAMETER Global
    装到全局目录，不碰任何项目。

.PARAMETER Upgrade
    升级已装的全局目录（隐含 -Global）。你改过的文件先备份到 .backup/<时间戳>/ 再覆盖。

.PARAMETER NoHooks
    项目初始化时不装 git 钩子。

.PARAMETER Force
    覆盖已存在的文件。

.PARAMETER DryRun
    只打印将要做什么，不落盘。

.EXAMPLE
    .\install.ps1 -Global

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -DryRun

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project
#>
[CmdletBinding()]
param(
    [string]$Target = '.',
    [switch]$Global,
    [switch]$Upgrade,
    [switch]$NoHooks,
    [switch]$Force,
    [switch]$DryRun,

    # 1.13.0 起废弃。保留定义只为给出可读的报错，而不是「找不到参数」。
    [switch]$Minimal,
    [switch]$WithCheck,
    [switch]$WithCi,
    [switch]$WithHooks,
    [switch]$AllModules,
    [string[]]$Modules,
    [switch]$SharedHooks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Minimal -or $WithCheck -or $WithCi -or $WithHooks -or $AllModules -or $Modules -or $SharedHooks) {
    Write-Host '1.13.0 起不再支持 -Minimal / -WithCheck / -WithCi / -WithHooks / -AllModules / -Modules / -SharedHooks。' -ForegroundColor Red
    Write-Host '模块现在全量装进全局目录，项目侧只初始化 3 个文件，不需要裁剪或项目级门禁开关。'
    Write-Host '用法：.\install.ps1 -Global 装一次；之后在项目里跑 .\install.ps1'
    exit 2
}

if ($Upgrade) { $Global = $true }

$repoRoot = $PSScriptRoot

if (-not (Test-Path (Join-Path $repoRoot 'AGENTS.md')) -or
    -not (Test-Path (Join-Path $repoRoot '.agents'))) {
    Write-Host "找不到模板文件，确认本脚本位于 ai-dev-standards 仓库根目录。`n当前目录: $repoRoot" -ForegroundColor Red
    exit 1
}

$version = 'unknown'
$manifestJson = Join-Path $repoRoot '.claude-plugin/plugin.json'
if (Test-Path $manifestJson) {
    try { $version = (Get-Content $manifestJson -Raw | ConvertFrom-Json).version } catch { $version = 'unknown' }
}

$globalHome = if ($env:AI_DEV_STANDARDS_HOME) { $env:AI_DEV_STANDARDS_HOME }
              else { Join-Path $env:USERPROFILE '.ai-dev-standards' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Get-Sha {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '' }
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-RelPath {
    param([string]$Root, [string]$Rel)
    return (Join-Path $Root ($Rel -replace '/', [System.IO.Path]::DirectorySeparatorChar))
}

function Write-Payload {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -Path $Source -Destination $Destination -Force
}

# ============================================================================
# 全局模式
# ============================================================================
if ($Global) {

    $repoNorm = (Resolve-Path $repoRoot).Path.TrimEnd('\', '/')
    # 用解析后的物理路径比较：F:/x 与 F:\x 是同一个目录，字符串比会失手
    $ghomeNorm = if (Test-Path $globalHome) {
        (Resolve-Path $globalHome).Path.TrimEnd('\', '/')
    }
    else {
        $globalHome.TrimEnd('\', '/')
    }
    $samePlace = ($repoNorm -eq $ghomeNorm)

    if ((-not $samePlace) -and (Test-Path $globalHome) -and
        ((Get-Item $globalHome).Attributes -band [System.IO.FileAttributes]::ReadOnly)) {
        Write-Host "全局目录不可写: $globalHome" -ForegroundColor Red
        exit 1
    }

    $manifestPath = Join-Path $globalHome '.standards-version'
    $script:recorded = @{}
    if (Test-Path $manifestPath) {
        foreach ($line in Get-Content -Path $manifestPath) {
            if ($line -match '^file (\S+) ([0-9a-fA-F]{64})$') {
                $script:recorded[$Matches[1]] = $Matches[2].ToLowerInvariant()
            }
        }
    }

    $files = [System.Collections.Generic.List[string]]::new()
    $files.Add('AGENTS.md')
    Get-ChildItem -Path (Join-Path $repoRoot '.agents') -Filter '*.md' -File |
        Sort-Object Name |
        ForEach-Object { $files.Add(".agents/$($_.Name)") }
    foreach ($f in @(
            'scripts/check.sh',
            'scripts/detect-profile.sh',
            'templates/githooks/commit-msg',
            'templates/githooks/post-commit',
            'templates/project/AGENTS.md',
            'templates/project/CLAUDE.md',
            'templates/github/check.yml')) {
        $files.Add($f)
    }

    $script:created = 0
    $script:updated = 0
    $script:skipped = 0
    $script:backedUp = 0
    $script:failed = [System.Collections.Generic.List[string]]::new()
    $script:managed = [System.Collections.Generic.List[string]]::new()
    $script:backupList = [System.Collections.Generic.List[string]]::new()

    function Put-Global {
        param([string]$Rel)

        $src = Get-RelPath $repoRoot $Rel
        $dst = Get-RelPath $globalHome $Rel

        if (-not (Test-Path $dst)) {
            if ($DryRun) { Write-Host "  [预览] 新增 $Rel" }
            else {
                try { Write-Payload $src $dst }
                catch { Write-Host "  ! 写入失败：$Rel" -ForegroundColor Red; $script:failed.Add($Rel); return }
            }
            $script:created++
            $script:managed.Add($Rel)
            return
        }

        if ((Get-Sha $src) -eq (Get-Sha $dst)) {
            $script:skipped++
            $script:managed.Add($Rel)
            return
        }

        $rec = ''
        if ($script:recorded.ContainsKey($Rel)) { $rec = $script:recorded[$Rel] }
        $untouched = $Force -or (-not $Upgrade) -or ($rec -and $rec -eq (Get-Sha $dst))

        if ($untouched) {
            if ($DryRun) { Write-Host "  [预览] 更新 $Rel" }
            else { Write-Payload $src $dst }
            $script:updated++
            $script:managed.Add($Rel)
            return
        }

        # 用户改过：备份后覆盖。全局目录是安装产物，不是工作区。
        if ($DryRun) {
            Write-Host "  [预览] 你改过 $Rel → 备份到 .backup/$stamp/ 后覆盖"
            $script:updated++
            $script:managed.Add($Rel)
            return
        }

        $bdir = Join-Path $globalHome ".backup/$stamp/$(Split-Path -Parent $Rel)"
        try {
            if (-not (Test-Path $bdir)) { New-Item -ItemType Directory -Path $bdir -Force | Out-Null }
            Copy-Item -Path $dst -Destination (Join-Path $globalHome ".backup/$stamp/$Rel") -Force
            Copy-Item -Path $src -Destination $dst -Force
            $script:backedUp++
            $script:backupList.Add($Rel)
            $script:updated++
            $script:managed.Add($Rel)
        }
        catch {
            Write-Host "  ! 备份失败，保留原文件：$Rel" -ForegroundColor Red
            $script:skipped++
            $script:failed.Add($Rel)
            if ($rec) { $script:managed.Add($Rel) }
        }
    }

    Write-Host "模板来源: $repoRoot"
    Write-Host "全局目录: $globalHome"
    Write-Host "规范版本: $version"
    Write-Host ''

    Write-Host '1. 全局规范'
    if ($samePlace) {
        Write-Host '  全局目录就是本仓库，不复制文件（升级用 git pull）。'
        foreach ($rel in $files) {
            if (-not (Test-Path (Get-RelPath $globalHome $rel))) {
                Write-Host "  ! 缺少 $rel" -ForegroundColor Red
            }
            $script:managed.Add($rel)
        }
    }
    else {
        foreach ($rel in $files) { Put-Global -Rel $rel }
    }

    if (-not $DryRun -and $script:managed.Count -gt 0) {
        $sourceKind = 'copy'
        if ($samePlace) { $sourceKind = 'repo' }
        elseif (Test-Path (Join-Path $globalHome '.git')) { $sourceKind = 'git' }

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# ai-dev-standards 全局安装清单，install.ps1 生成，不要手改。')
        $lines.Add('# 用途：-Upgrade 用这里的 sha256 判断文件是否被本地改过。')
        $lines.Add("version=$version")
        $lines.Add("installed=$(Get-Date -Format 'yyyy-MM-dd')")
        $lines.Add("source=$sourceKind")
        foreach ($rel in $script:managed) {
            $full = Get-RelPath $globalHome $rel
            if (-not (Test-Path $full)) { continue }
            $lines.Add("file $rel $(Get-Sha $full)")
        }

        $new = $lines -join "`n"
        $old = if (Test-Path $manifestPath) { Get-Content $manifestPath -Raw } else { '' }
        if ($new.TrimEnd() -ne $old.TrimEnd()) {
            Set-Content -Path $manifestPath -Value $new -Encoding utf8
        }
    }

    Write-Host ''
    Write-Host '────────────────────────────'
    Write-Host "写入 $script:created 个文件，更新 $script:updated 个，跳过 $script:skipped 个已存在的文件"
    if ($script:backedUp -gt 0) {
        Write-Host "你改过的 $script:backedUp 个文件已备份到 $(Join-Path $globalHome ".backup/$stamp")"
        $script:backupList | ForEach-Object { Write-Host "  $_" }
    }
    if ($script:failed.Count -gt 0) {
        Write-Host '以下文件写入失败或被保留：'
        $script:failed | ForEach-Object { Write-Host "  $_" }
    }
    if ((-not $DryRun) -and (Test-Path $manifestPath)) {
        Write-Host "安装清单: $manifestPath（version=$version）"
    }
    Write-Host ''
    Write-Host '项目侧不需要升级：那里只有指针和 project-profile，内容固定。'
    Write-Host "新项目初始化：.\install.ps1 -Target <项目路径>"
    exit 0
}

# ============================================================================
# 项目模式
# ============================================================================
if (-not (Test-Path $Target)) {
    Write-Host "目标目录不存在: $Target" -ForegroundColor Red
    exit 1
}
$target = (Resolve-Path $Target).Path.TrimEnd('\', '/')

$repoNorm = (Resolve-Path $repoRoot).Path.TrimEnd('\', '/')
if ($target -eq $repoNorm) {
    Write-Host '目标目录就是本仓库，跳过。' -ForegroundColor Red
    Write-Host '要装全局目录请用 -Global；初始化别的项目请传 -Target。'
    exit 1
}
if ($target -eq $globalHome.TrimEnd('\', '/')) {
    Write-Host '目标目录就是全局目录，不能在这里初始化项目。' -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $globalHome 'AGENTS.md')) -or
    -not (Test-Path (Join-Path $globalHome '.agents'))) {
    Write-Host "全局规范未安装：$globalHome" -ForegroundColor Red
    Write-Host ''
    Write-Host '先装一次（所有项目共用）：'
    Write-Host "  .\install.ps1 -Global"
    Write-Host ''
    Write-Host '或用插件命令：/ai-dev-standards:install（它会先确保全局已装）'
    exit 1
}

# ---------- 旧结构检测：只报告，不删任何文件 ----------
$legacyModules = @()
$legacyOther = @()
$agentDir = Join-Path $target '.agents'
if (Test-Path $agentDir) {
    $legacyModules = @(Get-ChildItem -Path $agentDir -Filter '*.md' -File |
        Where-Object { $_.Name -ne 'project-profile.md' } |
        ForEach-Object { ".agents/$($_.Name)" })
}
if (Test-Path (Join-Path $agentDir '.standards-version')) { $legacyOther += '.agents/.standards-version' }
$ptrFile = Join-Path $target 'AGENTS.md'
if (Test-Path $ptrFile) {
    $hit = Select-String -Path $ptrFile -Pattern '^last-verified:' -List -ErrorAction SilentlyContinue
    if ($hit) { $legacyOther += 'AGENTS.md' }
}

if ($legacyModules.Count -gt 0 -or $legacyOther.Count -gt 0) {
    $all = @($legacyModules + $legacyOther)
    Write-Host "目标项目: $target"
    Write-Host ''
    Write-Host "这个项目装的是 1.12.x 及更早的结构：规范副本在项目里，一共 $($all.Count) 处。"
    Write-Host '新结构下项目侧只留 AGENTS.md（指针）、CLAUDE.md 和 .agents/project-profile.md。'
    Write-Host ''
    Write-Host '需要清理的：'
    $all | ForEach-Object { Write-Host "  $_" }
    Write-Host ''

    $isGit = $false
    try {
        & git -C $target rev-parse --git-dir 2>$null | Out-Null
        $isGit = ($LASTEXITCODE -eq 0)
    }
    catch { $isGit = $false }

    $cmd = if ($isGit) { 'git rm -q' } else { 'Remove-Item -Force' }
    Write-Host '确认无误后执行（project-profile.md 不动）：'
    Write-Host "  cd `"$target`""
    if ($isGit) {
        Write-Host "  git rm -q $($all -join ' ')"
        Write-Host "  & `"$repoRoot/install.ps1`" -Target `"$target`""
        Write-Host ''
        Write-Host '  没提交过的文件 git rm 会报错，那就把 git rm -q 换成 Remove-Item -Force。'
    }
    else {
        Write-Host "  Remove-Item -Force $($all -join ', ')"
        Write-Host "  & `"$repoRoot/install.ps1`" -Target `"$target`""
    }
    Write-Host ''
    Write-Host '本脚本没有删任何文件。清理完重跑一次即可。'
    exit 0
}

$script:created = 0
$script:updated = 0
$script:skipped = 0
$agentsCustom = $false
$claudeCustom = $false

Write-Host "目标项目: $target"
Write-Host "全局目录: $globalHome"
Write-Host "规范版本: $version"
Write-Host ''

# ---------- 1. 项目档案 ----------
Write-Host '1. 项目档案'
$profDst = Join-Path $target '.agents/project-profile.md'
$profSrc = Join-Path $globalHome '.agents/project-profile.md'

if (-not (Test-Path $profDst)) {
    if ($DryRun) {
        Write-Host '  [预览] 新增 .agents/project-profile.md'
    }
    else {
        $parent = Split-Path -Parent $profDst
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -Path $profSrc -Destination $profDst -Force
        $script:created++
        Write-Host '  新增 .agents/project-profile.md（模板，待填）'
    }
}
else {
    $script:skipped++
    Write-Host '  已存在 .agents/project-profile.md，未改动'
}

# ---------- 2. 入口指针 ----------
Write-Host '2. 入口指针'
$ptrSrc = Join-Path $globalHome 'templates/project/AGENTS.md'
$ptrDst = Join-Path $target 'AGENTS.md'

if (-not (Test-Path $ptrDst)) {
    if ($DryRun) { Write-Host '  [预览] 新增 AGENTS.md（指向全局规范）' }
    else {
        Copy-Item -Path $ptrSrc -Destination $ptrDst -Force
        $script:created++
        Write-Host '  新增 AGENTS.md（指向全局规范）'
    }
}
elseif ((Get-Sha $ptrSrc) -eq (Get-Sha $ptrDst)) {
    $script:skipped++
    Write-Host '  AGENTS.md 已是最新指针'
}
else {
    $isPtr = Select-String -Path $ptrDst -Pattern '本文件是指针，不是规范本体' -List -ErrorAction SilentlyContinue
    if ($isPtr -or $Force) {
        if ($DryRun) { Write-Host '  [预览] 更新 AGENTS.md（指针有新版本）' }
        else { Copy-Item -Path $ptrSrc -Destination $ptrDst -Force }
        $script:updated++
        Write-Host '  更新 AGENTS.md（指针有新版本）'
    }
    else {
        $agentsCustom = $true
        $script:skipped++
        Write-Host '  ! 已有自定义 AGENTS.md，未覆盖' -ForegroundColor Yellow
    }
}

$clSrc = Join-Path $globalHome 'templates/project/CLAUDE.md'
$clDst = Join-Path $target 'CLAUDE.md'

if (-not (Test-Path $clDst)) {
    if ($DryRun) { Write-Host '  [预览] 新增 CLAUDE.md（一行 @AGENTS.md）' }
    else {
        Copy-Item -Path $clSrc -Destination $clDst -Force
        $script:created++
        Write-Host '  新增 CLAUDE.md（一行 @AGENTS.md）'
    }
}
else {
    $hasImport = Select-String -Path $clDst -Pattern '^@AGENTS\.md' -List -ErrorAction SilentlyContinue
    if ($hasImport) {
        $script:skipped++
        Write-Host '  CLAUDE.md 已含 @AGENTS.md'
    }
    elseif ($Force) {
        if ($DryRun) { Write-Host '  [预览] 覆盖 CLAUDE.md' }
        else { Copy-Item -Path $clSrc -Destination $clDst -Force }
        $script:updated++
        Write-Host '  覆盖 CLAUDE.md（-Force）'
    }
    else {
        $claudeCustom = $true
        $script:skipped++
        Write-Host '  ! 已有自定义 CLAUDE.md，未覆盖' -ForegroundColor Yellow
    }
}

if ($agentsCustom) {
    Write-Host ''
    Write-Host '  手动处理：在 AGENTS.md 开头加一段，指明规范在全局目录——'
    Write-Host '    本仓库的 AI 开发规范在 ${AI_DEV_STANDARDS_HOME:-$HOME/.ai-dev-standards}/'
    Write-Host '    开工前先读该目录下的 AGENTS.md，模块路径相对它所在目录。'
    Write-Host '    再读本仓库 .agents/project-profile.md。'
}
if ($claudeCustom) {
    Write-Host ''
    Write-Host '  手动处理：在 CLAUDE.md 第一行加 @AGENTS.md'
}

# ---------- 3. git 钩子 ----------
$hookNew = 0
$hookSkip = 0

Write-Host ''
Write-Host '3. git 钩子'

if ($NoHooks) {
    Write-Host '  已跳过（-NoHooks）'
}
else {
    $gitDir = $null
    try {
        $candidate = & git -C $target rev-parse --absolute-git-dir 2>$null
        if ($LASTEXITCODE -eq 0 -and $candidate) { $gitDir = $candidate.Trim() }
    }
    catch { $gitDir = $null }

    if (-not $gitDir) {
        Write-Host '  ! 目标不是 git 仓库，跳过钩子安装（装钩子需要仓库）'
    }
    else {
        $hookDir = Join-Path $gitDir 'hooks'
        $configured = $null
        try { $configured = & git -C $target config core.hooksPath 2>$null } catch { $configured = $null }
        if ($configured) {
            Write-Host "  ! 该项目已配置 core.hooksPath=$configured" -ForegroundColor Yellow
            Write-Host '    git 会忽略 .git/hooks/，刚装的钩子不会生效。'
            Write-Host '    处理：git config --unset core.hooksPath'
        }

        foreach ($h in @('commit-msg', 'post-commit')) {
            $src = Join-Path $globalHome "templates/githooks/$h"
            $dst = Join-Path $hookDir $h
            if (-not (Test-Path $src)) { continue }

            if ($DryRun) {
                if ((Test-Path $dst) -and ((Get-Sha $src) -eq (Get-Sha $dst))) { $hookSkip++ }
                else { Write-Host "  [预览] .git/hooks/$h"; $hookNew++ }
                continue
            }

            if (-not (Test-Path $hookDir)) { New-Item -ItemType Directory -Path $hookDir -Force | Out-Null }

            if (Test-Path $dst) {
                $content = ''
                try { $content = Get-Content -Path $dst -Raw -ErrorAction SilentlyContinue } catch { $content = '' }
                $isOurs = $content -and ($content -match 'ai-dev-standards-hook')
                $localCopy = "$dst.local"

                if ($isOurs) {
                    if ((Get-Sha $src) -eq (Get-Sha $dst)) { $hookSkip++; continue }
                    Write-Host "  更新 $h（$version）"
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
                        Write-Host "  ! 已有 $h，无法保留原钩子，仍继续覆盖" -ForegroundColor Yellow
                    }
                }
            }

            Copy-Item -Path $src -Destination $dst -Force
            $hookNew++
        }
    }
}

Write-Host ''
Write-Host '────────────────────────────'
Write-Host "写入 $script:created 个文件，更新 $script:updated 个，跳过 $script:skipped 个"
if (-not $NoHooks) { Write-Host "钩子：新增/更新 $hookNew 个，跳过 $hookSkip 个" }
Write-Host ''
Write-Host '下一步：补齐 .agents/project-profile.md 里剩下的「未定」'
Write-Host '  PowerShell 版不探测，profile 是空模板；装过插件就跑 /ai-dev-standards:profile'
Write-Host '  没装插件：让 AI 按 references/profile-guide.md 的「一键生成」执行'
Write-Host ''
Write-Host '其他项目只需重复这一步；规范本身升级只跑 .\install.ps1 -Global -Upgrade'
