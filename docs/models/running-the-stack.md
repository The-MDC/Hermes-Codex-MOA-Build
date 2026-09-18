# Running the stack: three providers, three rate-limit buckets

What to install, in what order, and the two traps that cost a session each.

Config: `configs/hermes/config.yaml` · Preflight: `scripts/nim-preflight.sh` ·
Quant survey: `docs/models/kimi-k3-quants.md`

## The shape of it

```
  parent agent    ──▶  moonshotai/kimi-k3        NVIDIA NIM
                       2.8T · 1M ctx · vision     integrate.api.nvidia.com

  subagents       ──▶  Qwen/Qwen3.6-35B-A3B      HF Inference Providers
                       36B / 3B active            router.huggingface.co

  429 fallback    ──▶  qwen/qwen3.5-122b-a10b    OpenRouter
                       125B / 10B active          openrouter.ai
```

Three providers, three independent rate-limit buckets. A 429 on one cannot starve
the others.

**Why Kimi-K3 is routed and not hosted:** there is no build that fits. The smallest
unpruned GGUF is 466 GB; the smallest pruned one anybody has demonstrated is 319 GiB
at 0.48 tok/s. Full reasoning in `kimi-k3-quants.md`.

**Why the subagents are the interesting half:** NIM's free tier runs around 40 RPM
and Kimi-K3 users report 429s on NVIDIA's own developer forums. One Hermes delegation
batch can spend a whole minute's budget. Moving children onto a different provider is
not a cost optimisation — it is what keeps the parent's requests available for the
work you care about.

**Why not a local model for that tier.** An earlier version of this stack put the
subagents on a local llama-server. That was wrong for any ordinary laptop, and the
arithmetic says so plainly:

| | |
|---|---:|
| TripleTrouble-V3 Q4_K_M weights | 21.2 GB |
| KV cache at 32K context (GQA, 2 KV heads) | ~1.3 GB |
| **resident total** | **~23 GB** |

That is a 32 GB-unified Mac or a 24 GB card, not a normal machine. MoE helps with
*speed* — only ~3.3B parameters activate per token, so it decodes like a 3B model —
but it does nothing for the memory floor: every one of the 35B has to be reachable.

The local tier was never the requirement. **Keeping children off the metered bucket
was.** A second cloud provider does that with nothing on your machine, and the CI
check now asserts the requirement (different provider, different host) rather than
the old implementation detail (`127.0.0.1`).

If you later want that tier on your own NVIDIA GPUs, NVIDIA ships a NIM container for
it — `nvcr.io/nim/qwen/qwen3.6-35b-a3b`, with documented function calling, image and
video input, and a DGX Spark (linux/arm64) build. Dedicated GPUs, no shared rate
limit, still on the NVIDIA account.

## Step 1 — NVIDIA key

Get it from <https://build.nvidia.com> ("Get API Key" on any model page; the same key
works across the catalog). Then:

```bash
mkdir -p ~/.hermes && touch ~/.hermes/.env && chmod 600 ~/.hermes/.env
printf 'NVIDIA_API_KEY=%s\n' 'nvapi-…' >> ~/.hermes/.env
```

Never in `config.yaml`, never in a commit, never pasted into a chat window. The config
reads it through `key_env`, and both `nim-preflight.sh` and CI check that no key-shaped
string is tracked in this repo.

## Step 2 — the other two keys

Neither is required to start; each one enables a tier.

```bash
# subagent tier — https://huggingface.co/settings/tokens
printf 'HF_TOKEN=%s\n' 'hf_…' >> ~/.hermes/.env

# 429 fallback — https://openrouter.ai/keys
printf 'OPENROUTER_API_KEY=%s\n' 'sk-or-v1-…' >> ~/.hermes/.env
```

`scripts/nim-preflight.sh` checks all three and warns — rather than failing — when a
secondary key is absent, because running NIM-only is a legitimate choice. What it
will not let pass quietly is a tier that is *configured but unreachable*: that is the
case where Hermes falls back onto whatever still answers, which is NIM, and the rate
limit you were avoiding arrives with nothing in the transcript to explain it.

### The two models

Both **Apache-2.0** — free weights, commercial use, modify and ship, no licence fee.
Both MoE, both natively multimodal, both tool-calling. They are not redundant copies;
failing over between them is a trade:

