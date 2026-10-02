---
name: nextlevelbuilder-ui-ux-pro-max-skill
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


# nextlevelbuilder/ui-ux-pro-max-skill Integration for Hermes Agent

## Overview
This skill integrates the **nextlevelbuilder/ui-ux-pro-max-skill** into Hermes Agent, providing design intelligence for building professional UI/UX across multiple platforms with 192 industry-specific reasoning rules, 79 searchable styles, and design system generation capabilities.

## Why UI/UX Pro Max?
- **192 industry-specific reasoning rules** — Anti-patterns, best practices per industry
- **79 searchable styles** — backed by stable IDs and aliases
- **Cross-platform support** — 22 major frameworks (React, Vue, Tailwind, iOS, Android, etc.)
- **Design system generation** — CLI-powered MASTER.md + pages/ overrides
- **Smart recommendations** — BM25 search for highly accurate design matching
- **Color palettes and font pairings** — curated for each industry

## Installation

```bash
# Using CLI (recommended)
npm install -g ui-ux-pro-max-cli

# Go to your project
cd /path/to/your/project

# Install for your AI assistant
uipro init --ai claude      # Claude Code
uipro init --ai cursor      # Cursor
uipro init --ai windsurf    # Windsurf
uipro init --ai antigravity # Antigravity

# Or manual installation
git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git
cd ui-ux-pro-max-skill

# Install CLI
npm install -g .

# Initialize for Hermes
uipro init --ai hermes
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  nextlevelbuilder-ui-ux-pro-max-skill: true

# Environment variables
export UI_UX_PRO_MAX_DEFAULT_PROJECT="$HOME/projects/myapp"
export UI_UX_PRO_MAX_MODE=basic    # basic | premium
export UI_UX_PRO_MAX_DESIGN_SYSTEM="$HOME/.hermes/design-systems"

# BM25 search configuration
export UI_UX_PRO_MAX_BM25_TOP_K=20
```

## Usage

### Basic UI/UX Generation
```python
from hermes_tools import uipro

# Generate UI for a specific product type
result = uipro.generate(
    product_type="saas-dashboard",
    requirements="dark mode, responsive, admin panel",
    framework="react",
    style="modern"
)

# Or via CLI
uipro generate --product saas-dashboard --framework react --style modern

# Generate design system
uipro design-system --init --project myapp

# Generate page-specific overrides
uipro design-system --page dashboard --override "primary color: #ff0000"
```

### Style Search
```python
# Search for matching styles
styles = uipro.search_styles(
    product_type="banking",
    requirements="secure, minimalist, professional",
    color_palette=["#1a1a2e", "#16213e", "#f0f0f0"]
)

# Get specific style by ID
style = uipro.get_style("--tb-01")  # taxonomy-based ID
```

### Design System Commands
```bash
# Persist design system (Master + Overrides Pattern)
design-system/
└── myapp/
    ├── MASTER.md           # Global Source of Truth
    └── pages/
        └── dashboard.md    # Page-specific overrides

# How hierarchical retrieval works:
# 1. Check design-system/[project]/pages/[page-name].md first
# 2. If exists, its rules override the Master file
# 3. If not, use design-system/[project]/MASTER.md exclusively

# Generate from Master
uipro design-system --generate --project myapp

# Page-specific override
uipro design-system --page dashboard --override "primary: red"
```

### Industry-Specific Rules
The skill includes 192 industry-specific reasoning rules covering:
- **Anti-Patterns** — What NOT to do (e.g., "AI purple/pink gradients" for banking)
- **Style Taxonomy** — 79 searchable styles with stable IDs
- **Component Guidelines** — buttons, forms, navigation, chips, badges
- **Timing and Motion** — platform-specific animations
- **Accessibility** — contrast, focus states, reduced motion

## Benefits
- **Professional UI/UX** for Hermes agent outputs
- **Framework-agnostic** — works with any UI framework
- **Instant design system** — Master + overrides pattern
- **BM25-powered recommendations** — highly accurate matching
- **192 industry rules** — avoid common AI slop patterns

## Verification

```bash
# Check Hermes recognizes uipro
hermes doctor

# Test UI generation
hermes ask "Generate a dashboard UI for a SaaS application with dark mode"

# Verify design system
hermes ask "Create a design system for a fintech dashboard"

# Test style search
hermes ask "Find UI styles suitable for a banking application"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| uipro not found | Ensure PATH includes uipro CLI |
| Style search returns no results | Check `UI_UX_PRO_MAX_BM25_TOP_K` setting |
| Design system generation fails | Verify project directory exists |
| Framework not supported | Add to supported list in config |
| BM25 search slow | Reduce `BM25_TOP_K` value |

## References
- Original repo: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- UI UX Pro Max: https://uupm.cc/
- License: MIT
- Basic version: Fully open source (this repository)
- Premium version: Additional features available
- Compatible agents: Claude Code, AdaL (self-evolving AI coding agent)