---
name: darwin-35b-a3b-mythos
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

# darwin-35b-a3b-mythos Skill

## Description
Darwin-35B-A3B-Mythos is a measured Qwen3.6-35B-A3B reasoning derivative — frontier-class quality with published benchmarks, Korean capability, and a real on-device story.

## Why This Skill is Valuable
- Provides efficient secondary generation with ~3B active parameters (A3B sparse MoE)
- Strong reasoning performance: GPQA Diamond 86.4 (maj@8), 70.7 (greedy)
- Korean-capable (unique in current trending set)
- Apache-2.0 licensed, reproducible, honestly benchmarked
- On-device decode: 20.0 tok/s on RTX 5060 Laptop 8GB
- 3.7× faster than dense 32B on same laptop
- Datacenter throughput: 18,057 tok/s aggregate on 1× B200
- Text-only in v1 (vision tower coming in roadmap)

## Key Features
- 34.7B total / ~3B active (A3B sparse MoE)
- GPQA Diamond: 86.4 (maj@8), 70.7 (greedy)
- Korean-capable
- Apache-2.0 license
- On-device performance: 20 tok/s on RTX 5060 8GB
- 3.7× speedup over dense 32B on same hardware
- Datacenter throughput: 18,057 tok/s on 1× B200
- Text-only (v1)

## Usage
This skill provides access to Darwin-35B-A3B-Mythos' capabilities that can be used to:
- Handle complex secondary generation tasks efficiently
- Provide Korean language support
- Serve as a high-performance, locally viable alternative to larger models
- Complement the uncensored 13B Generator and Darwin-180B-RSI in a MOA architecture
- Run on consumer hardware for on-device AI applications

## Integration
Activates automatically via Hermes' pre_llm_call hook when appropriate. Can also be invoked directly via `hermes darwin-35bam <prompt>`.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  darwin-35b-a3b-mythos: true
```