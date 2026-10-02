---
name: ecc-agent-harness
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

# ecc-agent-harness Skill

## Description
ECC (Agent Harness) is a performance optimization system for AI agents. It provides skills, instincts, memory, security, and research-first development for Claude Code, Codex, Opencode, Cursor and beyond. It includes 68 agents, hooks, memory, runtime controls, rules, and commands.

## Why This Skill is Valuable
- Provides a comprehensive agent optimization system
- Includes 68 specialized agents for various tasks
- Offers hooks and memory for continuous learning
- Implements security and research-first practices
- Compatible with multiple agent frameworks (Claude Code, Codex, etc.)

## Key Features
- 68 agents covering planning, review, build, repair, security, architecture, and domain work
- Hooks and memory for enforcement, session summaries, continuous learning, instincts, and context controls
- Selective rules for always-loaded standards by language or project
- Commands for implementation planning, code review, etc.
- Skills for various domains (e.g., coding standards, testing, documentation, security)
- Platform support for Zed, VS Code, Cursor, etc.
- Security features including mandatory checks

## Usage
This skill provides access to ECC's agent harness capabilities that can be used to:
- Optimize Hermes agent performance
- Integrate specialized agents for specific tasks
- Implement hooks and memory for continuous improvement
- Apply coding standards and best practices
- Use ECC's command and skill system within Hermes

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  ecc-agent-harness: true
```