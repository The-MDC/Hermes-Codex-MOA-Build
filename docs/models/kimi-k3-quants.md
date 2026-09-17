# Kimi-K3 quantizations, and what to actually run

Surveyed 2026-09-17 against the live Hugging Face Hub and NVIDIA's NIM catalog.
Every size below is a sum of the real LFS file sizes, not a repo-card claim.

## The finding that decides everything

**Kimi-K3 ships as MXFP4.** Moonshot quantization-aware-trained it: `MXFP4 weights /
MXFP8 activations`, 2.8T total parameters, 104B activated, 896 experts with 16 selected
per token, 1,048,576-token context, native vision.

That single fact breaks the usual quantization instinct. The release is *already* 4-bit,
so the ladder above 4-bit is pure waste and the ladder below it eats into weights that were
trained to be 4 bits wide. There is no "quantize it to make it fit" move here.

The numbers say it plainly — `unsloth/Kimi-K3-GGUF`, measured:

| build | shards | size | note |
|---|---:|---:|---|
| `UD-Q1_0` | 11 | **466.4 GB** | smallest unpruned build published |
| `UD-TQ1_0` | 12 | 508.9 GB | |
| `UD-TQ2_0` | 13 | 551.5 GB | |
| `UD-IQ1_S` | 14 | 594.0 GB | 78.9% top-1 agreement with unquantized (Unsloth's figure) |
| `UD-IQ1_M` | 15 | 648.9 GB | |
| `UD-IQ2_XXS` | 16 | 711.1 GB | 84.1% top-1 agreement |
| `UD-Q2_K_XL` | 19 | 861.3 GB | |
| `UD-Q4_K_XL` | 32 | 1,508.7 GB | ← **at the native checkpoint's size** |
| `UD-Q8_K_XL` | 34 | 1,561.2 GB | ← **above it.** Upcasting 4-bit weights to 8 bits |

The MXFP4 source is 1.56 TB. `UD-Q8_K_XL` is 1.561 TB. You would download the whole model
to get back exactly what Moonshot published, in a slower container. `UD-Q4_K_XL` is no
better: same bit width as the source, 1.5 TB, zero saved.

So the real ladder is 466 GB → 861 GB, and **none of it runs on a desktop.** The smallest
honest number for unpruned Kimi-K3 is 466 GB of weights that all have to be reachable at
decode time.

## Best quant: `nvidia/Kimi-K3-NVFP4`

<https://huggingface.co/nvidia/Kimi-K3-NVFP4> · NVIDIA Model Optimizer v0.45.0 · ~1.6 TB

It is the best quant for one reason that none of the others can match: **it is the only
Kimi-K3 quantization published with a side-by-side evaluation against the original.**

| benchmark | original Kimi-K3 | Kimi-K3-NVFP4 |
|---|---:|---:|
| GPQA Diamond | 0.9321 | 0.9277 |
| SciCode | 0.5838 | **0.5858** |
| MMMU-Pro | 0.8063 | 0.7983 |
| AA-LCR | 0.7500 | **0.7506** |
| IFBench | 0.7440 | **0.7493** |
| Terminal-Bench 2.1 | 0.8034 | 0.8020 |

Three of six land above the original — which is what measurement noise looks like, and is
the point: the conversion is within noise of lossless. It is not a compression play. It is
a *format* play: routed experts go MXFP4 → NVFP4 with `input_scale=1.0` and no calibration
data at all, attention projections go to 128×128 per-block FP8, and the result runs on
Blackwell tensor cores natively. Same bits, different silicon path.

Validated on 8× B300 under vLLM and SGLang. Governed by the NVIDIA Open Model Agreement on
top of the Kimi K3 License.

Everyone else's Kimi-K3 quant repo publishes no eval at all. That is the whole ranking.

## Best merged quant: `prometheusAIR/Kimi-K3-REAP55-GGUF`

"Merged" for a 896-expert MoE means expert *merging or pruning*, and there are two schools.

**REAP (expert pruning)** — score each expert by `gate · ‖expert output‖` over a calibration
corpus, keep the top N, slice the rest out. The expert axis is outermost in GGUF, so
surviving experts are byte-identical copies: **zero added quantization error.** The cost is
whatever the calibration corpus under-represented, which disappears silently.

| build | experts kept | size | evidence |
|---|---|---:|---|
| `prometheusAIR/Kimi-K3-REAP55-GGUF` | 400/896 (55% pruned) | **319 GiB** | needle 15/15 through 64K; imatrix coverage on all 400 experts in all 92 layers |
| `hellohazime/…REAP576-IQ2_XXS` | 576/896 | 478.5 GB | **SWE-Lancer 7/8, $13,000** |
| `hellohazime/…REAP640-IQ1_S` | 640/896 | 441.4 GB | SWE-Lancer 5/8, $3,500; measured KLD vs unpruned |

REAP55 is the pick on craft: converted from the native MXFP4 master rather than from a
requantized intermediate, and deliberately built to avoid `iq1_s`/`iq2_s`/`iq3_s`, whose
CUDA matmuls are **broken on sm_120 (RTX 50-series, RTX PRO 6000 Blackwell) and silently
produce garbage**. If you own Blackwell consumer silicon, that disqualifies most of the
sub-2-bit field outright.

`hellohazime`'s pair is the pick on *evidence* — real SWE-Lancer runs with dollar figures
and a published KLD study — and its author is unusually honest about single-attempt
variance. Both authors state the same caveat: the calibration corpora were English + code,
so **neither build speaks Chinese or Japanese any more.** That is not a bug, it is what
pruning is.

**MergeMoE (expert merging)** — `HaithamalWaisy/kimi-k3-merged` collapses all 896 experts
per layer into 2 super-experts, producing a dense 62.23B / 66.3 GB model. It is the only
Kimi-K3 derivative that would actually fit a workstation. Three reasons not to reach for it:

1. Its own card says **"Quality was not benchmarked by this project."**
2. It is derived from Unsloth's `UD-IQ1_S` — a 1-bit quant — so merge loss stacks on top of
   1-bit loss.
3. It is labelled **Apache 2.0 "inherited from Kimi K3"**, which is wrong. Kimi K3 is under
   the Kimi K3 License, not Apache 2.0. Do not rely on that licence statement.

Its stated purpose is a base for fine-tuning and RL, not for serving. Taken on those terms
it is interesting. It is not a way to run Kimi-K3.

## What this means for compute

Speed on pruned local builds, measured by their authors:

- REAP55 on RTX PRO 6000 Blackwell + 125 GiB DDR5 + Gen5 NVMe RAID0: **0.48 tok/s** warm,
  0.32 cold. Storage-bound, not GPU-bound — the 262 GiB expert pool streams from NVMe.
- REAP640/576 on a Mac Studio M3 Ultra 512 GB, fully resident: **~3.0 tok/s** decode.

3 tok/s is not an agentic coding loop. It is a model you ask one question and walk away
from. Kimi-K3 is always-thinking, so a single reply spends thousands of tokens inside the
reasoning channel before it says anything.

**Conclusion: do not self-host Kimi-K3 for interactive work.** Route it. See
`configs/hermes/config.yaml`.

## If you do want it on your own metal

Then it is NVFP4 on NVIDIA silicon, and the entry ticket is a rack:

| path | hardware | source |
|---|---|---|
| vLLM, aggregated | 8× B300 | `nvidia/Kimi-K3-NVFP4` model card |
| SGLang + DSPARK speculative decoding | 8× B300 | same |
| Dynamo, aggregated | 16× GB200 / 16× GB300 (TP16 over MNNVL) | NVIDIA Dynamo recipe |
| Dynamo, disaggregated 1P1D | 32× GB200 | same |
| Dynamo, disaggregated 1P2D | 24× GB300 | same |
| Dynamo, H200 | 32× H200 | same |

Kimi-K3 is a **day-0 Dynamo recipe** (vLLM + SGLang, H200 · GB200 · GB300), so the
Kubernetes path is supported rather than improvised. Note vLLM support is not upstream yet
— the NVFP4 repo ships a required compatibility patch, tracked in vLLM PRs #50617, #52406
and #52405; SGLang support is tracked in PR #35077 and needs the
`lmsysorg/sglang:dev-dev-kimi-k3-nvfp4` image. A pip-installed SGLang cannot load the
checkpoint.

First launch pulls ~1.6 TB. `fastsafetensors` brings 8×B300 startup to ~18 minutes; the
default loader is much slower.

## llama.cpp status

Kimi-K3 is **not in any llama.cpp release.** Every GGUF above needs
[PR #26185](https://github.com/ggml-org/llama.cpp/pull/26185) (the `kimi-k3` arch), and the
chat parser needs patching on top — llama.cpp's auto-parser derives XTML delimiters by
diffing template renders, picks `<|sep|>` and `<|close|>`, and those appear in every
channel, so reasoning terminates early and scaffolding leaks into content. Tool calls break
for the same reason. Both prune authors ship or reference a patch.

Also load-bearing if you try it: `--cache-reuse 0` is **required** — partial prefix-cache
reuse corrupts the KDA recurrent state.

## Sources

- `moonshotai/Kimi-K3` model card — architecture, MXFP4 QAT, benchmarks
- `nvidia/Kimi-K3-NVFP4` model card — conversion method, evals, vLLM/SGLang recipes
- `unsloth/Kimi-K3-GGUF` — file listing, measured 2026-09-17
- `prometheusAIR/Kimi-K3-REAP55-GGUF`, `hellohazime/Kimi-K3-REAP-512GB-GGUF` — prune method,
  KLD study, SWE-Lancer results, sm_120 warning
- `HaithamalWaisy/kimi-k3-merged` — MergeMoE
- NVIDIA Dynamo recipe catalog — GPU topologies
