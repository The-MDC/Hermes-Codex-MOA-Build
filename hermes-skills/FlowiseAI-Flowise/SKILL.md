---
name: FlowiseAI-Flowise
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

# FlowiseAI-Flowise Skill

## Description
Flowise is an open-source low-code tool for creating LLM orchestration flows and AI agents via a drag-and-drop interface. It allows you to build AI agents visually without writing code.

## Why This Skill is Valuable
- Provides a visual interface for building AI agents and LLM flows
- Supports various LLM providers (OpenAI, Anthropic, Ollama, etc.)
- Includes pre-built nodes for common tasks (LLM, prompt, memory, tools, etc.)
- Can be extended with custom nodes
- Offers Docker deployment for easy setup
- Provides REST API for programmatic access
- Includes chat UI for testing agents

## Key Features
- Drag-and-drop interface for building agent flows
- Support for multiple LLM providers and embeddings
- Pre-built nodes for LLMs, prompts, memory, tools, agents, etc.
- Custom node development capability
- Docker and docker-compose deployment options
- REST API for agent execution and management
- Built-in chat UI for testing and debugging
- Export/import flows as JSON
- Extensible with custom integrations

## Usage
This skill provides access to Flowise's capabilities that can be used to:
- Build and deploy AI agents visually
- Create LLM orchestration flows for complex tasks
- Integrate with external tools and APIs
- Test and debug agent interactions
- Deploy agents via Docker or directly
- Access agents via REST API for programmatic control

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  FlowiseAI-Flowise: true
```