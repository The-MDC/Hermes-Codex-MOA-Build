<#
.SYNOPSIS
  Diagnose the two blockers carried over from the 2026-09-22 handoff.

.DESCRIPTION
  Neither blocks the model tiers, so neither should stop a bring-up. Both were
  reported as "broken" with no root cause attached, and a wrong guess at either
  costs a session. This separates what is measurable from what is a judgment call.

    1. hermes-council raises ModuleNotFoundError: No module named 'mcp.server.fastmcp'
    2. codex mcp list reports the bridge as Unsupported

  Diagnoses by default and changes nothing. -Fix applies ONLY the council
  dependency repair, which is the one with a mechanical answer. The Codex
  handshake is deliberately never auto-fixed: the interface it needs was removed
  upstream, so the repair is a design decision, not an install.

.EXAMPLE
  pwsh -File scripts/hermes-blockers.ps1
  pwsh -File scripts/hermes-blockers.ps1 -Fix
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Apply the council dependency repair. Does not touch Codex.
    [switch]$Fix
)

$ErrorActionPreference = 'Continue'

function Section($t) { Write-Host "`n$t" -ForegroundColor Cyan }
function Ok($m)      { Write-Host "  ok    $m" -ForegroundColor Green }
function Info($m)    { Write-Host "  ..    $m" -ForegroundColor DarkGray }
function Warn($m)    { Write-Host "  warn  $m" -ForegroundColor Yellow }
function Bad($m)     { Write-Host "  FAIL  $m" -ForegroundColor Red }
function Act($m)     { Write-Host "  ->    $m" -ForegroundColor Magenta }

$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
              else { Join-Path $env:LOCALAPPDATA 'hermes' }
$VenvPython = if ($env:HERMES_VENV_PYTHON) { $env:HERMES_VENV_PYTHON }
              else { Join-Path $HermesHome 'hermes-agent\venv\Scripts\python.exe' }

# ============================================================ BLOCKER 1 =====
Section 'blocker 1 - hermes-council / mcp.server.fastmcp'

