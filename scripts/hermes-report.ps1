<#
.SYNOPSIS
  Inventory a Hermes/Codex install and print a report that is SAFE TO PASTE.

.DESCRIPTION
  WHY THIS EXISTS
      Everything in this repo is config and scripts. The people and sessions that
      write it cannot see the machine it lands on -- a cloud session runs in a Linux
      container with no path to a Windows desktop, no device link, and no way to
      read %LOCALAPPDATA%\hermes. So every question about the real install ("is the
      model pulled", "which env vars are set", "are the .bak files still there")
      has been answered by guessing, and several of those guesses were wrong.

      This closes that loop in the one direction that works: you run it, you paste
      the output back.

  SAFE TO PASTE, BY CONSTRUCTION, NOT BY CARE
      Two independent mechanisms, because one is not enough for a file whose whole
      job is to describe a directory that contains credentials.

      1. Values are never read. The .env reader captures the NAME and the LENGTH of
         each entry and discards the value in the same expression. There is no code
         path that puts a credential into a variable that reaches output.
      2. Every line printed goes through Scrub() first, which replaces anything
         key-SHAPED with [REDACTED] -- covering files this script did not expect to
         contain secrets, like a config.yaml.bak-* that carries an inline token.

      Mechanism 2 is the one that matters. Mechanism 1 protects what we anticipated;
      mechanism 2 protects what we did not. The Render bearer token that this repo
      has been chasing since 2026-09-22 got loose through a file nobody expected to
      be sensitive, which is exactly the case mechanism 1 alone would miss.

      It still is not a promise. Read the output before you paste it.

  READ-ONLY. Starts nothing, installs nothing, writes nothing except -OutFile.

.EXAMPLE
  pwsh -File scripts/hermes-report.ps1
  pwsh -File scripts/hermes-report.ps1 -OutFile "$HOME\hermes-report.txt"
#>
[CmdletBinding()]
param(
    # Write the report to a file as well as the console. The file gets the same
    # scrubbing -- there is no unredacted path out of this script.
    [string]$OutFile,

    # Directory to inventory. Defaults to HERMES_HOME, else %LOCALAPPDATA%\hermes.
    [string]$HermesHome = $(if ($env:HERMES_HOME) { $env:HERMES_HOME }
                           else { Join-Path $env:LOCALAPPDATA 'hermes' })
)

# SilentlyContinue, and this is a SAFETY setting rather than a cosmetic one.
#
# An uncaught cmdlet error writes to stderr DIRECTLY, bypassing Say() and therefore
# bypassing Scrub(). That is an unredacted path out of a script whose entire purpose
# is to describe a directory full of credentials. It is not hypothetical: an early
# revision called Get-Acl, which does not exist off Windows, and the resulting error
# printed unscrubbed. It happened to quote only a line of this script -- but a
# cmdlet that failed while reading a file could quote that file's contents instead.
#
# So: no error surfaces on its own. Everything that touches the filesystem is
# wrapped, and anything worth telling the reader is told through Say().
$ErrorActionPreference = 'SilentlyContinue'

# Ordered longest-first so a specific prefix wins over the generic blob rule.
$KeyShapes = @(
    'github_pat_[A-Za-z0-9_]{16,}',
    'sk-or-v1-[A-Za-z0-9]{12,}',
    'nvapi-[A-Za-z0-9_\-]{12,}',
    'xox[baprs]-[A-Za-z0-9\-]{10,}',
    'AIza[A-Za-z0-9_\-]{20,}',
    'ghp_[A-Za-z0-9]{16,}',
    'hf_[A-Za-z0-9]{16,}',
    'rnd_[A-Za-z0-9]{12,}',
    'vcp_[A-Za-z0-9]{12,}',
    'sk-[A-Za-z0-9]{20,}',
    'eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}',   # JWT
    'postgres(?:ql)?://[^\s''"]+',                    # connection strings carry passwords
    '[A-Za-z0-9+/]{50,}={0,2}'                        # long opaque blob, last resort
)

function Scrub([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }
    foreach ($shape in $KeyShapes) {
        $s = [regex]::Replace($s, $shape, '[REDACTED]')
    }
    return $s
}

# EVERY line goes through here. Nothing calls Write-Host directly below.
$script:Lines = @()
function Say([string]$m = '') {
    $safe = Scrub $m
    $script:Lines += $safe
    Write-Host $safe
}
function Head([string]$t) { Say ''; Say $t; Say ('-' * $t.Length) }

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Ver($cmd, $arg) {
    if (-not (Have $cmd)) { return 'NOT ON PATH' }
    try { (& $cmd $arg 2>&1 | Out-String).Trim() -replace '\r?\n.*', '' }
    catch { "present, version unreadable" }
}

Say "Hermes/Codex install report"
Say ("generated {0}  on {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $env:COMPUTERNAME)
Say "SAFE TO PASTE - values are never read, and all output is scrubbed of key shapes."
Say "Read it before pasting anyway."

# ------------------------------------------------------------------ toolchain
Head 'toolchain'
Say ("  pwsh       {0}" -f $PSVersionTable.PSVersion)
Say ("  hermes     {0}" -f (Ver 'hermes' '--version'))
Say ("  ollama     {0}" -f (Ver 'ollama' '--version'))
Say ("  codex      {0}" -f (Ver 'codex' '--version'))
Say ("  python     {0}" -f (Ver 'python' '--version'))
Say ("  node       {0}" -f (Ver 'node' '--version'))

# ------------------------------------------------------------- hermes home
Head "hermes home: $HermesHome"
if (-not (Test-Path $HermesHome)) {
    Say '  DOES NOT EXIST - nothing has been installed here yet'
} else {
    $items = Get-ChildItem $HermesHome -Recurse -Depth 2 -ErrorAction SilentlyContinue |
             Sort-Object FullName
    Say ("  {0} entr(ies), depth 2" -f $items.Count)
    foreach ($i in $items) {
        $rel = $i.FullName.Substring($HermesHome.Length).TrimStart('\')
        if ($i.PSIsContainer) {
            Say ("    [dir ] {0}" -f $rel)
        } else {
            Say ("    [file] {0,-52} {1,10:N0} B  {2:yyyy-MM-dd HH:mm}" -f
                 $rel, $i.Length, $i.LastWriteTime)
        }
    }
}

# --------------------------------------------------- the .bak question (Render)
Head 'config backups  (this answers the Render token question)'
$baks = @()
if (Test-Path $HermesHome) {
    $baks = @(Get-ChildItem $HermesHome -Filter 'config.yaml.bak-*' -ErrorAction SilentlyContinue)
}
if (-not $baks -or $baks.Count -eq 0) {
    Say '  none present.'
    Say '  If shell history is also clear, the Render assertion in three files is stale'
    Say '  and should be removed rather than left asserting something untrue.'
} else {
    Say ("  {0} backup file(s) present:" -f $baks.Count)
    foreach ($b in $baks) {
        # Count key-shaped matches. Report the COUNT and the family, never the match.
        $hits = 0
        $families = @()
        try {
            $raw = Get-Content $b.FullName -Raw -ErrorAction Stop
            foreach ($shape in $KeyShapes) {
                $m = [regex]::Matches($raw, $shape)
                if ($m.Count) {
                    $hits += $m.Count
                    $families += ($shape -replace '\[.*$', '' -replace '\\', '')
                }
            }
        } catch { $families = @('unreadable') }
        $verdict = if ($hits -gt 0) {
            "*** {0} KEY-SHAPED STRING(S): {1} -- ROTATE, then delete this file" -f
                $hits, (($families | Select-Object -Unique) -join ', ')
        } else { 'no key-shaped string found' }
        Say ("    {0,-34} {1,10:N0} B  {2:yyyy-MM-dd}" -f $b.Name, $b.Length, $b.LastWriteTime)
        Say ("      -> {0}" -f $verdict)
    }
    Say ''
    Say '  Deleting a backup does not un-expose a credential that was in it.'
    Say '  Rotate first, in the provider dashboard, THEN delete.'
}

# ------------------------------------------------------------------- .env
Head '.env  (NAMES AND LENGTHS ONLY - no value is ever read into a variable)'
$envPath = Join-Path $HermesHome '.env'
if (-not (Test-Path $envPath)) {
    Say "  MISSING at $envPath"
    Say '  Every remote provider reads its key from here. See VSCODE-QUICKSTART.md 3.1.'
} else {
    $info = Get-Item $envPath
    Say ("  present, {0:N0} B, modified {1:yyyy-MM-dd HH:mm}" -f $info.Length, $info.LastWriteTime)
    $seen = @{}
    foreach ($line in (Get-Content $envPath)) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(.*)$') {
            $n = $Matches[1]
            # The value's LENGTH is computed and the value discarded here.
            $len = $Matches[2].Trim().Trim('"').Trim("'").Length
            $seen[$n] = $len
            Say ("    {0,-24} {1}" -f $n, $(if ($len) { "set, $len chars" } else { 'EMPTY' }))
        }
    }
    foreach ($req in @('NVIDIA_API_KEY', 'HF_TOKEN', 'OPENROUTER_API_KEY')) {
        if (-not $seen.ContainsKey($req)) {
            Say ("    {0,-24} MISSING - that tier will fail over silently" -f $req)
        }
    }
}

# --------------------------------------------------------- environment vars
Head 'environment variables the config references by name'
foreach ($v in @('HERMES_HOME', 'HERMES_SKILLS_SERVER', 'HERMES_COUNCIL_LAUNCHER',
                 'HERMES_COUNCIL_PYTHON', 'HERMES_VENV_PYTHON')) {
    $val = [Environment]::GetEnvironmentVariable($v)
    if (-not $val) {
        $note = if ($v -eq 'HERMES_VENV_PYTHON') { 'unset - CORRECT, it is obsolete' } else { 'NOT SET' }
        Say ("  {0,-24} {1}" -f $v, $note)
    } else {
        $exists = if ($v -match 'PYTHON|LAUNCHER|SERVER') {
            if (Test-Path $val) { 'path exists' } else { 'PATH DOES NOT EXIST' }
        } else { '' }
        Say ("  {0,-24} {1}  {2}" -f $v, $val, $exists)
        if ($v -eq 'HERMES_VENV_PYTHON') {
            Say '      ^ obsolete. Pointing at the venv was the bug; use HERMES_COUNCIL_PYTHON.'
        }
    }
}

# ------------------------------------------------------------ local models
Head 'Ollama'
if (-not (Have 'ollama')) {
    Say '  ollama NOT ON PATH - the local floor and 5 auxiliary slots have no backend'
} else {
    $tags = (& ollama list 2>&1 | Out-String)
    foreach ($m in @('hermes3:8b', 'nemotron-nano:12b-v2')) {
        Say ("  {0,-24} {1}" -f $m, $(if ($tags -match [regex]::Escape($m)) { 'PRESENT' } else { 'ABSENT' }))
    }
    Say '  full list:'
    foreach ($l in ($tags -split '\r?\n' | Where-Object { $_.Trim() })) { Say "    $l" }
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 5 -UseBasicParsing
        Say ("  server on 127.0.0.1:11434 answering ({0})" -f $r.StatusCode)
    } catch {
        Say '  NOTHING ANSWERING on 127.0.0.1:11434 - run `ollama serve`'
    }
}

