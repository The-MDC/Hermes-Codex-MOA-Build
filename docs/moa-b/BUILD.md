# Hermes-MOA-B Build Plan

## 1. Overview
Create a **Mixture‑of‑Agents (MOA)** inside Hermes that:
- Generates high‑quality code (CodeLlama‑13B‑Instruct‑hf‑abliterated‑GGUF, Q8_0)
- Plans and reasons about tasks (MiniCPM‑3B)
- Reviews and audits code (CodeLlama‑13B‑Instruct‑hf‑abliterated‑GGUF, Q8_0 + Mixtral‑6×7B‑Trimmed, Q6_K)
- Adds multimodal vision for chart/table analysis (Ising‑Calibration‑1.5‑31B‑BF16, i1‑Q6_K)
- Dispatches tasks across the swarm via a coordinator that shares the Vision agent's loaded model (Ising‑Calibration‑1.5‑31B‑BF16, i1‑Q6_K)
- Supports a **copy‑trade** smart agent workflow
- Uses **Kanban** for task orchestration and parallel execution

No DeepSeek or other proprietary/gateway-only model is part of this agent roster — every
model above is publicly hosted on Hugging Face and loaded locally via `hermes model load`.

## 2. Prerequisites
- Hermes desktop app installed and running (CLI available)
- Python 3.14+ with `hermes-tools` available (`from hermes_tools import ...`)
- NVIDIA GPU(s) with **~70 GB combined VRAM** to keep Generator/Reviewer, Audit, and
  Vision/Swarm Coordinator resident at once at the quants below (see §5) — this build
  assumes NVIDIA inference/compute headroom, not a single consumer card
- Internet access for model download

## 2.1 Profile & Workspace Setup
```bash
# Create a dedicated profile (isolated config & memory)
hermes profile create codex-moa \
  --workspace_path ~/.hermes/profiles/codex-moa \
  --initial_status "running"

# Set memory limit — see §5 for the real per-model footprint this must cover
hermes config set memory_limit_gb 80
```

## 2.2 Kanban Board (Task Board)
```bash
# Create a board for the MOA
kanban_create \
  --title "MOA‑B Build" \
  --assignee "hermes-agent" \
  --board "default" \
  --workspace_path ~/.hermes/cache/scratch \
  --initial_status "todo"
```

## 3. Model Acquisition & Quantisation

1. **CodeLlama‑13B‑Instruct‑hf‑abliterated (Q8_0)** — Generator + Reviewer
   ```bash
   wget -O ~/.hermes/cache/codellama-13b-q8_0.gguf \
        https://huggingface.co/mradermacher/CodeLlama-13b-Instruct-hf-abliterated-GGUF/resolve/main/CodeLlama-13b-Instruct-hf-abliterated.Q8_0.gguf
   ```
   Live-verified, 13.83 GB. Q8_0 only exists in mradermacher's plain `-GGUF` repo — the
   imatrix `-i1-GGUF` repo for this model tops out at i1‑Q6_K, so the two can't be
   combined.

2. **MiniCPM‑3B (int8)** – pull from HuggingFace or use the pre‑quantised file. — Planner

3. **Mixtral‑6×7B‑Instruct‑v0.1‑bfloat16‑Trimmed024567 (Q6_K)** — Audit
   ```bash
   wget -O ~/.hermes/cache/mixtral-6x7b-q6_k.gguf \
        https://huggingface.co/mradermacher/Mixtral-6x7B-Instruct-v0.1-bfloat16-Trimmed024567-GGUF/resolve/main/Mixtral-6x7B-Instruct-v0.1-bfloat16-Trimmed024567.Q6_K.gguf
   ```
   Live-verified, 29.07 GB. This is a real, publicly-hosted **6-expert prune of
   Mixtral‑8×7B** (`DrNicefellow/Mixtral-6x7B-Instruct-v0.1-bfloat16-Trimmed024567`,
   two of the eight original experts removed), quantised by mradermacher — not a
   hypothetical. Sizing, same quant level both sides:

   | | 8 experts (original) | 6 experts (this build) | offset |
   |---|---|---|---|
   | Q6_K | 38.38 GB | **29.07 GB** | **‑9.31 GB (‑24.3%)** |
   | Q8_0 | 49.62 GB | 37.65 GB | ‑11.98 GB (‑24.1%) |
   | Q4_K_M | 26.44 GB | 21.44 GB | ‑5.00 GB (‑18.9%) |

   Picked **Q6_K over the plan's old "4‑bit"** on purpose: dropping 2 experts already
   frees ~9 GB at matching quality, and NVIDIA compute headroom means that saving is
   better spent on fidelity (Q6_K) than banked as a further size cut. If VRAM gets
   tight again, Q4_K_M on this same 6‑expert file (21.44 GB) is the fallback, not a
   return to 8 experts.