| | Qwen3.6-35B-A3B | Qwen3.5-122B-A10B |
|---|---:|---:|
| total / active | 36B / **3B** | 125B / 10B |
| SWE-bench Verified | **73.4** | 72.0 |
| Terminal-Bench 2 | **51.5** | 49.4 |
| BFCL-V4 (tool use) | — | **72.2** |
| MMMU-Pro (vision) | — | **76.9** |
| context | 262K | 262K |
| downloads | 27.9M | 7.0M |

For scale on those: Claude Sonnet 4.5 scores 62.0 on SWE-bench Verified and 75.0 on
MMMU-Pro; GPT-5 mini scores 55.5 on BFCL-V4 against the 122B's 72.2.

The 35B is the better coder and the cheaper one to run. The 122B is the better
tool-caller and the better vision model. That is why the 35B carries the subagents
and the 122B catches the parent's 429s — each tier gets the model suited to it.

**One caveat on 73.4.** Alibaba measured it with their own agent scaffold, not the
standard public harness. DeepSeek published a scaffold comparison showing the harness
alone is worth ~9 points on DeepSWE with identical weights, so that digit is not
directly comparable to other labs' published SWE-bench numbers. Strong model;
vendor-measured number.

**Pinning a provider.** `Qwen/Qwen3.6-35B-A3B` lets HF route for you.
`Qwen/Qwen3.6-35B-A3B:featherless-ai` or `:scaleway` pin a specific one — both are
live — and `:fastest` routes on latency.

