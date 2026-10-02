---
name: tt-a1i-archify
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

# tt-a1i-archify Skill

## Description
Archify is an agent skill for Cursor, Claude Code, Codex CLI, and OpenCode. Give it a system description or repository; get an interactive, shareable technical map.
It produces self-contained HTML diagrams with motion and crisp export for architecture, workflow, sequence, data-flow, and lifecycle diagrams.

## Why This Skill is Valuable
- Generates beautiful, verifiable diagrams from system descriptions
- Produces self-contained HTML with motion and export options (PNG, SVG, WebM)
- Supports five technical diagram types: architecture, workflow, sequence, data-flow, lifecycle
- Offers four visual presets, dark/light themes, and optional finite motion
- Enables reviewing architecture changes before merge (Before/Delta/After comparison)
- Every interaction stays grounded with source tracing and guided stories
- One file, ready to trust and share: typed JSON IR and deterministic checks

## Key Features
- Five diagram types: architecture, workflow, sequence, data-flow, lifecycle
- Four visual presets with dark/light themes
- Optional finite motion in diagrams
- Before/Delta/After comparison for architecture changes
- Grounded interactions: search nodes, open revision-verified source, trace upstream/downstream
- Guided stories without inventing topology
- Self-contained HTML output with export to PNG, SVG, WebM, and share cards
- Deterministic checks and typed JSON IR for reliability

## Usage
This skill provides access to Archify's diagram generation capabilities that can be used to:
- Create architecture diagrams from codebase or system description
- Generate workflow and sequence diagrams
- Produce data-flow and lifecycle diagrams
- Review architecture changes before merging
- Generate shareable technical maps for documentation
- Export diagrams in multiple formats (HTML, PNG, SVG, WebM)

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  tt-a1i-archify: true
```