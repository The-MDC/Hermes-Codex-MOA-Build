# Handoff — current state of the Hermes/Codex build

**Update this file in place. Do not add another dated handoff.** This session's audit
found three documents describing a retired topology as current, because each was
written as a point-in-time snapshot and then left. A living state file with one
authoritative version does not rot the same way. Dated records still have a place —
`handoff-2026-09-22.md` is a record of *what was reported on a day* and is annotated
rather than edited — but "what is true now" belongs here, and only here.

Last updated: 2026-09-25 · Branch: `claude/lucid-noether-0ui54b` (reset from `The-MDC`
after PR #13 merged) · PR #13 **merged**, PR #17 open (`anthropic-direct` +
inventory script + this fallback change)

---

## Orientation: read these, in this order

1. **This file** — state, open items, and what needs a human.
2. `VSCODE-QUICKSTART.md` — fast path: Ollama, two local models, both DeepSeek tiers.
3. `TAKEOVER.md` — the full six-phase bring-up, one success line per step.
4. `configs/hermes/config.yaml` — the config itself carries the reasoning inline.

Retired, kept only for their reasoning: `running-the-stack.md`, `kimi-k3-quants.md`,
`local-floor.md`. They carry banners. **Do not follow their instructions.**

---

## The architecture as committed

```
parent      custom:hf-router     deepseek-ai/DeepSeek-V4-Pro       1.6T / 49B active, 1M ctx
subagents   custom:nvidia-nim    nvidia/llama-3.3-nemotron-super-49b-v1.5 high-compute delegation
            (swapped from nemotron-3-super-120b-a12b 2026-09-25, on request --
             120B is retired, no reference to it remains in config.yaml)
fallback    custom:or-fallback   deepseek/deepseek-v4.1-flash      552B / 8B prefill, 16B decode
floor       custom:local         hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0
                                  Ollama, 5 aux slots (swapped from hermes3:8b 2026-09-25)

vision      RETIRED as a local tier 2026-09-25, on request ("remove hermes 8B and
            the 12b"). `local-vl` (nemotron-nano-12b-v2-vl, llama.cpp :8080) is
            gone entirely; vision now routes to or-fallback (cloud), same as
            before the local-vl tier ever existed. The new floor model is
            text-only (Llama-3.2 3B), so this was never a vision-capable swap.

auxiliary   5 slots -> Hermes-3-Llama-3.2-3B-abliterated:Q8_0   routing, classification,
                                                                  titles, approval, curator
            2 slots -> V4.1-Flash          compression, web_extract
            1 slot  -> or-fallback         vision (was local-vl until 2026-09-25)
moa         V4.1-Flash reference -> NIM Nemotron 49B aggregator (was 120B)
mcp         7 servers, 2 hosted (cloudflare, submcp) on an explicit CI allowlist

fallback_providers (ordered, added-to 2026-09-25):
  1. nvidia/llama-3.3-nemotron-super-49b-v1.5 on nvidia-nim (cloud, SAME bucket
     AND, since the 120B->49B swap, SAME model as subagents/delegation)
  2. deepseek/deepseek-v4.1-flash on or-fallback              (was fallback 1)
  3. hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0 local
     (last resort, unchanged in role -- swapped from hermes3:8b)

anthropic-direct (claude-sonnet-5, Anthropic's OpenAI-compat endpoint) exists in
providers: since 2026-09-25, wired into NOTHING above -- reachable only via
/model custom:anthropic-direct:claude-sonnet-5.
```

Three structural rules hold this together. Breaking any one fails **silently**:

1. **Provider references must dodge `excluded_providers`.** `deepseek`, `openrouter`
   and `ollama` are all excluded, and exclusion matches every key a provider surfaces
   under. That is why the entries are named `hf-router`, `or-fallback` and `local`.
   Naming an excluded provider directly resolves to nothing and falls back to the
   main model — a bill and a latency change, no error.
2. **Subagents must not share the parent's provider.** Not "must avoid NIM" — that
   rule encoded the old topology and blocked a correct layout. CI asserts the general
   form now.
