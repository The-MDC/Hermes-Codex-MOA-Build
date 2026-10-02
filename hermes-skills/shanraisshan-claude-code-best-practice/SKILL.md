---
name: shanraisshan-claude-code-best-practice
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

# shanraisshan-claude-code-best-practice Skill

## Description
Best practices and patterns for Claude Code agent engineering, including subagents, commands, skills, workflows, hooks, MCP servers, and orchestration patterns. This skill provides patterns for building agentic systems with Claude Code.

## Why This Skill is Valuable
- Provides proven patterns for agent engineering
- Includes subagent and command patterns
- Offers workflow orchestration techniques
- Integrates with MCP servers and hooks
- Enhances Claude Code capabilities for Hermes agents

## Key Features
- Subagent patterns (.claude/agents/)
- Command patterns (.claude/commands/)
- Skill patterns (.claude/skills/)
- Workflow orchestration examples
- Hook and MCP server integration
- Settings and memory management patterns
- Development workflow templates

## Usage
This skill provides access to Claude Code best practices that can be applied to Hermes agent development:
- Implement subagent patterns for task delegation
- Use command patterns for CLI interfaces
- Apply skill patterns for reusable capabilities
- Orchestrate workflows using provided patterns
- Integrate with MCP servers for extended capabilities
- Configure hooks for automated workflows

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  shanraisshan-claude-code-best-practice: true
```