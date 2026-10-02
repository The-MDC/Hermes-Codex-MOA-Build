---
name: Zackriya-Solutions-meetily
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

# Zackriya-Solutions-meetily Skill

## Description
Privacy first, AI meeting assistant with 4x faster Parakeet/Whisper live transcription, speaker diarization, and Ollama summarization built on Rust. 100% local processing. no cloud required. Meetily (Meetly Ai - https://meetily.ai) is the #1 Self-hosted, Open-source Ai meeting note taker for macOS & Windows.

## Why This Skill is Valuable
- Provides AI-powered meeting assistant capabilities
- Entirely local processing (no cloud required)
- Features live transcription, speaker diarization, and AI summarization
- Privacy-focused and enterprise-ready
- Built on Rust for performance and safety

## Key Features
- 4x faster Parakeet/Whisper live transcription
- Speaker diarization
- Ollama summarization
- 100% local processing
- No cloud required
- Privacy-first design
- Open-source and self-hosted
- Available for macOS & Windows

## Usage
This skill provides access to Meetily's AI meeting assistant capabilities that can be used to:
- Capture and transcribe meetings locally
- Generate AI-powered meeting summaries
- Maintain privacy and control over meeting data
- Integrate meeting notes into knowledge workflows

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  Zackriya-Solutions-meetily: true
```