3. **No auxiliary slot may sit on `auto`.** `auto` means "use the main model", which
   puts side jobs on the parent's bucket. This is how `vision` was silently broken:
   left on `auto` from when the parent was Kimi-K3, which had vision, while the
   current parent is text-only.

---

## Done and verified

| Thing | How it was verified |
|---|---|
| Config topology | CI assertion block run against it; 3 negative tests reproducing each silent-failure shape all rejected |
| CI catches dangling provider refs | Negative-tested: excluded-provider ref, renamed provider, deleted provider |
| PowerShell scripts parse | `Parser::ParseFile` locally **and** in CI (`shell: pwsh` on ubuntu-latest) |
| `hermes-apply.ps1` is safe | Executed against a throwaway root: idempotent on identical content; on drift it backs up first and the drifted line survives in the backup |
| No credential leakage | Ran with dummy keys in `.env`; zero occurrences in output |
| `hermes-council` | **Fixed on the box.** Wrapper starts clean, no ModuleNotFoundError |
| GitHub Actions | Green on all 7 commits, 6–12s each |
| Port checks are now portable | **Resolved 2026-09-22.** `Test-NetConnection` is Windows-only and was listed here as a path that had never executed. Off Windows it did not fail cleanly — it threw `term not recognized` straight to stderr while the surrounding logic carried on. Replaced with a `TcpClient` helper that behaves identically everywhere, then exercised in a container against all three states: server up with the right alias (ok), server up with the wrong id (FAIL naming `--alias` as the fix), server down (FAIL) |
| Cloudflare Workers disconnected | **Resolved 2026-09-22.** The integration was deleted by the repo owner. Verified rather than assumed: PR #13's head carried two check runs (`Workers Builds` failing in 0s, `harness checks`), PR #14's head carries **one** — `harness checks`, green, 12s. The `Workers Builds` run is absent, not merely passing. The red X frozen in #13's history does not clear: completed check runs are immutable |

## Assumed, NOT verified

Be explicit about these. Each is the dangling-reference class that CI structurally
cannot see.

- **Whether `hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-GGUF:Q8_0` is
  pulled on the box.** `ollama pull` for it is documented (see the table above);
  the disk is the open question, same class of gap as hermes3:8b's ever was.
  (The old llama-server/VL-projector item that used to sit here no longer
  applies -- that tier is retired, not just unverified.)
- **`cloudflare` and `submcp` MCP URLs and tool lists** — taken from the handoff,
  never reachable from the build container. A wrong URL fails loudly; a wrong
  `tools.include` fails silently by filtering everything out.