## Step 3 — wire Hermes

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak 2>/dev/null || true
cp configs/hermes/config.yaml ~/.hermes/config.yaml
scripts/nim-preflight.sh
```

The preflight is the point. It proves the key authenticates, proves `moonshotai/kimi-k3` is
in the catalog *this key* can see, proves a completion comes back, probes whether tool
calling works, reports any rate-limit headers, and checks that the other two buckets
answer. It never prints any key. `--nim-only` skips the secondary checks; `--list`
prints every model your NVIDIA key can reach.

### Trap 1 — traffic that does not reach NVIDIA

`moonshotai/kimi-k3` is also an OpenRouter catalog slug. Hermes has an open bug
([#39753](https://github.com/NousResearch/hermes-agent/issues/39753)) where a model name
matching the OpenRouter catalog overrides an explicit `provider: custom` + `base_url` and
routes to OpenRouter instead. The session works. The billing goes elsewhere. **Your NVIDIA
key gets sent to a third party.**

The config avoids it by declaring a *named* provider (`providers: nvidia-nim:`) and routing
by provider key rather than by model-name detection. The preflight checks the response
headers for a third-party relay and tells you to rotate the key if it finds one.

### Trap 2 — subagents on the metered endpoint

If `delegation` is unset, children inherit the parent's provider and every one of
them spends a NIM request.

The config routes them by **provider name** (`provider: "custom:hf-router"`), not by
`delegation.base_url`. That is deliberate: the `base_url` path takes an inline
`api_key` and otherwise falls back to `OPENAI_API_KEY` only — there is no `key_env`
for it — so using it would mean pasting a token into a tracked file or having
children authenticate as the wrong account. Naming the provider resolves its
`key_env` instead.

`fallback_providers: []` under `delegation` denies children any chain back onto NIM.
CI asserts all of it, and its failure paths are exercised: subagents on NIM, a
fallback chain restored, an inline key added, or two providers collapsed onto one
host each make the check exit 1.

### Keeping the picker to four models

Two separate sources of clutter, two separate fixes.

**Live discovery.** Every provider sets `discover_models: false`. Without it Hermes
probes each endpoint's `/models` — the HF router and OpenRouter each return hundreds —
and **a `models:` list alone does not whitelist**: Hermes reads that list as
context-length overrides and probes anyway. That surprise is the whole reason the flag
exists, and CI now asserts it on every provider.

**Hermes' built-in provider catalog**, which surfaces independently of anything
configured here. `excluded_providers` hides those.

There is a trap in combining them. The exclusion matches case-insensitively against
*every key a provider can surface under*, so an entry of ours named `openrouter` would
be hidden by the exclusion aimed at the **built-in** openrouter. Ours is therefore called
**`or-fallback`**, and CI asserts no provider name collides with its own exclusion list.

Result: `hermes model` shows exactly four entries.

| tier | provider | model |
|---|---|---|
| parent | `nvidia-nim` | `moonshotai/kimi-k3` |
| subagents | `hf-router` | `Qwen/Qwen3.6-35B-A3B` |
| fallback | `or-fallback` | `qwen/qwen3.5-122b-a10b` |
| floor | `local` | `Hermes-4-14B` |

To add one back, add it to that provider's `models:` — not by re-enabling discovery,
which returns you to hundreds.

### Switching models mid-session

```
/model custom:nvidia-nim:moonshotai/kimi-k3
/model custom:hf-router:Qwen/Qwen3.6-35B-A3B
/model custom:or-fallback:qwen/qwen3.5-122b-a10b
```

Note the triple syntax has had bugs of its own
([#9147](https://github.com/NousResearch/hermes-agent/issues/9147),
[#8470](https://github.com/NousResearch/hermes-agent/issues/8470)) — if a switch appears to
do nothing, check which provider you are actually on before assuming the config is wrong.

## NVIDIA AI Workbench

Workbench is the right container for this if you want the stack reproducible rather than
assembled by hand on one machine — and it is the bridge from your desktop to NVIDIA compute
without moving your working environment.

### How it is laid out

**You install the Desktop App on your laptop, never on a remote.** It is the human-facing
interface either way. A *location* is a machine with Workbench installed: your laptop is
the local location, and NVIDIA Sync handles installing onto a remote and registering it in
the Desktop App. A *desktop-only install* skips the local install entirely — you get the app
and work exclusively on remotes. That last mode is the one to reach for if your laptop has
no NVIDIA GPU: the Desktop App stays on the laptop, the compute is elsewhere, and the
project is the same either way.

A project is a git repository with a `.project/` directory at the top.
`.project/spec.yaml` is the spec file, in four sections — `meta` (identity), `layout`
(directory roles), `environment` (the container build: base image, installed apps) and
`execution` (what runs).

### Where the NVIDIA key goes, exactly

Workbench splits environment variables in two, and the split is the whole reason to use it
for this:

| type | key stored in | value stored in | in git? |
|---|---|---|---|
| non-sensitive | `variables.env` | `variables.env` | **yes, tracked** |
| sensitive | `.project/spec.yaml` | `.nvwb/project-runtime-info/secrets.env` on disk | **no** |

So `NVIDIA_NIM_BASE_URL` and `NVIDIA_NIM_MODEL` are non-sensitive and belong in
`variables.env`. `NVIDIA_API_KEY` is sensitive: **only its name** goes in `spec.yaml`, and
the value lands in `secrets.env` outside the repository, entered once through the Desktop
App. Neither `scripts/nim-preflight.sh` nor this repo's CI will ever see a key, because
there is nowhere in the tracked tree for one to be.

`scripts/nim-preflight.sh` reads `NVIDIA_API_KEY`, `NVIDIA_NIM_BASE_URL` and
`NVIDIA_NIM_MODEL` from the environment, which is exactly what Workbench injects at
container runtime. It runs unchanged inside a Workbench container.

### Start from the example, not from a blank spec

**`nvidia/workbench-example-hybrid-rag`** is NVIDIA's own Workbench project and it already
does the tri-modal thing this stack needs: the same app runs against build.nvidia.com
endpoints, against a self-hosted NIM container via compose, or against local inference,
with quantization options on the local path. That is our topology with different models
plugged in. Fork it — the NVIDIA-owned repo is read-only, so you cannot push to it.

No `.project/spec.yaml` is committed here on purpose. The full field-level schema could not
be verified from this environment, and a spec that looks right but fails validation on your
desktop is worse than no spec — it is the same silent-failure class the doctor and the
preflight exist to catch. Let Workbench write it (it creates `.project/spec.yaml` on
project creation), or adapt hybrid-rag's, then declare `NVIDIA_API_KEY` as a sensitive
variable through the Desktop App.

References:
<https://docs.nvidia.com/ai-workbench/user-guide/latest/concepts/understand-project-specification.html>
· <https://docs.nvidia.com/ai-workbench/user-guide/latest/reference/projects/runtime-configuration-reference.html>
· <https://docs.nvidia.com/ai-workbench/user-guide/latest/reference/user-interface/desktop-app.html>

## Scaling Kimi-K3 onto your own GPUs

If NIM's rate limit becomes the bottleneck and you have the hardware, the self-host path is
`nvidia/Kimi-K3-NVFP4` — the best Kimi-K3 quant published, and the only one with
side-by-side evals against the original. It is a Dynamo day-0 recipe. Entry ticket is 8×
B300 (vLLM or SGLang) or 16× GB200/GB300 under Dynamo. Sizes, evals and the vLLM/SGLang
caveats are in `kimi-k3-quants.md`.
