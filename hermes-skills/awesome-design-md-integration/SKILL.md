---
name: awesome-design-md-integration
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


# VoltAgent/awesome-design-md Integration for Hermes Agent

## Overview
This skill integrates **VoltAgent/awesome-design-md** into Hermes Agent, providing access to curated DESIGN.md files from popular brand design systems. Drop a DESIGN.md into your project and tell your AI agent to generate a matching UI.

## Why Awesome DESIGN.md?
- **Curated collection** — DESIGN.md files extracted from real websites
- **Instant UI generation** — AI agents read DESIGN.md to generate consistent UI
- **Design depth** — Includes analyzed patterns, tokens, and rules (not surface-level)
- **Markdown format** — LLMs read markdown best, no parsing/configuration needed
- **Brand consistency** — Generate UI that matches real design systems

## What is DESIGN.md?
DESIGN.md is a plain-text design system document introduced by Google Stitch that AI agents read to generate consistent UI. It includes:
1. **Visual Theme & Atmosphere** — Mood, density, design philosophy
2. **Color Palette & Roles** — Semantic name + hex + functional role
3. **Typography Rules** — Font families, full hierarchy table
4. **Layout Principles** — Spacing scale, grid, whitespace philosophy
5. **Depth & Elevation** — Shadow system, surface hierarchy
6. **Do's and Don'ts** — Design guardrails and anti-patterns
7. **Responsive Behavior** — Breakpoints, touch targets, collapsing strategy
8. **Agent Prompt Guide** — Quick color reference, ready-to-use prompts

Each site also includes:
- `preview.html` — Visual catalog showing color swatches, type scale, buttons, cards
- `preview-dark.html` — Same catalog with dark surfaces

## Installation

```bash
# Clone for local access (recommended for Hermes)
git clone https://github.com/VoltAgent/awesome-design-md.git
cd awesome-design-md

# Or access via GitHub directly
# https://github.com/VoltAgent/awesome-design-md

# Verify installation
ls -la  # Should see README.md, DESIGN.md files in subdirectories
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  awesome-design-md-integration: true

# Environment variables
export AWESOME_DESIGN_MD_PATH="$HOME/.hermes/resources/awesome-design-md"  # if cloned locally
export AWESOME_DESIGN_MD_CACHE_DIR="$HOME/.hermes/cache/awesome-design-md"
export AWESOME_DESIGN_MD_DEFAULT_CATEGORY="ai-llm-platforms"  # ai-llm-platforms | backend | frontend
```

## Usage

### Using DESIGN.md Files

```python
from hermes_tools import awesomedesignmd

# List available DESIGN.md collections
collections = awesomedesignmd.list_collections()

# Get DESIGN.md for a specific brand
design_content = awesomedesignmd.get_design(
    brand="voltagent",  # or together.ai, hashicorp, mongodb, etc.
    category="ai-llm-platforms"
)

# Or via CLI
awesome-design-md list
awesome-design-md get --brand voltagent --category ai-llm-platforms

# Generate UI from DESIGN.md
ui_code = awesomedesignmd.generate_ui(
    design_content=design_content,
    description="Create a dashboard with dark mode",
    framework="react"
)
```

### Hermes Agent Commands

```bash
# List available categories
hermes awesome-design-md list-categories

# List brands in a category
hermes awesome-design-md list --category ai-llm-platforms

# Get DESIGN.md for VoltAgent
hermes awesome-design-md get --brand voltagent --category ai-llm-platforms

# Generate UI using the DESIGN.md
hermes awesome-design-md generate \
  --brand voltagent \
  --description "Create a chat interface with message history" \
  --framework react

# Get preview information
hermes awesome-design-md preview --brand voltagent

# Get dark mode preview
hermes awesome-design-md preview-dark --brand voltagent
```

### Example Workflows

#### Generate VoltAgent-Styled UI
```bash
# Get the VoltAgent DESIGN.md
hermes awesome-design-md get --brand voltagent --category ai-llm-platforms

# Generate a chat interface
hermes awesome-design-md generate \
  --brand voltagent \
  --description "Create a real-time chat application with message history, user lists, and typing indicators" \
  --framework react \
  --output ./chat-app
```

#### Generate HashiCorp-Styled Infrastructure Tool
```bash
# Get HashiCorp DESIGN.md
hermes awesome-design-md get --brand hashicorp --category backend

# Generate Terraform UI
hermes awesome-design-md generate \
  --brand hashicorp \
  --description "Create a Terraform module selector with variable validation" \
  --framework vue \
  --output ./terraform-ui
```

#### Generate MongoDB-Styled Admin Panel
```bash
# Get MongoDB DESIGN.md
hermes awesome-design-md get --brand mongodb --category backend

# Generate admin panel
hermes awesome-design-md generate \
  --brand mongodb \
  --description "Create a database admin panel for collections, queries, and performance monitoring" \
  --framework svelte \
  --output ./mongodb-admin
```

## Benefits
- **Instant design consistency** — UI matches real brand design systems
- **No design expertise needed** — AI handles the design implementation
- **Production-ready patterns** — Based on real websites and applications
- **Framework agnostic** — Works with React, Vue, Svelte, HTML/CSS/JS, etc.
- **Dark mode support** — Includes dark variant previews
- **Component libraries** — Ready-to-use buttons, forms, navigation, etc.
- **Responsive design** — Built-in breakpoints and touch targets

## Verification

```bash
# Check Hermes recognizes the skill
hermes doctor

# Test category listing
hermes awesome-design-md list-categories

# Test brand listing
hermes awesome-design-md list --category ai-llm-platforms

# Test DESIGN.md retrieval
hermes awesome-design-md get --brand voltagent --category ai-llm-platforms

# Test UI generation
hermes awesome-design-md generate --brand voltagent --description "simple button" --framework html
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Brand not found | Check spelling or use `list` to see available brands |
| Category not recognized | Use `list-categories` to see valid options |
| DESIGN.md not loading | Verify file path and read permissions |
| UI generation fails | Check description clarity and framework support |
| Missing preview files | Some brands may not have preview.html files |
| Framework not supported | Try vanilla HTML/CSS/JS or report missing framework |

## References
- Original repo: https://github.com/VoltAgent/awesome-design-md
- DESIGN.md specification: https://stitch.withgoogle.com/docs/design-md/
- License: MIT
- Collection sources: Together AI, VoltAgent, HashiCorp, MongoDB, and more
- File types: DESIGN.md, preview.html, preview-dark.html
- Usage: Copy DESIGN.md to project, tell AI agent to use it