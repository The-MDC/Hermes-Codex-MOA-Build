---
name: hogeheer499-strix-halo-guide
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

# hogeheer499-strix-halo-guide Skill

## Description
AMD Strix Halo local LLM guide providing reproducible setup instructions, benchmarks, and raw evidence for running large language models (like Qwen3-Coder 30B) on AMD Strix Halo / Ryzen AI MAX+ 395 systems with Radeon 8060S graphics.

## Why This Skill is Valuable
- Provides optimized local LLM setup for specific hardware
- Includes benchmarks and performance data
- Offers guidance for Vulkan/RADV setup with Ollama and llama.cpp
- Enables high-throughput local LLM inference (e.g., 98.5 t/s for Qwen3-30B-A3B-Instruct)

## Key Features
- Copyable Ubuntu + Vulkan/RADV setup
- Practical model/backend recommendations
- Direct benchmark results (Qwen3-Coder 30B at 98.5 t/s)
- MTP speculative decoding guidance
- Community feedback and results

## Usage
This skill provides access to AMD Strix Halo LLM optimization knowledge that can be used to:
- Configure local LLM environments for maximum performance
- Benchmark and validate LLM inference speeds
- Set up speculative decoding for improved throughput
- Troubleshoot and optimize local AI workloads

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  hogeheer499-strix-halo-guide: true
```