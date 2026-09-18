# The local floor: a model on your own machine

Added because the three cloud tiers share one failure mode — no network takes all of
them at once. This tier is the only one nothing can rate-limit, meter, or disconnect.

It is **not** a peer of the tiers above it. 14B against 36B and 2.8T. Use it when the
others cannot be reached, or for narrow tool-calling where a large model is waste.

## The model: `NousResearch/Hermes-4-14B`

"Optimized for Hermes" is literal here rather than a claim. NousResearch builds Hermes
Agent, and they build this. It was post-trained for exactly what the harness needs —
ChatML, function calling, tool use, JSON mode, structured outputs — on a Qwen3-14B base,
with hybrid reasoning that can be switched off.

Nothing else in the field can say that. Every other candidate is a general model you
hope handles tool calls well; this one was trained against the harness it will run in.

### Which quant

Sizes from `bartowski/NousResearch_Hermes-4-14B-GGUF` (imatrix, best-maintained):

| quant | size | for |
|---|---:|---|
| `IQ4_XS` | **8.11 GB** | 16 GB machine with other things running |
| `IQ4_NL` | 8.54 GB | non-I-quant CUDA fallback |
| `Q4_K_M` | **9.00 GB** | the default on 16 GB |
| `Q5_K_M` | 10.51 GB | 24 GB |
| `Q6_K` | **12.12 GB** | 32 GB; past here returns diminish fast |
| `Q8_0` | 15.70 GB | only if RAM is free and you want it |

**On RTX 50-series / RTX PRO 6000 (sm_120), avoid `IQ2_*`/`IQ3_*`** — those tensor types
have broken CUDA matmuls there and *silently emit garbage* rather than failing. `IQ4_XS`
is outside that set, but `Q4_K_M` is the safer choice on that hardware.

```bash
hf download bartowski/NousResearch_Hermes-4-14B-GGUF \
    NousResearch_Hermes-4-14B-Q4_K_M.gguf --local-dir ~/models

llama-server -m ~/models/NousResearch_Hermes-4-14B-Q4_K_M.gguf \
    --port 8080 --host 127.0.0.1 -ngl 99 -c 32768 --jinja
```

`--jinja` is load-bearing: without it the ChatML template is not applied and tool calls
never form. That is the single most common way this tier appears broken.

### What was rejected, and why

**`NousResearch/Hermes-4.3-36B`** (Nov 2025) is newer and stronger — and its official
Q4_K_M is **21.76 GB**, the same class as the local model that already did not fit. The
official GGUF ladder runs 17.62 GB (Q3_K_M) to 38.42 GB (Q8_0). Not a laptop model.

**`Edge0/Edge0-35B-A3B-preview`** is a genuinely clever piece of work — a 35B MoE running
in **under 3 GiB of active memory** at 15 tok/s by streaming experts from SSD, within 3.9
points of its fp16 base. It is disqualified by its own model card: *"not yet optimized for
agentic tasks — tool use, multi-step planning, and long-horizon autonomy are currently
weak."* Apple-Silicon-only too. Worth watching for the full release.

**If 8.11 GB is still too much**, `TokenRhythm/NeoHorse-1-4B` is 2.71 GB at Q4_K_M and
4.48 GB at Q8_0, Apache-2.0, purpose-built for agent harnesses: tau2-Bench 88.46 (best in
its 4B cohort), BFCL v4 61.79, IFBench 65.33, HumanEval 96.95, 262K context. First-party
GGUF at `TokenRhythm/NeoHorse-1-4B-GGUF`. Change `model` and the download line; nothing
else in the config moves.

## The research browser

**Hermes already has one.** `web_search` and `web_extract` are model-callable tools with a
provider registry, so this is configuration, not construction.

SearXNG is the free half: self-hosted metasearch over 70+ engines, no API key, no rate
limit. It is **search-only** — no extract, no crawl — so the config pairs it with
Firecrawl for extraction.

```bash
docker run -d -p 8888:8080 --name searxng searxng/searxng
# then, in ~/.hermes/.env:
SEARXNG_URL=http://127.0.0.1:8888
```

**Naming the backend is load-bearing.** Hermes' auto-detection walks a priority ladder —
Firecrawl > Parallel > Tavily > Exa > SearXNG > Brave > DDGS — so merely having
`FIRECRAWL_API_KEY` in your environment silently wins over SearXNG, and you never find out
your "free local search" is billing an API. `web.search_backend: searxng` in the config
stops that, and CI asserts it stays named.

With no `SEARXNG_URL` and no keys at all, Hermes falls to DDGS (DuckDuckGo, keyless).
Degraded, but the local model is not left without a browser.

If SearXNG returns **403**, its JSON API is off: add `- json` under `search.formats` in
its `settings.yml`. `scripts/nim-preflight.sh` reports that case by name.

## Turn thinking off for this tier

Hermes 4 is hybrid-mode — it reasons only when asked. The config sets
`chat_template_kwargs: {thinking: false}` because reasoning tokens are pure latency on a
machine already decoding slowly, and tool calls do not benefit from them. Turn it back on
for a question you actually want reasoned through.

## What CI enforces

The loopback provider is exempt from the `key_env` rule — a server on your own machine
authenticates nothing, so its "key" is a placeholder, not a secret. **The exemption keys
on the host resolving to loopback, not on the provider being named `local`**, so renaming
a remote endpoint cannot smuggle a real key past the check. That failure path is
exercised: pointing `local` at a remote host makes the check exit 1.
