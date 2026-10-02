---
name: kyuz0-amd-strix-halo-toolboxes
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

# kyuz0-amd-strix-halo-toolboxes Skill

## Description
AMD Strix Halo Llama.cpp Toolboxes repository, part of the Strix Halo AI Toolboxes project. Provides toolboxes and guidance for running Llama.cpp on AMD Strix Halo hardware with unified-memory allocation and OS-specific configuration.

## Why This Skill is Valuable
- Provides optimized Llama.cpp builds for AMD Strix Halo
- Includes unified-memory allocation guidance
- Offers OS-specific configuration for maximum performance
- Part of the larger Strix Halo AI Toolboxes ecosystem

## Key Features
- Llama.cpp toolboxes for AMD Strix Halo
- Unified-memory allocation setup
- OS-specific configuration guides
- Performance optimization for local LLM inference
- Integration with Strix Halo AI Toolboxes

## Usage
This skill provides access to AMD Strix Halo Llama.cpp toolboxes that can be used to:
- Optimize Llama.cpp for AMD Strix Halo hardware
- Configure unified-memory allocation
- Set up OS-specific parameters for maximum performance
- Leverage the Strix Halo AI Toolboxes ecosystem

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  kyuz0-amd-strix-halo-toolboxes: true
```