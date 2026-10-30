#Requires -Version 7.0
<#
.SYNOPSIS
    把 AI 开发规范装到目标项目（Windows / PowerShell 7 版本）。

.DESCRIPTION
    本脚本就在仓库根目录，clone 下来直接跑即可。
    与 install.sh 行为一致：不覆盖已存在的文件，除非显式加 -Force。

.PARAMETER Target
    目标项目目录，默认当前目录。

.PARAMETER WithCi
    同时安装 .github/workflows/check.yml。

.PARAMETER WithHooks
    安装 git 钩子并设置 core.hooksPath。

.PARAMETER Force
    覆盖已存在的文件。

.PARAMETER DryRun
    只打印将要做什么，不落盘。

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -DryRun

.EXAMPLE
    .\install.ps1 -Target . -WithHooks -WithCi
#>
[CmdletBinding()]
param(
    [string]$Target = '.',
    [switch]$WithCi,
    [switch]$WithHooks,
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot

if (-not (Test-Path (Join-Path $repoRoot 'AGENTS.md')) -or
    -not (Test-Path (Join-Path $repoRoot '.agents'))) {
    throw "找不到模板文件，确认本脚本位于 ai-dev-standards 仓库根目录。`n当前目录: $repoRoot"
}
if (-not (Test-Path $Target)) {
    throw "目标目录不存在: $Target"
}
$target = (Resolve-Path $Target).Path

if ($target -eq (Resolve-Path $repoRoot).Path) {
    throw '目标目录就是本仓库，跳过。'
}

$script:copied = 0
$script:skipped = 0
$script:skippedList = [System.Collections.Generic.List[string]]::new()

function Write-File {
    param([string]$Source, [string]$Destination)

    $rel = $Destination.Substring($target.Length).TrimStart('\', '/')

    if ((Test-Path $Destination) -and (-not $Force)) {
        $script:skipped++
        $script:skippedList.Add($rel)
        return
    }

    if ($DryRun) {
        Write-Host "  [预览] $rel"
        $script:copied++
        return
    }

    $parent = Split-Path -Parent $Destination
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -Path $Source -Destination $Destination -Force
    $script:copied++
}

Write-Host "模板来源: $repoRoot"
Write-Host "目标项目: $target"
Write-Host ''

Write-Host '1. 核心规范文件'
Write-File (Join-Path $repoRoot 'AGENTS.md') (Join-Path $target 'AGENTS.md')
Write-File (Join-Path $repoRoot 'CLAUDE.md') (Join-Path $target 'CLAUDE.md')

$agentDir = Join-Path $repoRoot '.agents'
foreach ($f in Get-ChildItem -Path $agentDir -Filter '*.md' -File) {
    Write-File $f.FullName (Join-Path $target ".agents/$($f.Name)")
}

Write-Host '2. 自检脚本'
Write-File (Join-Path $repoRoot 'scripts/check.sh') (Join-Path $target 'scripts/check.sh')

if ($WithCi) {
    Write-Host '3. GitHub Actions 门禁'
    Write-File (Join-Path $repoRoot 'templates/github/check.yml') (Join-Path $target '.github/workflows/check.yml')
}

if ($WithHooks) {
    Write-Host '4. git 钩子'
    Write-File (Join-Path $repoRoot 'templates/githooks/commit-msg') (Join-Path $target 'templates/githooks/commit-msg')
    Write-File (Join-Path $repoRoot 'templates/githooks/post-commit') (Join-Path $target 'templates/githooks/post-commit')

    if (-not $DryRun) {
        $isRepo = $false
        try {
            & git -C $target rev-parse --git-dir *> $null
            $isRepo = ($LASTEXITCODE -eq 0)
        }
        catch { $isRepo = $false }

        if ($isRepo) {
            & git -C $target config core.hooksPath templates/githooks
            Write-Host '  core.hooksPath -> templates/githooks'
        }
        else {
            Write-Host '  ! 目标不是 git 仓库，跳过 hooksPath 配置'
        }
    }
}

Write-Host ''
Write-Host '────────────────────────────'
Write-Host "写入 $script:copied 个文件，跳过 $script:skipped 个已存在的文件"

if ($script:skippedList.Count -gt 0) {
    Write-Host ''
    Write-Host '以下文件已存在，未被覆盖：'
    $script:skippedList | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
    Write-Host '确认要覆盖请加 -Force 重跑。'
}

if (-not $DryRun) {
    Write-Host ''
    Write-Host '下一步（必须）：填 .agents/project-profile.md'
    Write-Host '  文件里全是「未定」。逐项确认后再开工——'
    Write-Host '  规范要求 AI 遇到未定项必须停下来问，不许拿示例值当事实。'
    Write-Host '  字段说明见 references/profile-guide.md'
    Write-Host ''
    Write-Host "验证安装：cd `"$target`"; bash scripts/check.sh"
}
