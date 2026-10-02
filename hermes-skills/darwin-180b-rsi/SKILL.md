---
name: darwin-180b-rsi
description: """"
version: 1.0.0
author: "unknown"
license: "MIT"
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [automatically-portled]
    category: general
    related_skills: []
---

# darwin-180b-rsi Skill

## Description
Darwin-180B-RSI is the newest flagship of the Darwin family — #1 on AIME 2026, HMMT Feb 2026, GPQA Diamond, MMLU-Pro and MMMU-Pro, and a model that gets better by learning from its own verified work.

## Why This Skill is Valuable
- Provides massive reasoning uplift via 180B MoE with 512 experts
- Self-improving mechanism learns from verified work (reduces hallucination over time)
- Measurement-driven evolution precisely targets weaknesses while preserving existing capabilities
- 262K long context enables deep reasoning over extensive inputs
- Vision-language capability adds versatility
- Korean + English support
- Dominates key reasoning benchmarks (AIME, HMMT, GPQA, MMLU-Pro, MMMU-Pro)

## Key Features
- 180B total parameters, 512 experts (MoE)
- Vision-language model
- 262K long context
- Korean + English
- Self-improving (learns from verified work)
- Measurement-driven evolution
- Benchmark performance:
  - AIME 2026: 100 🥇
  - HMMT Feb 2026: 100 🥇
  - GPQA Diamond: 94.44 🥇
  - MMLU-Pro: 88.12 🥇
  - MMMU-Pro: 79.48 🥇

## Usage
This skill provides access to Darwin-180B-RSI's reasoning capabilities that can be used to:
- Solve complex mathematical problems (AIME, HMMT level)
- Answer graduate-level science questions (GPQA Diamond)
- Perform complex reasoning over long documents (262K context)
- Enhance the uncensored 13B Generator with powerful reasoning capabilities
- Provide self-improving capabilities over time

## Integration
Activates automatically via Hermes' pre_llm_call hook when reasoning tasks are detected. Can also be invoked directly via `hermes darwin-180b-rsi <prompt>`.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  darwin-180b-rsi: true
```

## NVIDIA NIM Usage
When using NVIDIA NIM inference, ensure you have access to the Darwin-180B-RSI model via the NVIDIA API endpoint.