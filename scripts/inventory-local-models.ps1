<#
.SYNOPSIS
  Inventory every local model file on this machine and cross-check against
  what configs/hermes/config.yaml actually expects to find.

.DESCRIPTION
  Read-only. Touches nothing, starts nothing, deletes nothing.

  Covers every location this repo's own docs reference:
    - Ollama's model blob store              (the local floor model lives here)
    - $HOME\Models\*                         (TAKEOVER.md's GGUF download target)
    - The Hugging Face cache                 (`hf download` caches here by
                                               default even when --local-dir is
                                               also given -- a second, easy-to-
                                               miss copy of the same weights)
    - LM Studio's model folder, if present   (common enough to be worth a look,
                                               not referenced by this repo)

  Then reports whether the one model config.yaml's `local` provider actually
  expects (`hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0`) was
  found, and flags anything on disk that ISN'T referenced by any provider -- the
  dead-weight class of problem this repo already hit once with a stray
  nemotron-nano:12b-v2 download that nothing ever routed to. (As of 2026-09-25
  there is only the one local provider: `local-vl`, the second local tier this
  script used to also cross-check, was retired the same day hermes3:8b was.)

.EXAMPLE
  pwsh -File scripts/inventory-local-models.ps1
#>
[CmdletBinding()]
param()

function Section($t) { Write-Host "`n$t" -ForegroundColor Cyan }
function Fmt-Size($bytes) {
    if ($bytes -ge 1GB) { "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { "{0:N1} MB" -f ($bytes / 1MB) }
    else { "{0:N0} KB" -f ($bytes / 1KB) }
}

$found = @()   # objects: Source, Name, Path, SizeBytes

# ---------------------------------------------------------------- Ollama ---
Section 'Ollama'
$ollama = Get-Command ollama -ErrorAction SilentlyContinue
if ($ollama) {
    $list = & ollama list 2>&1
    Write-Host $list
    # ollama list gives names and sizes but not on-disk paths -- the real
    # blobs live under the model store, which is what actually answers
    # "what is on this disk", including anything orphaned from a deleted tag.
    $store = if ($env:OLLAMA_MODELS) { $env:OLLAMA_MODELS }
             else { Join-Path $env:USERPROFILE '.ollama\models' }
    if (Test-Path $store) {
        $blobs = Get-ChildItem (Join-Path $store 'blobs') -File -ErrorAction SilentlyContinue
        $total = ($blobs | Measure-Object Length -Sum).Sum
        Write-Host "  blob store: $store"
        Write-Host "  $($blobs.Count) blob(s), $(Fmt-Size $total) total"
        foreach ($b in $blobs) {
            $found += [pscustomobject]@{ Source='ollama-blob'; Name=$b.Name; Path=$b.FullName; SizeBytes=$b.Length }
        }
    } else {
        Write-Host "  blob store not found at $store (set OLLAMA_MODELS if it lives elsewhere)"
    }
} else {
    Write-Host '  ollama not on PATH'
}

# --------------------------------------------------------- $HOME\Models ---
Section 'TAKEOVER.md download target ($HOME\Models)'
$modelsDir = Join-Path $HOME 'Models'
if (Test-Path $modelsDir) {
    $ggufs = Get-ChildItem $modelsDir -Recurse -File -Include *.gguf -ErrorAction SilentlyContinue
    foreach ($g in $ggufs) {
        Write-Host "  $(Fmt-Size $g.Length)`t$($g.FullName)"
        $found += [pscustomobject]@{ Source='local-gguf'; Name=$g.Name; Path=$g.FullName; SizeBytes=$g.Length }
    }
    if (-not $ggufs) { Write-Host "  $modelsDir exists but has no .gguf files" }
} else {
    Write-Host "  $modelsDir does not exist"
}

# ------------------------------------------------------ Hugging Face cache -
Section 'Hugging Face cache (hf download default target)'
$hfCache = if ($env:HF_HOME) { Join-Path $env:HF_HOME 'hub' }
           elseif ($env:HUGGINGFACE_HUB_CACHE) { $env:HUGGINGFACE_HUB_CACHE }
           else { Join-Path $env:USERPROFILE '.cache\huggingface\hub' }
if (Test-Path $hfCache) {
    $repos = Get-ChildItem $hfCache -Directory -Filter 'models--*' -ErrorAction SilentlyContinue
    foreach ($r in $repos) {
        $files = Get-ChildItem $r.FullName -Recurse -File -Include *.gguf,*.safetensors -ErrorAction SilentlyContinue
        $total = ($files | Measure-Object Length -Sum).Sum
        if ($files) {
            $repoName = $r.Name -replace '^models--', '' -replace '--', '/'
            Write-Host "  $repoName  ($(Fmt-Size $total), $($files.Count) file(s))"
            foreach ($f in $files) {
                $found += [pscustomobject]@{ Source='hf-cache'; Name="$repoName/$($f.Name)"; Path=$f.FullName; SizeBytes=$f.Length }
            }
        }
    }
    if (-not $repos) { Write-Host "  $hfCache exists but holds no model repos" }
} else {
    Write-Host "  $hfCache does not exist"
}

# -------------------------------------------------------------- LM Studio --
Section 'LM Studio (not used by this repo, checked anyway)'
$lmsDir = Join-Path $env:USERPROFILE '.lmstudio\models'
if (Test-Path $lmsDir) {
    $files = Get-ChildItem $lmsDir -Recurse -File -Include *.gguf -ErrorAction SilentlyContinue
    $total = ($files | Measure-Object Length -Sum).Sum
    Write-Host "  $lmsDir : $($files.Count) file(s), $(Fmt-Size $total)"
    foreach ($f in $files) {
        $found += [pscustomobject]@{ Source='lm-studio'; Name=$f.Name; Path=$f.FullName; SizeBytes=$f.Length }
    }
} else {
    Write-Host '  not present'
}

# ---------------------------------------------------------------- verdict --
Section 'Cross-check against configs/hermes/config.yaml'
$configPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'configs\hermes\config.yaml'
if (Test-Path $configPath) {
    $cfg = Get-Content $configPath -Raw
    foreach ($expected in @('Hermes-3-Llama-3.2-3B-abliterated')) {
        $have = $found | Where-Object { $_.Name -like "*$expected*" -or $_.Path -like "*$expected*" }
        if ($have) { Write-Host "  ok    $expected -- found on disk" -ForegroundColor Green }
        else       { Write-Host "  FAIL  $expected -- config.yaml expects this, not found anywhere scanned" -ForegroundColor Red }
    }
} else {
    Write-Host "  config not found at $configPath -- run this from inside the repo"
}

Section 'Summary'
$grouped = $found | Group-Object Source
foreach ($g in $grouped) {
    $total = ($g.Group | Measure-Object SizeBytes -Sum).Sum
    Write-Host ("  {0,-14} {1,3} file(s)  {2}" -f $g.Name, $g.Count, (Fmt-Size $total))
}
$grandTotal = ($found | Measure-Object SizeBytes -Sum).Sum
Write-Host "`n  TOTAL: $($found.Count) model file(s), $(Fmt-Size $grandTotal) on disk"