# ------------------------------------------------------------------- codex
Head 'Codex'
if (-not (Have 'codex')) {
    Say '  codex NOT ON PATH - install with: npm install -g @openai/codex'
} else {
    try {
        & codex login status 2>&1 | Out-Null
        Say ("  login status exit code {0} {1}" -f $LASTEXITCODE,
             $(if ($LASTEXITCODE -eq 0) { '(credentials present)' } else { '(NOT logged in - run: codex login)' }))
    } catch { Say '  login status could not be read' }
    $mcp = (& codex mcp list 2>&1 | Out-String)
    if ($mcp -match '(?i)unsupported') {
        Say '  codex mcp list: Unsupported  <- EXPECTED, not a defect.'
        Say '    The entry point was removed upstream in Codex 0.154.0 (2026-09-05).'
        Say '    Codex is MCP-client-only now. Delegation is a subprocess and is fine.'
    } else {
        foreach ($l in ($mcp -split '\r?\n' | Where-Object { $_.Trim() })) { Say "    $l" }
    }
    $codexHome = Join-Path $HOME '.codex'
    if (Test-Path $codexHome) {
        foreach ($f in (Get-ChildItem $codexHome -ErrorAction SilentlyContinue)) {
            # auth.json holds a token. Name and size only; never opened.
            Say ("    {0,-28} {1,8:N0} B" -f $f.Name, $f.Length)
        }
    } else { Say "  $codexHome does not exist" }
}

