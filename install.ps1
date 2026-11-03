#Requires -Version 7.0
<#
.SYNOPSIS
    把 AI 开发规范装到目标项目（Windows / PowerShell 7 版本）。

.DESCRIPTION
    本脚本就在仓库根目录，clone 下来直接跑即可。
    与 install.sh 行为一致：不覆盖已存在的文件，除非显式加 -Force。

.PARAMETER Target
    目标项目目录，默认当前目录。

.PARAMETER Minimal
    只装 AGENTS.md + .agents/，项目根只多 2 个条目，不装钩子。
    适合不用 Claude Code 的场景——它不装 CLAUDE.md，Claude Code 会读不到规范。
    与 -NoHooks / -WithCheck / -WithCi 互斥。

.PARAMETER NoHooks
    不装 git 钩子。钩子默认是装的，装到 .git/hooks/。

.PARAMETER WithCheck
    额外装 scripts/check.sh（五项自检）。默认不装。

.PARAMETER WithCi
    额外安装 .github/workflows/check.yml。会自动带上 scripts/check.sh，因为 CI 跑的就是它。

.PARAMETER WithHooks
    兼容旧写法保留；钩子现在是默认行为，不需要显式指定。

.PARAMETER Force
    覆盖已存在的文件。

.PARAMETER DryRun
    只打印将要做什么，不落盘。

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -DryRun

.EXAMPLE
    .\install.ps1 -Target F:\code\my-project -Minimal

.EXAMPLE
    .\install.ps1 -Target . -WithHooks -WithCi
#>
[CmdletBinding()]
param(
    [string]$Target = '.',
    [switch]$Minimal,
    [switch]$NoHooks,
    [switch]$WithCheck,
    [switch]$WithCi,
    [switch]$WithHooks,
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

Write-Host '1. 核心规范'
Write-File (Join-Path $repoRoot 'AGENTS.md') (Join-Path $target 'AGENTS.md')

$agentDir = Join-Path $repoRoot '.agents'
foreach ($f in Get-ChildItem -Path $agentDir -Filter '*.md' -File) {
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
        Write-Host '4. git 钩子'

        $gitDir = $null
        try {
            $candidate = & git -C $target rev-parse --absolute-git-dir 2>$null
            if ($LASTEXITCODE -eq 0 -and $candidate) { $gitDir = $candidate.Trim() }
        }
        catch { $gitDir = $null }

        if (-not $gitDir) {
            Write-Host '  ! 目标不是 git 仓库，跳过钩子安装（装到 .git/hooks/ 需要仓库）'
        }
        else {
            $hookDir = Join-Path $gitDir 'hooks'

            # core.hooksPath 一旦设置，git 就完全不看 .git/hooks/ 了
            $configured = $null
            try { $configured = & git -C $target config core.hooksPath 2>$null } catch { $configured = $null }
            if ($configured) {
                Write-Host "  ! 该项目已配置 core.hooksPath=$configured"
                Write-Host '    git 会忽略 .git/hooks/，刚装的钩子不会生效。'
                Write-Host '    用之前先执行：git config --unset core.hooksPath'
            }

            foreach ($h in @('commit-msg', 'post-commit')) {
                $src = Join-Path $repoRoot "templates/githooks/$h"
                $dst = Join-Path $hookDir $h
                if (-not (Test-Path $src)) { continue }

                if ($DryRun) {
                    Write-Host "  [预览] .git/hooks/$h"
                    $script:copied++
                    continue
                }

                if (-not (Test-Path $hookDir)) {
                    New-Item -ItemType Directory -Path $hookDir -Force | Out-Null
                }

                # 钩子必须覆盖才生效，但已有的先备份
                if (Test-Path $dst) {
                    $backup = "$dst.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
                    try {
                        Copy-Item -Path $dst -Destination $backup -Force
                        Write-Host "  已有 $h，已备份为 $(Split-Path -Leaf $backup)"
                    }
                    catch {
                        Write-Host "  ! 已有 $h，备份失败，仍继续覆盖"
                    }
                }

                Copy-Item -Path $src -Destination $dst -Force
                $script:copied++
            }
        }
    }
    else {
        Write-Host '4. 已跳过钩子（-NoHooks）'
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
    if ((Test-Path (Join-Path $target 'scripts/check.sh')) -and (-not $DryRun)) {
        Write-Host ''
        Write-Host "验证安装：cd `"$target`"; bash scripts/check.sh"
    }
}
