# Handoff — bring the Hermes–Codex build up, in order

One sequential list. Every step says **who executes it**, and the ones marked
**YOU** are marked that way because Hermes structurally cannot do them — not because
they are hard.

Read `HERMES-SELF-SETUP.md` for the prompt that hands Part C to Hermes. Read
`TAKEOVER.md` for the full detail behind any step. This file is the order.

---

## Why some steps can never be delegated

Three different reasons, and they are worth telling apart:

| Reason | Steps | Why Hermes cannot |
|---|---|---|
| **Credentials** | A2, B4 | Only you hold the keys. Nothing in this repo has ever contained one, and `.gitignore` now enforces that. A step that asks an agent to handle a key is a step that logs it. |
| **Bootstrap** | B1–B3 | The local tier cannot install the backends that serve it. hermes3:8b cannot install Ollama; the VL runner cannot start llama-server. |
| **Authority** | A1, A3, D3 | Renaming a repo, merging a PR, rotating a live token. Consequences outside this machine. |

Everything else — Part C, the whole of it — Hermes runs.

---

## Part A — Owner only, before anything else

### A1. Rename the repository · **YOU**

GitHub → Settings → General → Repository name → `hermes-codex-build`.

Also change the **description**, still `Complete Claude + Claude Code enhancement
stack for MAD Gambit…`. It is the last product reference attached to this repo and
the only one visible without opening a file.

GitHub redirects the old URL, so existing clones and PR links keep working.
`docs/models/VSCODE-QUICKSTART.md` already clones the new name and **will not resolve
until this is done**.

### A2. Decide the Render token · **YOU**

An earlier *deployed* `config.yaml` carried a Render bearer token inline. The MCP
entry is gone from the committed config, but **disabling is not rotating**. The
credential may still be readable in shell history, in `config.yaml.bak-*` files on
the box, or in a gateway log that captured the config at startup.

A Render bearer token is account-level API access. Answer it with:

```powershell
pwsh -File scripts/hermes-report.ps1
```

It reports **how many key-shaped strings each backup holds and of what family** —
never the value. Zero hits everywhere and a single-user box means nothing is exposed;
say so and delete this step. Otherwise rotate it in the Render dashboard.

### A3. Merge PR #16 · **YOU**

It is a draft, green on both checks, `mergeable_state: clean`. Everything below
assumes the branch is merged, or that you are working from it.

---

## Part B — Bootstrap. YOU, because the local tier cannot install itself

Stop after each one. A step is done when its **success line** matches — not when the
command exits 0.

### B1. Ollama and the floor model · **YOU**

```powershell
ollama list          # installs Ollama first if this is not recognised
ollama pull hermes3:8b
```

**Success:** `ollama list` shows `hermes3:8b`.

At this point Hermes has a backend and can talk. It still cannot do B2 or B3.

### B2. The VL model files · **YOU**

≈10.5 GB, two files. **You need both** — the projector is what makes it see.

```powershell
hf download Vastined/NVIDIA-Nemotron-Nano-12B-v2-VL-BF16-GGUF `
  --include '*Q5_K_M*.gguf' '*mmproj*.gguf' `
  --local-dir "$HOME\Models\nemotron-nano-12b-v2-vl"
```

**Success:** `...VL-Q5_K_M.gguf` ≈ **8.77 GB** and `...VL-BF16-mmproj.gguf` ≈ **1.69 GB**.

**Do not try this with Ollama.** `ollama create` *succeeds* while silently dropping
the projector, leaving a model with `-VL` in its name that cannot see.

### B3. llama.cpp, and serve it · **YOU**

From <https://github.com/ggml-org/llama.cpp/releases>, take a **`b#####`** tag — not
`v0.4.x`, those carry no Windows binaries. **Take a recent one — mid-2026 or later.**
Current nightly is ~b11118 (2026-09-22) and carries everything needed.

