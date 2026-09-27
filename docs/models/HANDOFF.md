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
| **Bootstrap** | B1 | The local tier cannot install the backend that serves it — the floor model cannot install Ollama. (B2/B3 below, the VL runner's own bootstrap, are RETIRED — see those steps.) |
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
ollama pull hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0
```

**Success:** `ollama list` shows the full tag above (swapped from `hermes3:8b`
2026-09-25, on request).

At this point Hermes has a backend and can talk. That is now the whole of Part B's
bootstrap — B2 and B3 below are retired.

### B2. The VL model files · RETIRED 2026-09-25

This step, and B3 below, downloaded and served `nemotron-nano-12b-v2-vl` via a
second local server (`local-vl`, llama.cpp on :8080). That tier is gone from
`config.yaml` entirely, on request ("remove hermes 8B and the 12b"), and `vision`
now routes to the cloud (`custom:or-fallback` / `deepseek/deepseek-v4.1-flash`) —
the same route it used before this tier ever existed. Nothing to download or
serve here anymore. Skip straight to B4.

### B3. llama.cpp, and serve it · RETIRED 2026-09-25

Retired along with B2 above — there is no local vision server to build or run.
The reasoning this step used to carry (build-floor requirements, the `--alias`/
`--mmproj` flags, the two llama.cpp PRs a working build needed) is preserved in
`configs/hermes/config.yaml`'s git history if it's ever needed again, but it no
longer describes anything this file asks you to do.

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
- upstream skill warns — only if C3 did not run

There is no port-8080 check to expect a FAIL from anymore — B2/B3's llama-server
is retired along with `local-vl`. A FAIL anywhere in this output now means
something to actually fix.

### D2. RETIRED 2026-09-25 · was "Make llama-server survive a reboot"

This step existed to keep B3's llama-server running as a service rather than a
closeable terminal window, since `vision` and all heavy local text routed
through it. Both the server and that routing are gone: `vision` is on the cloud
route now, so there is no local process to keep alive here. Skip to D3.

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
- **Whether the new local floor model is pulled on the box** —
  `hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0` (swapped from
  hermes3:8b 2026-09-25), verified live against the Hugging Face repo at 3.42 GB;
  the disk is the open question, same class of gap hermes3:8b's ever was. (The
  llama.cpp/VL-projector item that used to sit here no longer applies — B2/B3 are
  retired, not just unverified.)
- **The Codex shim has never run against a real `codex` binary.** Its error paths were
  exercised against a stub; the happy path is simulated.
- **`cloudflare` and `submcp` MCP URLs and tool lists** came from a prior handoff and
  were never reachable from a build container. A wrong URL fails loudly; a wrong
  `tools.include` fails **silently**, by filtering everything out. `mcporter` — step
  C3 — is the tool that can tell you which.
