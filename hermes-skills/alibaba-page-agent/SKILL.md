---
name: alibaba-page-agent
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

# alibaba-page-agent Skill

## Description
JavaScript in-page GUI agent. Control web interfaces with natural language. One script gives any web page its own AI agent.

## Why This Skill is Valuable
- Provides in-page AI agent capabilities without browser extensions
- Enables natural language control of web interfaces
- Works with most mainstream LLMs including locally deployed ones
- Optional Chrome extension for multi-page tasks
- MCP Server (Beta) for external control

## Key Features
- Easy integration with just one script
- Text-based DOM manipulation (no screenshots needed)
- Bring your own LLMs support
- Optional Chrome extension for multi-page agent capabilities
- MCP Server for external agent control
- SaaS AI copilot integration in minimal code
- Smart form filling (turn 20-click workflows into one sentence)
- Accessibility through natural language (voice commands, screen readers)

## Usage
This skill provides access to Page Agent capabilities that can be used to:
- Create AI agents that live in web pages
- Control web interfaces with natural language
- Build smart form filling automation
- Enhance web app accessibility
- Create multi-page agents across browser tabs
- Integrate AI copilots into SaaS products
- Control agents externally via MCP

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  alibaba-page-agent: true
```