The old instruction here said "≥ b6315" and was wrong by about nine months. b6315 is
where `nemotronh` landed — the **text** Nemotron Nano v2 (llama.cpp PR #15507, merged
2025-08-29), which used to hold this slot. This model is `nemotron_v2_vl` and needs
PR **#19547** (merged 2026-02-12) plus PR **#23638** (dynamic hi-res tiling, ~2026-05-25).
Without #23638 every image encodes at a fixed 256 tokens whatever its resolution, which
makes reading a screenshot of a dialog or a terminal — this tier's whole job —
effectively useless (issue #25317).

- NVIDIA → `llama-b#####-bin-win-cuda-12.4-x64.zip` **plus**
  `cudart-llama-bin-win-cuda-12.4-x64.zip`, unzipped into the **same folder**.
  Without the cudart, `llama-server.exe` dies on a missing DLL that never mentions CUDA.
- Otherwise → `llama-b#####-bin-win-cpu-x64.zip`.

```powershell
$m = "$HOME\Models\nemotron-nano-12b-v2-vl"
llama-server -m "$m\NVIDIA-Nemotron-Nano-12B-v2-VL-Q5_K_M.gguf" `
             --mmproj "$m\NVIDIA-Nemotron-Nano-12B-v2-VL-BF16-mmproj.gguf" `
             --alias nemotron-nano-12b-v2-vl `
             --host 127.0.0.1 --port 8080 `
             -c 16384 -ngl 99 --jinja
```

**Success:** `(Invoke-RestMethod http://127.0.0.1:8080/v1/models).data.id` prints
exactly `nemotron-nano-12b-v2-vl`.

`--alias` is load-bearing; `-c 16384` must match `local-vl.context_length`; `--jinja`
or the tool-call probe fails as *prose*; `--host 127.0.0.1` because this server takes
no key.

Leave it running for now. Promote it to a service at **D2**.

### B4. The keys · **YOU**

Copy `.env.example` to `$HERMES_HOME\.env` and fill in three values. Nothing else in
this handoff touches a key, and no step below will ask you to paste one.

```powershell
Copy-Item .env.example "$env:LOCALAPPDATA\hermes\.env"
notepad "$env:LOCALAPPDATA\hermes\.env"
```

| Var | Tier | Where |
|---|---|---|
| `HF_TOKEN` | parent | <https://huggingface.co/settings/tokens> (read scope is enough) |
| `NVIDIA_API_KEY` | subagents | <https://build.nvidia.com> → Get API Key |
| `OPENROUTER_API_KEY` | fallback + compression + web_extract | <https://openrouter.ai/keys> |

**Leave `FIRECRAWL_API_KEY` unset** unless you mean it — present in the environment it
silently beats SearXNG and you get billed for searches you thought were local.

Then the five path variables, which are **not** keys:

```powershell
[Environment]::SetEnvironmentVariable('HERMES_SKILLS_SERVER','<path>\dist\index.js','User')
[Environment]::SetEnvironmentVariable('HERMES_COUNCIL_LAUNCHER','<repo>\scripts\hermes-council-launch.cmd','User')
[Environment]::SetEnvironmentVariable('HERMES_COUNCIL_PYTHON',(Get-Command python).Source,'User')
[Environment]::SetEnvironmentVariable('HERMES_CODEX_LAUNCHER','<repo>\scripts\codex-mcp-launch.cmd','User')
[Environment]::SetEnvironmentVariable('HERMES_CODEX_NODE',(Get-Command node).Source,'User')
```

**Open a new shell afterwards** — `User` scope does not affect the current one.

**Success:** a new shell has all five set, and `.env` holds three keys.

---

## Part C — Hermes executes this

Paste the prompt from `HERMES-SELF-SETUP.md`. It covers every step below and reports
`step <n> PASS|FAIL / expected / got` for each.

| Step | What | Detail in |
|---|---|---|
| C1 | Install the configs, with backups — `hermes-apply.ps1 -WhatIf`, then for real | TAKEOVER 4 |
| C2 | Copy `hermes-skills/*` into `~/.hermes/skills/` | TAKEOVER 3.4 |
| C3 | Enable the three upstream skills it already depends on | TAKEOVER **3.4a** |
| C4 | Restart the gateway, confirm MCP servers register | TAKEOVER 3.5 |
| C5 | Prove the VL model **sees** and **calls tools** — two probes | TAKEOVER **1.4** |
| C6 | Run the acceptance gate and paste the whole output | TAKEOVER 6.1 |

**C5 is the gate that decides what the VL runner is allowed to do.** Ordinary chat
looking fine proves nothing — a wrong chat template degrades tool use silently. Until
those two probes pass, the runner reads and reports; it does not execute.

**Hermes stops and escalates** — do not let it improvise — when a config edit is
needed, when a key would be written anywhere but `.env`, when `hermes-verify.ps1`
FAILs a step already run, or when two steps fail for the same reason.

---

## Part D — Close it out

### D1. Read the verifier output · **YOU, with Claude**

`hermes-verify.ps1 -Stage full -Deep` is the acceptance gate. It reads each provider's
endpoint and model id **out of the installed config** rather than restating them, so
it cannot drift from what Hermes actually sends.

Expect these, and they are not defects:

- `hermes not on PATH` warn — only if you did not install the CLI globally
- port 8080 **FAIL** — only if you skipped B3 or the server stopped
- upstream skill warns — only if C3 did not run

### D2. Make llama-server survive a reboot · **YOU**

B3 leaves it in a terminal window. A window someone can close is not a deployment,
and `vision` plus all heavy local text route through it.

1. **NSSM service** — survives logout and reboot, restarts on crash. Do this one.
2. **Scheduled Task at log on** — no extra software; dies on a logged-out reboot.
3. **Leave the terminal** — only while still bringing things up.
4. **Docker** `--restart unless-stopped` — clean, but GPU passthrough adds a layer.

### D3. Decide the two open calls · **YOU**

- **`skills.external_dirs`** — commented in `config.yaml`. Turning it on points Hermes
  at the repo checkout so `git pull` is live, instead of copying skills into
  `~/.hermes/skills/` where nothing reports drift. It also means a moved or deleted
  checkout silently removes 28 skills. Deliberate either way.
- **`operations/hermes-orchestration`** — upstream ships
  `autonomous-ai-agents/hermes-agent` v3.2.0, which covers Hermes in general better
  than ours does. Ours should stay narrow: these five tiers, these gateway ids, these
  scripts. If it starts restating the general case, cut that part.

---

## What is still unproven, after all of this

Stated plainly, because a handoff that implies more than it delivers is worse than one
that admits the gap:

- **No script here has executed against a real Hermes install on Windows.** CI proves
  the files parse and agree with each other. It cannot prove behaviour.
- **Whether a current llama.cpp build loads this VL model with its projector** — both
  files exist (verified on the Hub: 8.77 GB + 1.69 GB) and `nemotron_v2_vl` support is
  in PR #19547 by name. The two together on a real build is what B3 settles. A build
  missing #19547 refuses loudly; one missing #23638 fails quietly, by reading
  screenshots badly.
- **The Codex shim has never run against a real `codex` binary.** Its error paths were
  exercised against a stub; the happy path is simulated.
- **`cloudflare` and `submcp` MCP URLs and tool lists** came from a prior handoff and
  were never reachable from a build container. A wrong URL fails loudly; a wrong
  `tools.include` fails **silently**, by filtering everything out. `mcporter` — step
  C3 — is the tool that can tell you which.
