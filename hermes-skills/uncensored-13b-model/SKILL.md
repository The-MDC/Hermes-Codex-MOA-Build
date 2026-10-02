---
name: uncensored-13b-model
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

# uncensored-13b-model Skill

## Description
An uncensored 13B parameter language model serving as the base generator in the MOA1 (Mixture of Agents) architecture. This model provides high-quality text generation capabilities while minimizing excessive censorship that might hinder useful outputs.

## Why This Skill is Valuable
- Serves as the foundational generation model in the MOA1 architecture
- 13B parameter scale offers strong capabilities without excessive resource demands
- "Uncensored" design allows for broader exploration of topics while still maintaining safety through the guard model
- Can be efficiently combined with more powerful reasoning models (like Darwin-180B-RSI) in a Mixture of Agents setup
- Provides a balance between capability and deployment feasibility

## Key Features
- 13B parameter count
- Designed for text generation tasks
- Compatible with MOA architecture patterns
- Can be quantized for efficient deployment (GGUF, etc.)
- Serves as the primary text generation backbone

## Usage
This skill provides access to the uncensored 13B model's capabilities that can be used to:
- Generate high-quality text outputs as the base layer in MOA1
- Serve as the generator that is enhanced by the powerful MOE (Darwin-180B-RSI)
- Work in tandem with the secondary generator (Darwin-35B-A3B-Mythos)
- Have its outputs validated by the guard model (Nemotron 3.5 Content Safety)
- Handle general purpose text generation tasks efficiently

## Integration
Activates automatically via Hermes' pre_llm_call hook when text generation is needed. Can also be invoked directly via `hermes uncensored-13b <prompt>`.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  uncensored-13b-model: true
```

## Model Selection Notes
When implementing this skill, select an appropriate uncensored 13B model such as:
- Based on Llama 2, Mistral, or similar architectures
- Ensure it has been properly uncensored while maintaining basic safety
- Consider quantized versions (Q4_K_M, Q5_K_M, etc.) for efficient deployment
- Verify compatibility with your chosen inference backend (vLLM, llama.cpp, etc.)