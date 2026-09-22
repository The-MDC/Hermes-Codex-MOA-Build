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
    $keyLeak = $false
    foreach ($shape in @('nvapi-[A-Za-z0-9_\-]{20,}', 'hf_[A-Za-z0-9]{30,}',
                         'sk-or-v1-[A-Za-z0-9]{20,}')) {
        if ($raw -match $shape) {
            Fail "config.yaml contains something shaped like a live key - rotate it, then move it to .env"
            $keyLeak = $true
        }
    }
    # Gated on THIS scan, not on $script:Fail. It used to read
    # `if ($script:Fail -eq 0)`, so any unrelated earlier failure -- `hermes` not
    # on PATH is enough -- silently swallowed the clean result. A security check
    # that goes quiet for a reason having nothing to do with security is worse
    # than one that is simply absent: the reader sees no line and cannot tell
    # whether it passed, failed, or never ran.
    if (-not $keyLeak) { Ok 'no key-shaped string in config.yaml' }

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
    # hermes-council's failure was interpreter substitution by the supervisor,
    # NOT a missing dependency -- see configs/hermes/config.yaml. Fixed by
    # pointing `command` at a launcher that pins the interpreter. If it is
    # erroring again, check which interpreter is actually being used before
    # touching any package version.
    if ($mcpOut -match 'hermes-council' -and $mcpOut -match '(?i)error|failed|unsupported') {
        Warn 'hermes-council is erroring - check WHICH interpreter it ran under (scripts/hermes-blockers.ps1) before suspecting packages'
    }
    if (-not $env:HERMES_COUNCIL_LAUNCHER) {
        Warn 'HERMES_COUNCIL_LAUNCHER not set - config.yaml names it as hermes-council''s command'
    } elseif (-not (Test-Path $env:HERMES_COUNCIL_LAUNCHER)) {
        Fail "HERMES_COUNCIL_LAUNCHER points at a missing file: $env:HERMES_COUNCIL_LAUNCHER"
    } else { Ok 'council launcher present' }
}

# The Codex MCP bridge. WARN, not FAIL, and the demotion is the point.
#
# `Unsupported` here is PERMANENT and not a fault of this install. Codex 0.154.0
# removed the `codex mcp-server` entry point on 2026-09-05; the replacement,
# `codex app-server`, speaks its own JSON-RPC 2.0 protocol and is not an MCP
# server. Codex is an MCP *client* now. No handshake exists to succeed.
#
# This used to raise Fail, which made the whole script unpassable: TAKEOVER.md
# phase 6.1 asks for `OK no failures` as the final gate, and on any box with
# codex on PATH that verdict could never be reached. A gate that cannot go green
# stops being read -- and then it hides the failures that ARE real. Worse, this
# script contradicted scripts/hermes-blockers.ps1, which already recommends
# option (a): do nothing, because delegation does not use this interface.
#
# Hermes reaches Codex as a SUBPROCESS via the bundled `codex` skill
# (docs/models/codex-handoff.md). That path is unaffected and is the supported
# one. Do not "fix" this by setting model.openai_runtime: codex_app_server --
# that routes Hermes' own reasoning through Codex and creates a second, invisible
# consumer of the same ChatGPT 5-hour window, which is exactly what
# `openai-codex` sits in excluded_providers to prevent.
#
# Gated on stage because line 26 says codex is not required until stage b, and
# this check ran at stage a regardless.
if ($codex -and $Stage -ne 'a') {
    $codexOut = (& codex mcp list 2>&1 | Out-String)
    if ($codexOut -match '(?i)unsupported') {
        Warn 'codex mcp list reports Unsupported - EXPECTED. The interface was removed upstream (Codex 0.154.0, 2026-09-05); Codex is MCP-client-only now. Delegation runs as a subprocess and is unaffected. Not a blocker, and not fixable here'
    } elseif ($codexOut -match 'hermes') { Ok 'codex bridge handshake OK' }
    else { Warn 'no hermes entry in codex mcp list - delegation uses the subprocess path, so this is informational' }
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

    # Read the endpoint and the model id OUT OF THE CONFIG BEING VERIFIED rather
    # than restating them here. THIS IS THE FIX FOR A BUG THIS FILE SHIPPED.
    #
    # These three lines used to carry literals. One of them probed OpenRouter for
    # `deepseek-ai/DeepSeek-V4.1-Flash` -- the Hugging Face repo id, which
    # OpenRouter does not serve under that name. Correcting config.yaml alone would
    # have left this script still probing the old id and reporting green; correcting
    # this script alone would have left Hermes still sending the wrong one. Two
    # copies of one fact, and either can be fixed without the other.
    #
    # So there is one copy now, and it is the one Hermes actually reads.
    #
    # Deliberately NOT a YAML parser. It reads two scalars out of a known block
    # shape and FAILS when it cannot find them. Falling back to a literal on a parse
    # miss would rebuild the exact hazard this replaces -- and a silent fallback is
    # the bug class this whole file exists to catch.
    function Get-ProviderField($provider, $field) {
        $lines = Get-Content $ConfigPath
        $start = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "^\s{2}$([regex]::Escape($provider))\s*:\s*$") { $start = $i; break }
        }
        if ($start -lt 0) { return $null }
        for ($i = $start + 1; $i -lt $lines.Count; $i++) {
            # A key at column 0 or 2 ends this provider's block. Everything that
            # belongs to it -- including its comments -- is indented 4.
            if ($lines[$i] -match '^\s{0,2}\S') { break }
            if ($lines[$i] -match "^\s{4}$([regex]::Escape($field))\s*:\s*(\S+)\s*$") {
                return $Matches[1]
            }
        }
        return $null
    }

    function Probe-Configured($name, $keyVar) {
        $url   = Get-ProviderField $name 'api'
        $model = Get-ProviderField $name 'default_model'
        if (-not $url -or -not $model) {
            Fail "could not read providers.$name (api / default_model) from $ConfigPath - refusing to guess; a probe against a guessed id proves nothing"
            return
        }
        Info "$name -> $model @ $url"
        Probe $name $url $keyVar $model
    }

    Probe-Configured 'hf-router'   'HF_TOKEN'
    Probe-Configured 'nvidia-nim'  'NVIDIA_API_KEY'
    Probe-Configured 'or-fallback' 'OPENROUTER_API_KEY'
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
