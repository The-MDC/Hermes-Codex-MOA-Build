<#
.SYNOPSIS
  Diagnose the two blockers carried over from the 2026-09-22 handoff.

.DESCRIPTION
  Neither blocks the model tiers, so neither should stop a bring-up. Both were
  reported as "broken" with no root cause attached, and a wrong guess at either
  costs a session. This separates what is measurable from what is a judgment call.

    1. hermes-council raises ModuleNotFoundError: No module named 'mcp.server.fastmcp'
    2. codex mcp list reports the bridge as Unsupported

  DIAGNOSES ONLY. Changes nothing, and there is no -Fix.

  A -Fix switch used to be declared and advertised here, and no code path ever
  read it: passing it did nothing, silently. An option that is documented but
  inert is worse than no option, because the reader believes a repair was
  attempted. It is removed rather than implemented, because neither blocker has
  a mechanical answer worth automating -- the council fault is an interpreter to
  PIN (the script prints the exact SetEnvironmentVariable line to paste), and the
  Codex handshake cannot be repaired at all: the interface it wants was removed
  upstream, so the decision is which of three options to take, not which command
  to run.

.EXAMPLE
  pwsh -File scripts/hermes-blockers.ps1
#>
[CmdletBinding()]
param()

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
Section 'blocker 1 - hermes-council interpreter'

# THIS SECTION USED TO TEST THE WRONG HYPOTHESIS, and the wrong one was very
# convincing. The error was:
#     ModuleNotFoundError: No module named 'mcp.server.fastmcp'
# An error naming a module invites the inference that the module is missing, so
# this script previously compared `mcp` and `fastmcp` package versions inside the
# Hermes venv and offered pins to reconcile them.
#
# That was wrong. The package imports FINE under the interpreter it was installed
# into. The Hermes supervisor was substituting its own bundled Python, so the
# import ran somewhere the packages had never been installed.
#
# So the question is not "which packages are present" -- it is "WHICH INTERPRETER
# actually runs, and does THAT one have them". This section answers that by
# testing every candidate interpreter independently and naming which ones work.

$candidates = [ordered]@{}
if ($env:HERMES_COUNCIL_PYTHON) { $candidates['HERMES_COUNCIL_PYTHON'] = $env:HERMES_COUNCIL_PYTHON }
$globalPy = (Get-Command python -ErrorAction SilentlyContinue).Source
if ($globalPy) { $candidates['global python'] = $globalPy }
$venvPy = Join-Path $HermesHome 'hermes-agent\venv\Scripts\python.exe'
if (Test-Path $venvPy) { $candidates['hermes venv'] = $venvPy }
if ($env:HERMES_VENV_PYTHON) { $candidates['HERMES_VENV_PYTHON'] = $env:HERMES_VENV_PYTHON }

if (-not $candidates.Count) {
    Bad 'no candidate interpreter found at all'
    Act 'Install Python, or set HERMES_COUNCIL_PYTHON to the one holding hermes_council.'
} else {
    $probe = @'
import importlib, json, sys
out = {"exe": sys.executable, "ver": "%d.%d.%d" % sys.version_info[:3]}
for name in ("hermes_council", "mcp", "mcp.server.fastmcp", "fastmcp"):
    try:
        importlib.import_module(name); out[name] = "ok"
    except Exception as e:
        out[name] = type(e).__name__
print(json.dumps(out))
'@

    $working = @()
    foreach ($label in $candidates.Keys) {
        $exe = $candidates[$label]
        if (-not (Test-Path $exe)) { Bad "$label -> $exe (does not exist)"; continue }
        $raw = ($probe | & $exe - 2>&1 | Out-String).Trim()
        try { $r = $raw | ConvertFrom-Json } catch { Bad "$label -> $exe (probe failed: $($raw -split "`n" | Select-Object -First 1))"; continue }

        # hermes_council is the one that decides whether this interpreter can serve.
        # The fastmcp line is reported for context only -- it is NOT the gate, and
        # treating it as the gate is exactly the mistake this section corrects.
        if ($r.hermes_council -eq 'ok') {
            Ok "$label -> $exe  (py $($r.ver)) imports hermes_council"
            $working += ,@($label, $exe)
        } else {
            Info "$label -> $exe  (py $($r.ver)) cannot import hermes_council: $($r.hermes_council)"
        }
        Info "     mcp=$($r.mcp)  mcp.server.fastmcp=$($r.'mcp.server.fastmcp')  fastmcp=$($r.fastmcp)"
    }

    Write-Host ''
    if (-not $working.Count) {
        Bad 'NO interpreter on this machine can import hermes_council'
        Act 'That is a genuine install problem. pip install the package into ONE'
        Act 'interpreter, then point HERMES_COUNCIL_PYTHON at exactly that one.'
    } else {
        Ok "$($working.Count) interpreter(s) can serve hermes_council"

        # The actual failure mode: a working interpreter exists, but the MCP entry
        # does not pin it, so the supervisor is free to pick a different one.
        $pinned = $env:HERMES_COUNCIL_PYTHON
        if (-not $pinned) {
            Bad 'HERMES_COUNCIL_PYTHON is NOT set - nothing pins the interpreter'
            Act "Pin the one that works:"
            Act "  [Environment]::SetEnvironmentVariable('HERMES_COUNCIL_PYTHON','$($working[0][1])','User')"
        } elseif ($working.Where({ $_[1] -eq $pinned }).Count) {
            Ok "HERMES_COUNCIL_PYTHON pins a working interpreter"
        } else {
            Bad "HERMES_COUNCIL_PYTHON pins $pinned, which CANNOT import hermes_council"
            Act "Repoint it at: $($working[0][1])"
        }

        $launcher = $env:HERMES_COUNCIL_LAUNCHER
        if (-not $launcher) {
            Bad 'HERMES_COUNCIL_LAUNCHER is NOT set - config.yaml names it as the command'
            Act 'Point it at scripts\hermes-council-launch.cmd in this repo.'
        } elseif (-not (Test-Path $launcher)) {
            Bad "HERMES_COUNCIL_LAUNCHER points at a missing file: $launcher"
        } else {
            Ok "launcher present: $launcher"
        }
    }
}

# The same exposure, one layer out. Any MCP entry whose `command` names a runtime
# can have that runtime substituted; only `url:` entries are immune. A substituted
# Node fails as misleadingly as a substituted Python did.
Section 'blocker 1b - other command: MCP entries with the same exposure'
foreach ($pair in @(@('atomicmemory','npx'), @('hermes-skills','node'))) {
    $cmd = Get-Command $pair[1] -ErrorAction SilentlyContinue
    if ($cmd) { Info "$($pair[0]) uses '$($pair[1])' -> $($cmd.Source)" }
    else { Warn "$($pair[0]) uses '$($pair[1])', which is not on PATH" }
}
Info 'If either starts failing with a missing-module error, check which runtime'
Info 'actually ran before touching any package. Same trap, different language.'

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
