---
name: zeroz-lab-cc-design
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


# ZeroZ-lab/cc-design Integration for Hermes Agent

## Overview
This skill integrates the **ZeroZ-lab/cc-design** into Hermes Agent, providing high-fidelity HTML design capabilities including brand cloning, quality guardrails, design systems, design variations, and multiple export formats.

## Why cc-design?
- **Brand cloning** — Progressive loading of 68+ brand design systems from getdesign.md
- **Quality guardrails** — Always-loaded core-constraints.md layer (Iron Law + 12-item anti-slop quick-ref + delivery checklist)
- **Variations** — 3+ design directions across layout, interaction, visual intensity, and motion
- **Export formats** — PDF (multi-file + single-file), PPTX (image + editable), MP4 video, inline HTML
- **Quality guarantees** — Never builds without approved plan, Never delivers without screenshot verification
- **No AI slop patterns** — banned gradients, emoji spam, generic layouts

## Why Hermes Integration?
- Generate professional HTML/web outputs from natural language
- Brand-consistent design system generation
- Automated quality verification before delivery
- Multi-format export for different use cases
- Integrate with agent swarm for design reviews

## Installation

```bash
# Using pip (recommended)
pip install cc-design

# Or from source
git clone https://github.com/ZeroZ-lab/cc-design.git
cd cc-design
pip install -e .

# Verify installation
cc-design --version

# Or via Hermes plugin system
hermes plugins install https://github.com/ZeroZ-lab/cc-design.git --enable
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  zeroz-lab-cc-design: true

# Environment variables
export CC_DESIGN_BRANDS_PATH="$HOME/.hermes/design/brands"  # brand design systems
export CC_DESIGN_CACHE_DIR="$HOME/.hermes/cache/cc-design"
export CC_DESIGN_DEFAULT_MODE=full  # lite | full | ultra
export CC_DESIGN_EXPORT_FORMAT=html  # html | pdf | pptx | mp4 | all

# Quality guardrails configuration
export CC_DESIGN_IRON_LAW=1  # enabled | disabled
export CC_DESIGN_ANTI_SLOP=1  # enabled | disabled
```

## Usage

### Basic HTML Design Generation

```python
from hermes_tools import ccdesign

# Generate design from description
result = ccdesign.generate(
    description="SaaS dashboard with dark mode, card-based layout",
    brand="getdesign.md",  # or path to brand profile
    style="modern SaaS",
    components=["header", "sidebar", "card", "footer"]
)

# Or via CLI
cc-design "Generate a SaaS dashboard with dark mode"

# With brand cloning
result = ccdesign.with_brand(
    description="Dashboard",
    brand_profile="getdesign.md#acme-corp"
)
```

### Design System Workflow

```bash
# Initialize design system
cc-design init --project myapp

# Generate design from plan
cc-design "I am building a dashboard page. Please read design-system/myapp/MASTER.md."
cc-design "Also check if design-system/myapp/pages/dashboard.md exists."
cc-design "If the page file exists, prioritize its rules."
cc-design "If not, use the Master rules exclusively."
cc-design "Now, generate the code..."

# Generate variations
cc-design variations --count 3 --description "SaaS dashboard dark mode"

# Quality check
cc-design audit --description "SaaS dashboard"
```

### Brand Cloning

```python
# Load brand design system
brand = ccdesign.load_brand("getdesign.md")

# Progressive loading of 68+ brand design systems
for brand_system in brand.systems:
    print(f"Loaded: {brand_system.name}")

# Apply to new design
result = ccdesign.apply_brand(
    description="New product dashboard",
    brand_profile=brand
)
```

### Export Formats

```python
# Export to different formats
html_result = ccdesign.export(result, format="html")
pdf_result = ccdesign.export(result, format="pdf")
pptx_result = ccdesign.export(result, format="pptx")
mp4_result = ccdesign.export(result, format="mp4")

# Or via CLI
cc-design export --format pdf --output dashboard.pdf
cc-design export --format mp4 --output demo.mp4
```

### Quality Guardrails (Always Enforced)

| Guardrail | Description |
|-----------|-------------|
| **Iron Law** | Core constraint that never compromises |
| **12-item Anti-Slop Quick-Ref** | Banned patterns: gradients, emoji spam, generic layouts |
| **Delivery Checklist** | Mandatory screenshot verification before export |
| **Typography System** | Defined type scale, never arbitrary fonts |
| **Spacing Scale** | Consistent spacing, never random values |

## Benefits
- **Professional HTML design** for Hermes agent outputs
- **Brand-consistent** — 68+ brand design systems
- **Quality guaranteed** — guardrails prevent AI slop
- **Multiple export formats** — html, pdf, pptx, mp4
- **Variations** — 3+ design directions per request
- **No AI slop patterns** — banned elements automatically excluded

## Verification

```bash
# Check Hermes recognizes cc-design
hermes doctor

# Test design generation
hermes ask "Generate a landing page for a coffee shop"

# Test brand cloning
hermes ask "Apply Acme Corp brand to a dashboard design"

# Test quality audit
hermes ask "Audit this design for AI slop patterns"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| cc-design not found | Ensure `cc-design` is installed and in PATH |
| Brand not loading | Check `CC_DESIGN_BRANDS_PATH` setting |
| Export fails | Verify output directory permissions |
| Quality audit false positive | Review `CC_DESIGN_ANTI_SLOP` rules |
| Variations not generating | Check `CC_DESIGN_DEFAULT_MODE` setting |
| Screenshot verification fails | Ensure display/X server is available |

## References
- Original repo: https://github.com/ZeroZ-lab/cc-design
- Demo: https://cc-design-demo.vercel.app/
- Examples: https://github.com/ZeroZ-lab/cc-design/blob/master/EXAMPLES.md
- License: MIT
- Brand cloning: 68+ brands from getdesign.md
- Quality guardrails: core-constraints.md layer
- Export formats: PDF, PPTX, MP4, inline HTML