# ------------------------------------------------- installed config vs repo
Head 'installed config vs this repo'
$repo = Split-Path $PSScriptRoot -Parent
foreach ($pair in @(
    @{ n = 'config.yaml'; src = (Join-Path $repo 'configs\hermes\config.yaml'); dst = (Join-Path $HermesHome 'config.yaml') },
    @{ n = 'config.toml'; src = (Join-Path $repo 'configs\codex\config.toml');  dst = (Join-Path $HOME '.codex\config.toml') })) {
    if (-not (Test-Path $pair.dst)) { Say ("  {0,-14} NOT INSTALLED - run scripts/hermes-apply.ps1" -f $pair.n); continue }
    if (-not (Test-Path $pair.src)) { Say ("  {0,-14} installed, but absent from this repo" -f $pair.n); continue }
    $a = (Get-FileHash $pair.src).Hash
    $b = (Get-FileHash $pair.dst).Hash
    # Truncated so the hash cannot trip the long-blob scrub rule.
    Say ("  {0,-14} {1}  (repo {2}  installed {3})" -f $pair.n,
         $(if ($a -eq $b) { 'IN SYNC' } else { 'DIFFERS - re-run hermes-apply.ps1' }),
         $a.Substring(0, 12), $b.Substring(0, 12))
}

Head 'next'
Say '  1. Paste this report back.'
Say '  2. pwsh -File scripts/hermes-verify.ps1 -Stage full -Deep'
Say '     That probes each provider live, reading the model ids out of the'
Say '     installed config rather than from a copy inside the script.'

if ($OutFile) {
    # Same scrubbed lines that went to the console. There is no second path.
    $script:Lines | Set-Content -Path $OutFile -Encoding utf8
    Write-Host ''
    Write-Host "written to $OutFile" -ForegroundColor Green
}