4. **Ising‑Calibration‑1.5‑31B‑BF16 (i1‑Q6_K)** — Vision, shared instance with Swarm Coordinator
   ```bash
   wget -O ~/.hermes/cache/ising-calibration-31b-q6_k.gguf \
        https://huggingface.co/mradermacher/Ising-Calibration-1.5-31B-BF16-i1-GGUF/resolve/main/Ising-Calibration-1.5-31B-BF16.i1-Q6_K.gguf
   ```
   Live-verified, 25.20 GB. Load once; point both the Vision agent and the Swarm
   Coordinator at the same running instance rather than loading two copies.

## 4. Agent Definitions & Spawning
| Agent | Model | Quant | Role | Hermes command (example) |
|-------|-------|-------|------|--------------------------|
| **Generator** | CodeLlama‑13B‑Instruct‑hf‑abliterated | Q8_0 | Write code, refactor, generate tests | `hermes spawn --subagent_id generator --goal "Write FastAPI auth service"` |
| **Planner** | MiniCPM‑3B | int8 | Break down tasks, suggest steps | `hermes spawn --subagent_id planner ...` |
| **Reviewer** | CodeLlama‑13B‑Instruct‑hf‑abliterated (same as generator) | Q8_0 | PR‑level review, linting | `hermes spawn --subagent_id reviewer ...` |
| **Audit** | Mixtral‑6×7B‑Trimmed024567 (6-expert prune of Mixtral‑8×7B) | Q6_K | Deep audit, security & compliance | `hermes spawn --subagent_id audit_agent ...` |
| **Vision** | Ising‑Calibration‑1.5‑31B‑BF16 | i1‑Q6_K | Parse chart images, extract data | `hermes spawn --subagent_id vision_agent ...` |
| **Swarm Coordinator** | Ising‑Calibration‑1.5‑31B‑BF16 (shared instance with Vision) | i1‑Q6_K | Watches the Kanban board, dispatches each new task to the least‑loaded agent | `hermes spawn --subagent_id swarm_coordinator --goal "watch kanban, dispatch"` |
| **Orchestrator** | Hermes‑Agent (built‑in) | – | Coordinates agents, manages Kanban, enforces resource limits | Runs automatically; no extra spawn needed |

**Link tasks** so that each step waits for the previous one:
```bash
kanban_link --parent_id <generator_task_id> --child_id <reviewer_task_id>
kanban_link --parent_id <reviewer_task_id> --child_id <audit_task_id>
kanban_link --parent_id <audit_task_id> --child_id <vision_task_id>
```

## 5. Resource Budget (example `config.yaml`)

```yaml
mixture_of_experts:
  enabled: true
  routing:
    - task_type: "code_gen"      -> profile: codellama13b
    - task_type: "planning"      -> profile: minicpm3b
    - task_type: "review"        -> profile: codellama13b
    - task_type: "audit"         -> profile: mixtral6x7b
    - task_type: "vision"        -> profile: ising_calibration_31b
    - task_type: "dispatch"      -> profile: ising_calibration_31b   # Swarm Coordinator, shares the Vision profile
  max_concurrent: 2               # limit parallel sub‑agents
  memory_limit_gb: 80
```

**Live-verified footprint, resident models:**

| Model | Quant | Size |
|---|---|---|
| CodeLlama‑13B (Generator/Reviewer) | Q8_0 | 13.83 GB |
| Mixtral‑6×7B‑Trimmed (Audit) | Q6_K | 29.07 GB |
| Ising‑Calibration‑31B (Vision + Swarm Coordinator, one shared instance) | i1‑Q6_K | 25.20 GB |
| MiniCPM‑3B (Planner) | int8 | ~3 GB |
| **Total** | | **~71 GB** |

`memory_limit_gb: 80` gives headroom above that ~71 GB floor. This is well past what a
single consumer GPU offers — it assumes the NVIDIA inference/compute capacity already
in place for this build, not a 12–30 GB card. If that capacity shrinks, the fallback
order is: drop Mixtral‑6×7B to Q4_K_M (‑7.6 GB), then unload Vision/Swarm Coordinator
between uses rather than keeping the 25 GB Ising‑Calibration instance resident
continuously.

