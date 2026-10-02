---
name: nemotron-safety-content-moderation
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

# nemotron-safety-content-moderation Skill

## Description
Nemotron 3.5 Content Safety is a compact 4B vision-language content-safety moderator designed for determining whether inputs (prompt and optionally an image) and responses are safe or unsafe.

## Why This Skill is Valuable
- Provides dedicated safety/gurading capability for the MOA architecture
- Multimodal (text + image) safety classification
- Supports 12 explicitly trained languages
- Accepts custom policies at inference time
- Designed specifically for content moderation and safety tasks
- Can classify both user prompts and assistant responses
- Includes optional reasoning traces for transparency
- Built-in taxonomy for safety categories

## Key Features
- 4B vision-language model
- Multimodal safety classification (text and image)
- 12 explicitly trained languages
- Custom policy support at inference time
- Classifies prompts and responses
- Optional reasoning traces
- Built-in safety taxonomy
- Available via NVIDIA NIM

## Usage
This skill provides access to Nemotron 3.5 Content Safety's capabilities that can be used to:
- Validate outputs from the uncensored 13B Generator and Darwin models for safety
- Classify user prompts for harmful content before processing
- Moderate agent-generated content in real-time
- Implement custom safety policies for specific use cases
- Provide safety guarding in the MOA1: Hermes-MOA-Build architecture

## Integration
Activates automatically via Hermes' pre_llm_call hook when safety checking is needed. Can also be invoked directly via `hermes nemotron-safety <prompt>` or with image inputs.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  nemotron-safety-content-moderation: true
```

## NVIDIA NIM Usage
When using NVIDIA NIM inference, ensure you have access to the Nemotron 3.5 Content Safety model via the NVIDIA API endpoint.