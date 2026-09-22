<#
.SYNOPSIS
  Verify a deployed Hermes install against configs/hermes/config.yaml.

.DESCRIPTION
  Answers one question: does the machine actually match what the repo says?

  CI can only check the config FILE. It cannot see whether `hermes` is installed,
  whether Ollama holds the models the config names, or whether an endpoint
  answers. Every silent failure recorded in docs/models/handoff-2026-09-22.md was
  of that second kind: a reference that is valid on paper and dangling on disk.

  Read-only. Changes nothing, starts nothing, prints no secret.

.EXAMPLE
  pwsh -File scripts/hermes-verify.ps1
  pwsh -File scripts/hermes-verify.ps1 -Deep     # also calls the remote endpoints
#>
[CmdletBinding()]
param(
    # Which bring-up phase to check. The stack comes up in stages, and a stage
    # gate that fails on something the NEXT stage installs is a gate nobody can
    # pass -- so each stage only requires what it was supposed to deliver.
    #
    #   a     hermes3:8b only. The minimal working floor.
    #   b     adds nemotron-nano:12b-v2 and the Codex bridge.
    #   full  everything, including the hosted MCP servers. (default)
    [ValidateSet('a', 'b', 'full')]
    [string]$Stage = 'full',

    # Also make one live request per remote provider. Costs a few tokens and
    # proves the key works, which no local check can.
    [switch]$Deep
)

$ErrorActionPreference = 'Continue'
$script:Fail = 0
$script:Warn = 0

function Section($t) { Write-Host "`n$t" -ForegroundColor Cyan }
function Ok($m)      { Write-Host "  ok    $m" -ForegroundColor Green }
function Warn($m)    { Write-Host "  warn  $m" -ForegroundColor Yellow; $script:Warn++ }
function Fail($m)    { Write-Host "  FAIL  $m" -ForegroundColor Red;    $script:Fail++ }
function Info($m)    { Write-Host "  ..    $m" -ForegroundColor DarkGray }

Write-Host "verifying stage '$Stage'" -ForegroundColor Cyan

$HermesHome = if ($env:HERMES_HOME) { $env:HERMES_HOME }
              else { Join-Path $env:LOCALAPPDATA 'hermes' }
$ConfigPath = Join-Path $HermesHome 'config.yaml'
$EnvPath    = Join-Path $HermesHome '.env'

# ---------------------------------------------------------------- toolchain
Section 'toolchain'

$hermes = Get-Command hermes -ErrorAction SilentlyContinue
if ($hermes) { Ok "hermes: $((& hermes --version 2>&1 | Select-Object -First 1))" }
else { Fail 'hermes not on PATH - nothing below can be trusted' }

$ollama = Get-Command ollama -ErrorAction SilentlyContinue
if ($ollama) { Ok "ollama: $((& ollama --version 2>&1 | Select-Object -First 1))" }
else { Fail 'ollama not on PATH - the local tier and 5 auxiliary slots have no backend' }

$codex = Get-Command codex -ErrorAction SilentlyContinue
if ($codex) { Ok "codex: $((& codex --version 2>&1 | Select-Object -First 1))" }
elseif ($Stage -eq 'a') { Info 'codex not on PATH - not required until stage b' }
else { Warn 'codex not on PATH - delegation to Codex will fail, everything else is fine' }

# ---------------------------------------------------------------- config
Section 'config'

