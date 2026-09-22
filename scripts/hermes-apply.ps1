<#
.SYNOPSIS
  Install this repo's Hermes and Codex configs onto the machine, with backups.

.DESCRIPTION
  Copies configs/hermes/config.yaml  -> $HERMES_HOME\config.yaml
         configs/codex/config.toml   -> ~\.codex\config.toml

  Every existing file is backed up to <name>.bak-<timestamp> FIRST. Nothing is
  overwritten without a copy surviving, because the deployed config has drifted
  from this repo before (docs/models/handoff-2026-09-22.md) and the deployed side
  may hold changes nobody wrote down.

  Touches no .env and no credential. Keys are read by Hermes from
  $HERMES_HOME\.env at runtime and are none of this script's business.

.EXAMPLE
  pwsh -File scripts/hermes-apply.ps1 -WhatIf   # show what would change
  pwsh -File scripts/hermes-apply.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$HermesHome = $(if ($env:HERMES_HOME) { $env:HERMES_HOME }
                            else { Join-Path $env:LOCALAPPDATA 'hermes' }),
    [string]$CodexHome  = $(Join-Path $HOME '.codex')
)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$repo  = Split-Path $PSScriptRoot -Parent

function Install-One {
    param([string]$Source, [string]$Target)

    if (-not (Test-Path $Source)) { throw "source missing: $Source" }

    $dir = Split-Path $Target -Parent
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'create directory')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    if (Test-Path $Target) {
        # Identical content is not worth a backup file; drift is.
        if ((Get-FileHash $Source).Hash -eq (Get-FileHash $Target).Hash) {
            Write-Host "  unchanged  $Target" -ForegroundColor DarkGray
            return
        }
        $backup = "$Target.bak-$stamp"
        if ($PSCmdlet.ShouldProcess($Target, "back up to $(Split-Path $backup -Leaf)")) {
            Copy-Item $Target $backup -Force
            Write-Host "  backed up  $(Split-Path $backup -Leaf)" -ForegroundColor Yellow
        }
    }

    if ($PSCmdlet.ShouldProcess($Target, 'install')) {
        Copy-Item $Source $Target -Force
        Write-Host "  installed  $Target" -ForegroundColor Green
    }
}

Write-Host "hermes home: $HermesHome"
Write-Host "codex home:  $CodexHome`n"

Install-One (Join-Path $repo 'configs\hermes\config.yaml') (Join-Path $HermesHome 'config.yaml')
Install-One (Join-Path $repo 'configs\codex\config.toml')  (Join-Path $CodexHome  'config.toml')

Write-Host @"

Two environment variables the config references by name, not value:

  HERMES_SKILLS_SERVER  full path to skills-mcp-server\dist\index.js
  HERMES_VENV_PYTHON    full path to the Hermes venv's python.exe

Set them for your user so Hermes resolves the two local MCP subprocesses:

  [Environment]::SetEnvironmentVariable('HERMES_SKILLS_SERVER','<path>','User')
  [Environment]::SetEnvironmentVariable('HERMES_VENV_PYTHON','<path>','User')

Then verify before routing any real work through it:

  pwsh -File scripts/hermes-verify.ps1
"@
