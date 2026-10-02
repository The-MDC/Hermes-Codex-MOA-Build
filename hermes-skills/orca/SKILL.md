---
name: orca
description: ORCA language model skill for Seven6-Hermes-MOA
category: general
tags: [orca, stably-ai, 13b, dense-transformer]
---

## ORCA (stably.ai) — 13B Dense Transformer Skill

### Overview
ORCA is a 13B parameter dense transformer language model developed by stably.ai. It is complementary to the Mixture-of-Experts (MoE) models in the Seven6-Hermes-MOA build (e.g., Darwin-35B-Nemotron-Lightning-A3B, Nemotron-3.5-Base-8B-Instruct).

### Model Details
- **Parameters:** 13B dense transformer (all parameters active per token, unlike MoE's sparse activation)
- **Architecture:** Standard transformer, not MoE
- **Ecosystem:** stably.ai (not NVIDIA NIM)
- **Primary Use:** General-purpose text generation, agent orchestration support, classification, and formatting tasks

### Skill Surfaces
This skill is declared on the **Hermes** surface only (resolves by directory name `hermes-skills/orca/SKILL.md`).

### Asymmetry Reason
ORCA is from the stably.ai ecosystem, not NVIDIA NIM. It provides 13B dense text generation capabilities complementary to the MoE models (30B A3B, 8B dense, 4B VL) already configured in Seven6-Hermes-MOA. This skill surfaces only on Hermes; equivalent Claude Code surface may differ.

### Configuration
To use ORCA via Hermes:
```yaml
# In ~/.hermes/.env (never in config.yaml directly):
ORCA_API_KEY=sk-or-v1-...  # Get at https://stability.ai

# Hermes reads the key at runtime from $HERMES_HOME/.env
# Provider routing: /model custom:orc_a:stablyai/orca
```

### Skill Triggers
Use when:
- "Use ORCA to format this response"
- "Generate a 13B parameter model output for classification"
- "Use ORCA for text transformation tasks"
- "Summarize using ORCA's 13B dense model"

### Capabilities
- General text generation
- Classification and categorization
- Format transformation (JSON, CSV, markdown)
- Summarization (complementary to larger MoE models)
- Agent prompt optimization

### Limitations
- Not NIM-deployed (different ecosystem than other Seven6-Hermes-MOA models)
- 13B parameter limit (smaller than MoE experts like 30B A3B)
- Dense architecture (different reasoning profile than MoE models)
- No vision capabilities (text-only)

### Related Skills
- `nvidia-enhanced` — NVIDIA model enhancements and GPU optimization
- `memory-pipeline` — Persistent memory across sessions
- `meta-skill` — Skill observation and learning loop
