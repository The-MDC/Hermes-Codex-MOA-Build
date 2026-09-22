# Handoff — current state of the Hermes/Codex build

**Update this file in place. Do not add another dated handoff.** This session's audit
found three documents describing a retired topology as current, because each was
written as a point-in-time snapshot and then left. A living state file with one
authoritative version does not rot the same way. Dated records still have a place —
`handoff-2026-09-22.md` is a record of *what was reported on a day* and is annotated
rather than edited — but "what is true now" belongs here, and only here.

Last updated: 2026-09-22 · Branch: `claude/lucid-noether-0ui54b` · PR #13 (draft)

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
parent      custom:hf-router     deepseek-ai/DeepSeek-V4-Pro      1.6T / 49B active, 1M ctx
subagents   custom:nvidia-nim    nemotron-3-super-120b-a12b       high-compute delegation
fallback    custom:or-fallback   deepseek-ai/DeepSeek-V4.1-Flash  552B / 8B prefill, 16B decode
floor       custom:local         hermes3:8b + nemotron-nano:12b-v2 (Ollama)

auxiliary   5 slots -> hermes3:8b          routing, classification, titles, approval, curator
            3 slots -> V4.1-Flash          compression, web_extract, vision
moa         V4.1-Flash reference -> NIM Nemotron 120B aggregator
mcp         7 servers, 2 hosted (cloudflare, submcp) on an explicit CI allowlist
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

## Assumed, NOT verified

Be explicit about these. Each is the dangling-reference class that CI structurally
cannot see.

- **Whether the HF router serves `deepseek-ai/DeepSeek-V4-Pro`.** It is a 1.6T model;
  router coverage at that size is not a given.
- **Whether OpenRouter serves `deepseek-ai/DeepSeek-V4.1-Flash`.**
- **Whether `nemotron-nano:12b-v2` is imported into Ollama**, and whether its chat
  template produces real `tool_calls` rather than prose about calling a tool.
- **`cloudflare` and `submcp` MCP URLs and tool lists** — taken from the handoff,
  never reachable from the build container. A wrong URL fails loudly; a wrong
  `tools.include` fails silently by filtering everything out.
- **Windows-only code paths in the .ps1 scripts** (`Test-NetConnection`) have never
  executed.

`pwsh -File scripts/hermes-verify.ps1 -Stage full -Deep` answers the first three. It
checks each provider's **catalog before the completion**, because a failed completion
alone cannot distinguish a wrong model id from an exhausted quota, and those need
opposite fixes.

---

## Needs a human — cannot be done from a session

1. **Rotate the Render bearer token.** An earlier deployed `config.yaml` carried it
   inline. It persists in shell history and in four `config.yaml.bak-*` files.
   Disabling the MCP entry did not un-expose it. Rotation is the only fix.
2. **Disconnect Cloudflare Workers from this repo.** Attached after 2026-09-19; fails
   in 0 seconds on every commit including docs-only ones; retry-looping by 11:30.
   Nothing in the repo can fix a build that dies before reading the repo.
   Dashboard: account `d266f6c59a542bce7394fb28b7580327`, service
   `madhats-claude-enhancement` → Settings → Build → Git repository → Disconnect.
   Or revoke the GitHub App's access at the org installations page.
3. **Run the quickstart on the Windows box.** Everything above is config and scripts;
   none of it is exercised until someone runs it.

---

## Open, in priority order

1. **Codex bridge `Unsupported`.** `codex mcp list` reports it. The binary and the
   registration both exist, so it is a protocol mismatch: `codex mcp-server` and the
   standalone binary were removed 2026-09-05, replaced by `codex app-server`
   (JSON-RPC 2.0). **Not urgent** — Hermes reaches Codex as a subprocess via the
   bundled `codex` skill, which does not use this interface. Verify delegation works
   before spending time here. `scripts/hermes-blockers.ps1` diagnoses without changing
   anything.
2. **Verify the two DeepSeek model ids** (see "Assumed" above).
3. **Tool-calling test for both local models.** The step that catches a wrong chat
   template. Skipping it means finding out later, via degraded tool use that looks
   like a model quality problem.

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

**Assertions that encode a topology rot into false confidence.** Two CI rules had to
be rewritten because they asserted an implementation (`127.0.0.1`, then `not
nvidia-nim`) rather than the requirement (a different bucket from the parent). The
compression threshold hardcoded `kimi-k3` and kept passing against a model no longer
in use — guarding nothing while looking green.

---

## Repo conventions

- Develop on `claude/lucid-noether-0ui54b`. PR #13 tracks it.
- CI is `harness checks`. The Workers check is the known-bad one; ignore it.
- Canonical numbers (fee 1.88%, community 28.8%, creator 40%, pre-money $12M) are
  asserted by CI against `CLAUDE.md` and must not change without explicit approval.
- No key-shaped string may enter `config.yaml`; CI and the preflight both reject it.
- Verify before claiming. Several statements in this repo's history were plausible,
  confidently written, and wrong.