if (-not (Test-Path $ConfigPath)) {
    Fail "no config at $ConfigPath - run scripts/hermes-apply.ps1 first"
} else {
    $raw = Get-Content $ConfigPath -Raw
    Ok "config present: $ConfigPath"

    # The four provider keys every reference in the repo config resolves through.
    # A rename here is the exact failure that dangles every custom: reference.
    foreach ($p in @('hf-router', 'nvidia-nim', 'or-fallback', 'local')) {
        if ($raw -match "(?m)^\s{2}$([regex]::Escape($p))\s*:") { Ok "provider '$p' defined" }
        else { Fail "provider '$p' is MISSING - every custom:$p reference dangles" }
    }

    # An inline key here would be committed-shaped and is the repo's one hard rule.
    # Match the shape, never print the match.
    foreach ($shape in @('nvapi-[A-Za-z0-9_\-]{20,}', 'hf_[A-Za-z0-9]{30,}',
                         'sk-or-v1-[A-Za-z0-9]{20,}')) {
        if ($raw -match $shape) { Fail "config.yaml contains something shaped like a live key - rotate it, then move it to .env" }
    }
    if ($script:Fail -eq 0) { Ok 'no key-shaped string in config.yaml' }

    # Render carried an inline bearer token in an earlier revision of this file.
    if ($raw -match '(?m)^\s{2}render\s*:') {
        Warn 'render MCP is present - it failed DNS repeatedly and once held an inline token. Confirm the token was rotated.'
    } else { Ok 'render MCP absent, as intended' }
}

if (-not (Test-Path $EnvPath)) {
    Fail "no .env at $EnvPath - every remote provider reads its key from there"
} else {
    $envRaw = Get-Content $EnvPath -Raw
    foreach ($k in @('NVIDIA_API_KEY', 'HF_TOKEN', 'OPENROUTER_API_KEY')) {
        # Presence only. The value is never read, printed, or length-checked.
        if ($envRaw -match "(?m)^\s*$k\s*=\s*\S") { Ok "$k is set" }
        else { Warn "$k not set - the tier that uses it will fail over" }
    }
}

# ---------------------------------------------------------------- local models
Section 'local models (Ollama)'

