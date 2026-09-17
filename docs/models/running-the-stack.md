# Running the stack: Kimi-K3 on NIM, TripleTrouble-V3 local

What to install, in what order, and the two traps that cost a session each.

Config: `configs/hermes/config.yaml` · Preflight: `scripts/nim-preflight.sh` ·
Quant survey: `docs/models/kimi-k3-quants.md`

## The shape of it

```
  Hermes parent agent  ─────────────▶  moonshotai/kimi-k3
                                       NVIDIA NIM · integrate.api.nvidia.com
                                       2.8T params · 1M ctx · vision · always-thinking

  Hermes subagents     ─────────────▶  TripleTrouble-V3
  + the 429 fallback                   local llama.cpp or vLLM · 127.0.0.1
                                       34.7B total / ~3.3B active · 131K ctx
```

Kimi-K3 does the thinking. Everything that fans out runs local and free.

**Why not run Kimi-K3 locally too:** there is no build that fits. The smallest unpruned
GGUF is 466 GB; the smallest pruned build anyone has demonstrated is 319 GiB at 0.48 tok/s.
Full reasoning in `kimi-k3-quants.md`.

**Why the subagents are the interesting half:** NIM's free tier runs around 40 RPM and
Kimi-K3 users report hitting 429 easily. One Hermes delegation batch can spend a whole
minute's budget. Moving children onto a local endpoint is not a cost optimisation, it is
what keeps the parent's requests available for the work you care about.

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

## Step 2 — local TripleTrouble-V3

`OliviaRossi/TripleTrouble-V3` is a merge of three Qwen 35B-A3B checkpoints —
KAT-Coder-V2.5-Dev (40%), Ornith-1.5-35B-A3B (35%), Qwen-AgentWorld-35B-A3B (25%) — fused
by normalized geodesic consensus with row-wise router calibration. 34.7B total, ~3.3B
active per token, 256 routed experts top-8, 40 layers, 131,072 context, Apache 2.0.

**Read this before you rely on it:** the model card publishes **no evaluation results at
all.** Not one benchmark against any of its three parents. The merge mathematics are
carefully described and the architecture claims are checkable, but "more capable" is not
established by anything published. Treat it as an unvalidated merge and test it on your own
work before trusting it with anything that matters. That is this repo's
no-claim-without-evidence rule applied to a model instead of a pitch deck.

### Which quant

`mradermacher/TripleTrouble-V3-i1-GGUF` — imatrix quants, the best-supported repo of the
three. Measured sizes:

| quant | size | fits |
|---|---:|---|
| `i1-IQ4_XS` | 18.7 GB | 24 GB card with real KV headroom |
| `i1-Q4_K_M` | **21.2 GB** | **the default. 32 GB+ VRAM, or unified memory** |
| `i1-Q5_K_M` | 24.7 GB | 32 GB card |
| `i1-Q6_K` | 28.5 GB | 48 GB, approaching diminishing returns |
| `i1-IQ2_M` | 11.7 GB | 16 GB card, real quality cost |
| `i1-IQ1_S` | 7.5 GB | a curiosity, not a working agent |

Take **`i1-Q4_K_M`** unless memory forces otherwise. It is a merge already — stacking
aggressive quantization on top of merge drift compounds two sources of damage that nobody
has measured together.

**On RTX 50-series / RTX PRO 6000 Blackwell (sm_120), prefer the K-quants.** The
`iq1_s`/`iq2_s`/`iq3_s` tensor types have broken CUDA matmuls on sm_120 and **silently
produce garbage** rather than failing — documented by the author of
`prometheusAIR/Kimi-K3-REAP55-GGUF`, who built that model specifically to avoid them. It is
a property of the tensor types, not of any one model, so it applies here too.

```bash
hf download mradermacher/TripleTrouble-V3-i1-GGUF \
    TripleTrouble-V3.i1-Q4_K_M.gguf --local-dir ~/models

llama-server -m ~/models/TripleTrouble-V3.i1-Q4_K_M.gguf \
    --port 8090 --host 127.0.0.1 -ngl 99 -c 131072 --jinja \
    --temp 0.3 --top-p 0.90
```

`--jinja` matters: without it the chat template is not applied and tool calls do not form.
Temperature 0.3 / top-p 0.90 is the card's own recommendation for tool calling and MCP
agents, which is what Hermes subagents do. For code synthesis it suggests 0.2 / 0.85; for
open-ended reasoning 0.6 / 0.92.

vLLM instead, if you have the VRAM for unquantized:

```bash
vllm serve OliviaRossi/TripleTrouble-V3 \
    --port 8090 --tensor-parallel-size 2 --max-model-len 32768 \
    --gpu-memory-utilization 0.90 --trust-remote-code
```

Single 80 GB card: add `--quantization fp8`.

## Step 3 — wire Hermes

```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.bak 2>/dev/null || true
cp configs/hermes/config.yaml ~/.hermes/config.yaml
scripts/nim-preflight.sh
```

The preflight is the point. It proves the key authenticates, proves `moonshotai/kimi-k3` is
in the catalog *this key* can see, proves a completion comes back, probes whether tool
calling works, reports any rate-limit headers, and checks the local endpoint is up. It
never prints the key.

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

If `delegation.base_url` is unset, children inherit the parent's provider and every one of
them spends a NIM request. The config pins them to `127.0.0.1` and gives them
`fallback_providers: []`, so a local outage fails loudly instead of quietly draining the
rate limit. CI asserts both.

### Switching models mid-session

```
/model custom:nvidia-nim:moonshotai/kimi-k3
/model custom:tripletrouble:TripleTrouble-V3
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