- **Whether a current llama.cpp build actually loads this VL model with its projector.** The
  GGUF and the mmproj both exist and `nemotron_v2_vl` is supported (PR #19547); the two together on
  a real build is the part nothing here can exercise. It fails loudly if not.
- **`nvidia/llama-3.3-nemotron-super-49b-v1.5`.** Added 2026-09-25 as
  fallback_providers[0]; as of the same day it is ALSO `nvidia-nim`'s own
  `default_model` (subagents/delegation, MoA aggregator), replacing
  nemotron-3-super-120b-a12b entirely on request. Neither use is live-verified:
  build.nvidia.com and docs.api.nvidia.com are both egress-blocked from this
  build container. Corroborated by three independent resellers proxying NIM
  (Puter, WaveSpeedAI, AIMLAPI), not first-party. Run
  `bash scripts/nim-preflight.sh --list | grep -i nemotron-super-49b` on the box
  before trusting either use of it.
- **`anthropic-direct` under a real key.** Verified live with garbage credentials
  only (two probes distinguishing this endpoint's OpenAI-shaped vs. Anthropic-shaped
  errors, and that `/models` needs `x-api-key` not `Bearer`) — never confirmed that
  a real `ANTHROPIC_API_KEY` actually returns `claude-sonnet-5` content. Unwired
  into any role; `hermes-verify.ps1 -Deep` closes the gap if `ANTHROPIC_API_KEY` is set.

`pwsh -File scripts/hermes-verify.ps1 -Stage full -Deep` now reads each provider's
endpoint and model id **out of the installed config** rather than restating them, so
the probe can no longer drift from what Hermes actually sends — which is how the
OpenRouter id stayed wrong through a merge. It checks each provider's **catalog
before the completion**, because a failed completion alone cannot distinguish a wrong
model id from an exhausted quota, and those need opposite fixes.

---

## Needs a human — cannot be done from a session

### 1. Rotate the Render bearer token

An earlier deployed `config.yaml` carried it **inline**. The MCP entry is now
disabled and absent from the committed config — but **disabling is not rotating**,
and the two are unrelated. Disabling stops Hermes *using* the server. The credential
is still readable in:

- shell history on the box
- the four `config.yaml.bak-*` files listed in `handoff-2026-09-22.md`
- any Hermes gateway log that captured the config at startup

A Render bearer token is account-level API access — services, deploys, environment
variables. Rotation in the Render dashboard is the only thing that closes it.

> If the token was never live, or the box is single-user and the `.bak-*` files and
> history have been cleared, then this is done — **say so and remove this item.**
> Three files currently assert it needs rotating. If that stops being true, leaving
> the assertion in place is exactly the staleness the 2026-09-22 audit cleaned up.

**Answer it with `scripts/hermes-report.ps1`**, which exists because no session can
see this machine:

```powershell
pwsh -File scripts/hermes-report.ps1
```

It inventories `$HERMES_HOME`, finds every `config.yaml.bak-*`, and reports **how
many key-shaped strings each one contains and of what family** — never the value.
That is the whole question: a backup with zero hits means nothing is exposed there,
and one with a `rnd_` hit means rotate before deleting, because deleting a file does
not un-expose what was in it. Its output is safe to paste back: values are never
read into a variable, and every line is scrubbed of key shapes on the way out.

### 2. Run the quickstart on the Windows box

Everything in this repo is config and scripts; none of it is exercised until someone
runs it. `docs/models/VSCODE-QUICKSTART.md`, then
`pwsh -File scripts/hermes-verify.ps1 -Stage full -Deep`.

---

## Open, in priority order

1. **Tool-calling test for the local model.** The step that catches a wrong chat
   template. Skipping it means finding out later, via degraded tool use that looks
   like a model quality problem. `VSCODE-QUICKSTART.md` §2.6 — this now covers
   only one local model, `hf.co/mradermacher/Hermes-3-Llama-3.2-3B-abliterated-
   GGUF:Q8_0` (swapped from hermes3:8b 2026-09-25); it carries five auxiliary
   slots, so its tool calling matters. The separate local-vl tool-call check this
   item used to also name is gone along with that tier.
2. **Codex delegation, once.** `TAKEOVER.md` step 5.5. Nothing has ever exercised
   the path Hermes actually uses.

**Closed, and why — so neither gets reopened:**

- ~~Codex bridge `Unsupported`~~. **Not a defect and not repairable.** Codex 0.154.0
  removed the `codex mcp-server` entry point on 2026-09-05; `codex app-server`
  speaks its own JSON-RPC 2.0 and is not an MCP server. Codex is an MCP *client*
  now, so there is no handshake left to succeed and no local configuration can make
  that line pass. Hermes' own built-in `codex` MCP preset has the same stale
  reference — an open upstream issue, not something this repo caused. Delegation is
  the subprocess path and is unaffected. `hermes-verify.ps1` now **warns** rather
  than failing here; it used to `Fail`, which made the phase 6 gate unreachable on
  any box with `codex` on PATH. Do not repair it by setting
  `model.openai_runtime: codex_app_server` — that is the second-consumer-of-one-quota
  problem `excluded_providers` exists to prevent.
- ~~Verify the two DeepSeek model ids~~. Done — see the table above. One was wrong
  and is fixed.

---

## Traps found this session — the generalisable ones

**Runtime substitution affects every `command:` MCP entry.** The hermes-council
failure looked like `ModuleNotFoundError`, which invites the inference that a module
is missing. It was not: the supervisor substituted its own bundled Python, so the
import ran where the packages had never been installed. `atomicmemory` (npx) and
`hermes-skills` (node) carry the identical exposure — a substituted Node fails the
same way and just as misleadingly. `url:` entries are immune. **If a `command:` entry
reports a missing module, check WHICH runtime ran before touching any package.**

**An error message names a symptom, not a cause.** That inference cost real debugging
time one layer below the fault. Preserved in `handoff-2026-09-22.md` rather than
tidied away.

**A benchmark belongs to the model it was measured on.** The `or-fallback` entry
carried `BFCL-V4 72.2` / `MMMU-Pro 76.9` from Qwen3.5-122B-A10B. Those were deleted
when the model changed, not carried across. No figure is quoted for the replacement
because none was run here.

**A check that cannot fail is not a check.** Every CI assertion added this session was
negative-tested. The PowerShell step has a `>=3` count guard so an under-matching glob
cannot pass vacuously.

**A check that cannot PASS is worse.** `hermes-verify.ps1` raised a `Fail` on
`codex mcp list` reporting `Unsupported` — a permanent upstream condition. So the
final gate in `TAKEOVER.md` phase 6, `OK no failures`, was unreachable on any machine
with `codex` installed. A gate nobody can satisfy stops being read, and then it hides
the failures that are real. It also contradicted `hermes-blockers.ps1`, which already
recommended doing nothing about it. Demoted to a warning that says why.

**A model id belongs to the GATEWAY, not to the model.** `or-fallback` sent
`deepseek-ai/DeepSeek-V4.1-Flash` — the Hugging Face repo id — to OpenRouter, which
names the same weights `deepseek/deepseek-v4.1-flash`. Nothing catches this: CI
resolves provider *references*, not the ids inside them; `discover_models: false`
stops Hermes probing `/models`; and a dead reference resolves to the main model
rather than erroring. It killed the 429 escape, `compression`, `web_extract` and
`vision` at once, silently. The id had been copied from the model card, which is
exactly the intuitive and wrong thing to do.

**Two copies of one fact will drift, and the copy in the checker is the dangerous
one.** `hermes-verify.ps1` restated all three model ids as literals, so the probe
could report green on an id Hermes would never send — or red on one it would. It now
reads them out of the installed config. Anything that verifies a value should read
that value from where the system reads it, never hold its own copy.

**An egress limit in one container is not a fact about sessions.** Both the PR #13
body and this file recorded the two DeepSeek ids as unverifiable from any session,
because that build container got 403 on `openrouter.ai` and could not reach
`huggingface.co`. Three of the four resolved immediately from a session with the
Hugging Face MCP connector attached — connectors do not go through the same egress
path as `curl`. Before recording something as structurally impossible, check whether
it is merely blocked on one route.

**Assertions that encode a topology rot into false confidence.** Two CI rules had to
be rewritten because they asserted an implementation (`127.0.0.1`, then `not
nvidia-nim`) rather than the requirement (a different bucket from the parent). The
compression threshold hardcoded `kimi-k3` and kept passing against a model no longer
in use — guarding nothing while looking green.

---

## Repo conventions

- Develop on `claude/lucid-noether-0ui54b`. **PR #13 is merged**, so that branch was
  reset from `The-MDC` rather than continued — a merged PR cannot track new work, and
  stacking on merged commits re-proposes them. Follow-up work opens a NEW PR.
- CI is `harness checks`, and as of 2026-09-22 it is the **only** check. The
  Cloudflare `Workers Builds` check that used to fail in 0s on every commit was
  disconnected; if it ever reappears, the integration has been re-attached and the
  fix is again on the Cloudflare or GitHub-App side, never in this repo.
- Product content has been removed from this repo entirely. It is the Hermes +
  Codex orchestration build and carries no company, branding or business figures.
- No key-shaped string may enter `config.yaml`; CI and the preflight both reject it.
- Verify before claiming. Several statements in this repo's history were plausible,
  confidently written, and wrong.