if ($ollama) {
    $tags = (& ollama list 2>&1 | Out-String)
    # These names must match `providers.local.models` in the repo config exactly.
    # A tag mismatch is not a loud failure: Hermes resolves the miss by falling
    # back to the main model, so you get an answer from the wrong tier.
    #
    # Stage a ships hermes3:8b alone, so the heavier model is only REQUIRED from
    # stage b onward. It is still reported at stage a, as information.
    $required = if ($Stage -eq 'a') { @('hermes3:8b') }
                else { @('hermes3:8b', 'nemotron-nano:12b-v2') }
    foreach ($m in @('hermes3:8b', 'nemotron-nano:12b-v2')) {
        if ($tags -match [regex]::Escape($m)) { Ok "$m present" }
        elseif ($m -in $required) {
            Fail "$m NOT in Ollama - config.yaml names it, so selecting it silently falls back"
        }
        else { Info "$m not present yet - not required until stage b" }
    }

    $port = Test-NetConnection -ComputerName '127.0.0.1' -Port 11434 `
                -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($port) { Ok 'Ollama answering on 127.0.0.1:11434' }
    else { Fail 'nothing listening on 127.0.0.1:11434 - run `ollama serve`' }
}

# ---------------------------------------------------------------- MCP
Section 'MCP servers'

if ($hermes) {
    $mcpOut = (& hermes mcp list 2>&1 | Out-String)
    $expected = switch ($Stage) {
        'a'  { @('crawl4ai', 'atomicmemory') }
        'b'  { @('crawl4ai', 'atomicmemory', 'hermes-skills') }
        default { @('voicebox', 'crawl4ai', 'atomicmemory', 'hermes-skills',
                    'hermes-council', 'cloudflare', 'submcp') }
    }
    foreach ($s in $expected) {
        if ($mcpOut -match [regex]::Escape($s)) { Ok "$s registered" }
        else { Warn "$s not listed by 'hermes mcp list'" }
    }
    # Known broken as of 2026-09-22; surfaced rather than assumed fixed.
    if ($mcpOut -match 'hermes-council' -and $mcpOut -match '(?i)error|failed|unsupported') {
        Warn 'hermes-council may still be raising ModuleNotFoundError on mcp.server.fastmcp'
    }
}

if ($codex) {
    $codexOut = (& codex mcp list 2>&1 | Out-String)
    if ($codexOut -match '(?i)unsupported') {
        Fail 'codex mcp list reports Unsupported - the bridge is registered but the handshake fails (protocol version mismatch, not a missing install)'
    } elseif ($codexOut -match 'hermes') { Ok 'codex bridge handshake OK' }
    else { Warn 'no hermes entry in codex mcp list' }
}

# ---------------------------------------------------------------- endpoints
if ($Deep) {
    Section 'endpoints (live, one request each)'

    # Keys live in $HERMES_HOME\.env, which Hermes reads at runtime -- they are
    # NOT normally exported into an interactive shell. Reading only the process
    # environment meant -Deep skipped every probe on a correctly configured box
    # and reported it as "not set", which looks like a finding and is not one.
    function Get-ProviderKey($keyVar) {
        $v = [Environment]::GetEnvironmentVariable($keyVar)
        if ($v) { return $v }
        if (Test-Path $EnvPath) {
            foreach ($line in Get-Content $EnvPath) {
                if ($line -match "^\s*$([regex]::Escape($keyVar))\s*=\s*(.+?)\s*$") {
                    return $Matches[1].Trim('"').Trim("'")
                }
            }
        }
        return $null
    }

    # Two questions, and one request cannot answer both. A failed completion looks
    # identical whether the model id is wrong or the account is out of quota, so
    # the catalog is checked FIRST: it isolates "this id does not exist here",
    # which is the failure this repo keeps hitting and CI cannot see.
    function Probe($name, $url, $keyVar, $model) {
        $key = Get-ProviderKey $keyVar
        if (-not $key) { Warn "$name skipped - $keyVar not in the environment or $EnvPath"; return }
        $auth = @{ Authorization = "Bearer $key" }

        try {
            $cat = Invoke-RestMethod -Method Get -Uri "$url/models" -Headers $auth -TimeoutSec 30
            $ids = @($cat.data | ForEach-Object { $_.id })
            if ($ids -contains $model) {
                Ok "$name catalog lists '$model' ($($ids.Count) models visible to this key)"
            } else {
                Fail "$name catalog does NOT list '$model' - the id is wrong for this provider, not a quota problem ($($ids.Count) models visible)"
                $near = @($ids | Where-Object { $_ -match 'deepseek|nemotron' } | Select-Object -First 5)
                if ($near) { Info "closest ids here: $($near -join ', ')" }
            }
        } catch {
            Warn "$name catalog unreadable: $($_.Exception.Message)"
        }

        try {
            $body = @{ model = $model
                       messages = @(@{ role = 'user'; content = 'ping' })
                       max_tokens = 1 } | ConvertTo-Json -Depth 5
            $r = Invoke-RestMethod -Method Post -Uri "$url/chat/completions" `
                    -Headers $auth -ContentType 'application/json' `
                    -Body $body -TimeoutSec 60
            # Echo the id the endpoint RETURNED, not the one we asked for: a router
            # that silently substitutes a model is invisible any other way.
            if ($r.model -and $r.model -ne $model) {
                Warn "$name answered as '$($r.model)', NOT the '$model' we asked for - silent substitution"
            } else {
                Ok "$name served '$($r.model)'"
            }
        } catch {
            Fail "$name did not answer for '$model': $($_.Exception.Message)"
        }
    }

    Probe 'hf-router'   'https://router.huggingface.co/v1'     'HF_TOKEN'           'deepseek-ai/DeepSeek-V4-Pro'
    Probe 'nvidia-nim'  'https://integrate.api.nvidia.com/v1'  'NVIDIA_API_KEY'     'nvidia/nemotron-3-super-120b-a12b'
    Probe 'or-fallback' 'https://openrouter.ai/api/v1'         'OPENROUTER_API_KEY' 'deepseek-ai/DeepSeek-V4.1-Flash'
}

# ---------------------------------------------------------------- verdict
Write-Host ''
if ($script:Fail -gt 0) {
    Write-Host "FAILED  $($script:Fail) failure(s), $($script:Warn) warning(s)" -ForegroundColor Red
    Write-Host 'Do not route production work through this install until the failures above are cleared.'
    exit 1
}
Write-Host "OK      no failures, $($script:Warn) warning(s)" -ForegroundColor Green
exit 0