if (-not (Test-Path $VenvPython)) {
    Bad "no python at $VenvPython"
    Act 'Set HERMES_VENV_PYTHON to the Hermes venv interpreter, then re-run.'
} else {
    Ok "venv python: $VenvPython"

    # What is actually installed. `mcp` and `fastmcp` are DIFFERENT packages and
    # the import path moved between them, which is the whole bug.
    $pkgs = & $VenvPython -m pip list --format=json 2>$null | ConvertFrom-Json
    $mcpPkg      = $pkgs | Where-Object { $_.name -eq 'mcp' }
    $fastmcpPkg  = $pkgs | Where-Object { $_.name -eq 'fastmcp' }
    $councilPkg  = $pkgs | Where-Object { $_.name -like '*hermes*council*' }

    if ($mcpPkg)     { Ok "mcp==$($mcpPkg.version)" }     else { Bad 'mcp is NOT installed' }
    if ($fastmcpPkg) { Ok "fastmcp==$($fastmcpPkg.version) (standalone)" }
                     else { Info 'fastmcp (standalone) not installed' }
    if ($councilPkg) { Ok "$($councilPkg.name)==$($councilPkg.version)" }
                     else { Warn 'no hermes-council package found in this venv' }

    # Probe the three import paths independently. Which ones resolve tells you
    # which of the two packages the server should be importing from.
    $probe = @'
import importlib, json
out = {}
for name in ("mcp", "mcp.server", "mcp.server.fastmcp", "fastmcp", "hermes_council"):
    try:
        importlib.import_module(name); out[name] = "ok"
    except Exception as e:
        out[name] = type(e).__name__ + ": " + str(e)[:80]
print(json.dumps(out))
'@
    $res = ($probe | & $VenvPython - 2>&1 | Out-String).Trim()
    try { $imports = $res | ConvertFrom-Json } catch { $imports = $null }

    if ($imports) {
        foreach ($k in 'mcp','mcp.server','mcp.server.fastmcp','fastmcp','hermes_council') {
            $v = $imports.$k
            if ($v -eq 'ok') { Ok "import $k" } else { Bad "import $k -> $v" }
        }

        if ($imports.'mcp.server.fastmcp' -eq 'ok') {
            Ok 'the reported blocker does NOT reproduce - the import path resolves'
            Act 'Re-enable hermes-council in configs/hermes/config.yaml and restart the gateway.'
        }
        elseif ($imports.'fastmcp' -eq 'ok') {
            Warn 'fastmcp exists only as the STANDALONE package, not under mcp.server'
            Info 'FastMCP was vendored into the mcp SDK as mcp.server.fastmcp, then split back'
            Info 'out. hermes_council imports the vendored path; this venv has the split one.'
            Act 'Two repairs, and they are not equivalent:'
            Act '  (a) pin the SDK back:  pip install "mcp>=1.2,<2"   - keeps hermes_council unmodified'
            Act '  (b) patch the import in hermes_council to use fastmcp - survives future SDK moves'
            Act 'Prefer (a) unless you maintain hermes_council. -Fix applies (a).'
            if ($Fix -and $PSCmdlet.ShouldProcess('hermes venv', 'pip install "mcp>=1.2,<2"')) {
                & $VenvPython -m pip install "mcp>=1.2,<2"
                $after = ('import importlib
try:
    importlib.import_module("mcp.server.fastmcp"); print("RESOLVED")
except Exception as e:
    print("STILL BROKEN:", e)' | & $VenvPython - 2>&1 | Out-String).Trim()
                if ($after -match 'RESOLVED') { Ok 'mcp.server.fastmcp now imports' }
                else { Bad $after; Act 'Escalate - repair (b) is the remaining path.' }
            }
        }
        else {
            Bad 'neither mcp.server.fastmcp nor fastmcp resolves'
            Act 'pip install "mcp>=1.2,<2" in this venv, then re-run this script.'
            if ($Fix -and $PSCmdlet.ShouldProcess('hermes venv', 'pip install "mcp>=1.2,<2"')) {
                & $VenvPython -m pip install "mcp>=1.2,<2"
            }
        }
    } else {
        Bad 'import probe produced no parseable output'
        Info $res
    }
}

# ============================================================ BLOCKER 2 =====
Section 'blocker 2 - codex bridge reports Unsupported'

$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) {
    Bad 'codex not on PATH'
} else {
    $ver = (& codex --version 2>&1 | Select-Object -First 1)
    Ok "codex: $ver"

    $listing = (& codex mcp list 2>&1 | Out-String)
    if ($listing -match '(?i)unsupported') {
        Bad 'codex mcp list reports Unsupported'
        Info 'The binary and the registration both exist, so this is a PROTOCOL'
        Info 'mismatch, not a missing install. `codex mcp-server` and the standalone'
        Info '`codex-mcp-server` binary were REMOVED on 2026-09-05. The replacement is'
        Info '`codex app-server`: JSON-RPC 2.0 over stdio/websocket/unix socket.'
        Info 'One official docs page still documents the removed tool - it is stale.'
        Write-Host ''
        Act 'This is NOT auto-fixable and NOT urgent. Three options:'
        Act '  (a) Do nothing. Hermes reaches Codex as a SUBPROCESS via the bundled'
        Act '      `codex` skill, which does not use this interface at all. Delegation'
        Act '      already works. This is the documented design (codex-handoff.md).'
        Act '  (b) Port the bridge to `codex app-server` - a second protocol client to'
        Act '      build and maintain. Worth it only if handoff volume justifies it.'
        Act '  (c) Unregister the bridge so the Unsupported line stops reading as a'
        Act '      fault:  codex mcp remove <name>'
        Act 'Recommendation: (a). Verify delegation works before spending time here.'
    }
    elseif ($listing -match '(?i)hermes') {
        Ok 'bridge registered, no Unsupported status'
    }
    else {
        Warn 'no hermes entry in codex mcp list'
        Info $listing.Trim()
    }

    foreach ($p in @("$HOME\.codex\config.toml",
                     "$HOME\.codex\agents\hermes-bridge.toml",
                     "$HOME\.codex\agents\hermes-research.toml")) {
        if (Test-Path $p) { Ok "present: $p" } else { Warn "missing: $p" }
    }

    # The repo's Codex template deliberately sets no inference route. A custom
    # route here would make the ChatGPT 5-hour window spend invisible to itself.
    $cfg = "$HOME\.codex\config.toml"
    if (Test-Path $cfg) {
        $c = Get-Content $cfg -Raw
        $bad = @('model_provider','model_providers','openai_base_url','chatgpt_base_url') |
               Where-Object { $c -match "(?m)^\s*\[?$_" }
        if ($bad) { Bad "config.toml sets $($bad -join ', ') - opens a second, silent inference route" }
        else      { Ok 'config.toml opens no custom inference route' }
    }
}

Write-Host "`nNeither blocker gates the model tiers. Continue the bring-up." -ForegroundColor Cyan
