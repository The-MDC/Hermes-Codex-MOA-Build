---
name: goose-agent
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

# goose-agent Skill

## Description
goose is a general-purpose AI agent that runs on your machine. Not just for code — use it for research, writing, automation, data analysis, or anything you need to get done.
A native desktop app for macOS, Linux, and Windows. A full CLI for terminal workflows. An API to embed it anywhere. Built in Rust for performance and portability.

## Why This Skill is Valuable
- Provides a ready-to-use AI agent framework
- Supports 15+ LLM providers via ACP
- Extensible via MCP (Model Context Protocol)
- Cross-platform (macOS, Linux, Windows)
- Production-grade and battle-tested

## Key Features
- Desktop app, CLI, and API
- Works with Anthropic, OpenAI, Google, Ollama, OpenRouter, Azure, Bedrock, and more
- Connect to 70+ extensions via MCP
- Part of the Agentic AI Foundation (AAIF) at the Linux Foundation
- Built in Rust for performance and portability

## Usage
This skill provides access to goose agent capabilities that can be used to:
- Extend Hermes agent with goose capabilities
- Use goose as a subagent or tool within Hermes
- Leverage goose's MCP server for tool integration
- Install and configure goose for local AI agent workflows

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  goose-agent: true
```