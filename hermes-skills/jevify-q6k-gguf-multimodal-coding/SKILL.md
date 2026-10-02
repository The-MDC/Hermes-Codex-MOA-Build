---
name: jevify-q6k-gguf-multimodal-coding
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

# jevify-Q6_K_GGUF (Multimodal/Coding Support) Skill

## Description
6-bit quantized model (~16 GB VRAM) providing multimodal/coding support for CodeLlama & Qwythos, serving as the first support expert in MOA1 tier1 mixture-of-experts architecture. Designed to parallelize multimodal and coding tasks alongside the primary generator.

## Why This Skill is Valuable
- Provides dedicated multimodal coding support parallel to primary generation
- 6-bit quantization balances quality and VRAM efficiency (~16 GB)
- Specialized for CodeLlama and Qwythos architecture compatibility
- Enables true Mixture-of-Experts parallelism in MOA1 architecture
- Supports concurrent multimodal and code generation tasks

## Key Features
- 6-bit Q6_K quantization
- ~16 GB VRAM requirement
- Multimodal capability (text + images/codes)
- Coding support for Common programming languages
- Parallel execution with primary generator
- MOA1 tier1 mixture-of-experts architecture compatible

## Usage
This skill provides access to jevify-Q6_K_GGUF's capabilities that can be used to:
- Support multimodal tasks (image description, code analysis) while primary model generates
- Handle code generation and analysis tasks in parallel with text generation
- Provide specialized reasoning for coding-related prompts
- Offload multimodal processing from primary 13B/180B generator
- Enable true Mixture-of-Experts parallelism in MOA1 workflow

## Integration
Activates automatically via Hermes' pre_llm_call hook when multimodal/coding tasks are detected. Can also be invoked directly via `hermes jevify-q6k-multimodal <prompt>`.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  jevify-q6k-gguf-multimodal-coding: true
```