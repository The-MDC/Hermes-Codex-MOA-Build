---
name: jevify-q6k-gguf-second-support
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

# jevify-Q6_K_GGUF (Second Support Expert) Skill

## Description
6-bit quantized model (~16 GB VRAM) serving as the second support expert in MOA1 tier1 mixture-of-experts architecture, providing parallel multimodal/coding lane expert. Designed to operate in parallel with the first support expert, creating a dual-expert support system for concurrent multimodal and coding tasks.

## Why This Skill is Valuable
- Provides dual-expert support system parallelism in MOA1 architecture
- Second 6-bit quantized expert (~16 GB VRAM) for concurrent processing
- Creates parallel multimodal/coding lane expert alongside first support expert
- Enables true two-expert support parallelism for MOA1 architecture
- Complements the first jevify-Q6_K_GGUF expert for balanced multimodal/coding workload distribution

## Key Features
- 6-bit Q6_K quantization (identical to first support expert)
- ~16 GB VRAM requirement (matches first expert)
- Second support expert in tier1 MoE architecture
- Parallel multimodal/coding lane expert
- Workload distribution across dual support experts
- MOA1 tier1 mixture-of-experts architecture compatible

## Usage
This skill provides access to the second jevify-Q6_K_GGUF expert's capabilities that can be used to:
- Operate in parallel with the first support expert (jevify-q6k-gguf-multimodal-coding)
- Handle additional multimodal/coding workloads concurrently
- Distribute tasks across dual support experts for balanced processing
- Provide redundant support capability if one expert is busy
- Enable true two-expert parallelism for MOA1 architecture workloads

## Integration
Activates automatically via Hermes' pre_llm_call hook when additional multimodal/coding support is needed beyond the first expert. Can also be invoked directly via `hermes jevify-q6k-second-support <prompt>`.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  jevify-q6k-gguf-second-support: true
```