## 6. Execution Flow
1. **User request** → Hermes chat command (`hermes chat -q "...`).
2. **Hermes‑Agent** parses the request, creates a Kanban task, and **spawns** the required sub‑agents.
3. Agents run in isolated subprocesses; each reads/writes to its own scratch directory under `~/.hermes/cache/scratch`.
4. Upon completion, each agent **writes its output** to the Kanban task's attachment directory; the orchestrator aggregates results and returns a final summary to the user.
5. For **copy‑trade** scenarios, the Vision agent extracts chart data, the Generator produces a trading‑bot script, and the Reviewer/Audit agents validate logic before the script is handed to the broker‑API MCP server.

## 7. Validation & Testing
- Run `hermes doctor` to verify environment health.
- Execute a **smoke test**: ask the generator to write a simple "Hello World" script, then have the reviewer check it.
- Use `kanban_show <task_id>` to inspect intermediate results.
- Verify that the final deliverable (script + audit log) is present as a downloadable artifact (`MEDIA:` link) in the chat.
- Time the Swarm Coordinator's first dispatch after a cold start, and confirm it still dispatches promptly while the Vision agent is mid-task on the same shared model.

## 8. Copy‑Trade Extension (Future‑Proof)
1. **Vision Agent** extracts price points from chart images.
2. **Planner** creates a trade‑strategy outline (entry, stop‑loss, position size).
3. **Generator** writes the trading script (e.g., using `ccxt` or a broker SDK).
4. **Audit** verifies no hard‑coded secrets, checks risk limits, logs actions.
5. **Hermes‑MCP** (or a custom webhook) executes the script on the chosen exchange.

## 9. Rollback / Cleanup
- To revert, simply delete the profile directory: `rm -rf ~/.hermes/profiles/codex-moa`.
- Remove attached artifacts with `kanban_attachments` if needed.

## 10. Possible Future Enhancements (unverified, not yet integrated)

None of this is wired into the plan above. It's candidate follow-up work, live-checked
against NVIDIA's own pages so speculative "could leverage X" language isn't repeated
as fact. **All of it also depends on a `hermes model load` / `hermes spawn` /
`kanban_*` CLI surface this repo has no spec for** — these commands appear throughout
this doc because they were specified that way, not because they've been verified
against a real Hermes CLI reference. Treat every command below the same way.

| Candidate | What it actually is (live-verified) | Fit for this build |
|---|---|---|
| **NemoClaw** | Real, open-source NVIDIA stack ([blog](https://developer.nvidia.com/blog/building-a-memory-driven-agent-with-nvidia-nemoclaw), [docs](https://docs.nvidia.com/nemoclaw/latest/)). Sandboxes "always-on assistant" (OpenClaw) agents with kernel-level isolation, network policy, and local/cloud privacy routing, bundling OpenShell + Nemotron + a Privacy Router. | **Correctly targeted.** The Swarm Coordinator keeps a 25 GB model resident and dispatches continuously — exactly the "always-on agent" shape NemoClaw sandboxes. Worth a real spike before the swarm is wired into anything that touches secrets or the network. |
| **NVIDIA NIM** | Real, containerized inference microservices with OpenAI-compatible-style APIs, backed by TensorRT-LLM/vLLM/SGLang ([overview](https://developer.nvidia.com/nim)). Either self-hosted or hosted. | Plausible alternative backend for Generator/Audit/Vision instead of raw GGUF+llama.cpp, if this build ever moves off single-box local inference. Not evaluated against this repo's actual `nvidia-nim` provider config. |
| **TensorRT-LLM** | Real, NVIDIA's optimized LLM inference engine. | Could replace llama.cpp for serving CodeLlama-13B / Ising-Calibration-31B with better throughput — but changes the serving stack this whole doc assumes (`hermes model load --path *.gguf`), so it's a bigger change than a model swap, not a drop-in. |
| **RAG Blueprint** (`build.nvidia.com/skills` → `rag-blueprint`) | Real, end-to-end RAG deployment reference (Docker/Helm, NIM-backed). | Would give the Reviewer/Audit agents grounded retrieval over this repo's own docs instead of relying on model memory. Independent of the model choices above — additive, not a replacement. |

**Explicitly not carried forward:** the NVIDIA "AI Factory Operations Agent" (FOX)
blueprint was suggested earlier in this thread as generic Hermes sub-agent
orchestration. Live-checked ([NVIDIA blog](https://blogs.nvidia.com/blog/factory-operations-fox-blueprint-ai-brain/)):
FOX is real, but it's a physical-manufacturing blueprint (robot fleets, machine QC,
industrial IoT integration) — it doesn't do generic software agent orchestration
and isn't a fit here.

---

*All steps are designed to be executed from the Hermes desktop app or via its CLI. The plan uses only tools already available in the Hermes environment, ensuring a smooth integration into the existing repo.*
