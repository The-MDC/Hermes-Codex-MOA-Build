---
name: trycua-cua
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


# trycua/cua Integration for Hermes Agent

## Overview
This skill integrates the **trycua/cua** Computer Use 2.0 framework into Hermes Agent, enabling computer use capabilities including desktop automation, isolated cloud desktops, local macOS VMs, and specialist decision models.

## Why cua?
- **Open-source desktop automation** — full control without vendor lock-in
- **Cross-OS fleets** — macOS, Windows, Linux sandboxes
- **Benchmarks for evaluation** — CUA-S1 for specialized decisions
- **Computer Use 2.0** — moves between code, APIs, and graphical interfaces
- **Compatible with major agents** — Claude Code, Codex, Cursor, OpenClaw

## Installation

```bash
# Using the Sandbox SDK
pip install cua-driver

# Or full CUA installation
pip install cua

# Verify installation
cua --version

# Or via Docker
docker pull cua-ai/cua:latest

# For specific platforms
# macOS: brew install cua
# Linux: Download from releases
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  trycua-cua: true

# Environment variables
export CUDA_VISIBLE_DEVICES=""  # if using CPU-only
export CUA_DEFAULT_ENV=macos  # macos | windows | linux
export CUA_FLEET_CREDENTIALS="$HOME/.cua/credentials.json"
```

## Usage

### Basic Computer Use
```python
from hermes_tools import cua_driver

# Connect agent to desktop
driver = cua_driver.connect()

# Execute commands
result = driver.execute("ls -la")
result = driver.execute("open -a Calculator")

# Capture screenshots
screenshot = driver.screenshot()

# Disconnect
driver.disconnect()
```

### Cua Fleets
```bash
# Provision a desktop from a pool
cua fleet claim

# Run a command
cua fleet run "uname -a"

# Save a screenshot
cua fleet screenshot

# Delete resources
cua fleet release
```

### Cua-S1 Models
```bash
# Use specialized decision models
cua perception forms --score "which value belongs in this field"
```

### Benefits
- **Full desktop automation** for Hermes agent
- **Cross-platform** — macOS, Windows, Linux
- **Isolated cloud desktops** — no local resource usage
- **Specialized models** — Cua-S1 for form decisions
- **Benchmark suite** — evaluate agent performance

## Verification

```bash
# Check Hermes recognizes cua
hermes doctor

# Test basic computer use
hermes ask "Open Calculator and compute 6x7"

# Verify fleet provisioning
cua fleet status

# Test Cua-S1 forms
cua perception forms --help
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| cua not found | Ensure PATH includes cua binary |
| Platform not supported | Check `CUA_DEFAULT_ENV` setting |
| Fleet provisioning fails | Verify credentials in `~/.cua/credentials.json` |
| Screen capture fails | Check display/X server permissions |
| Model loading errors | Ensure compatible GPU drivers |

## References
- Original repo: https://github.com/trycua/cua
- Docs: https://cua.ai/docs
- License: MIT
- Cua-S1: https://github.com/trycua/cua/blob/main/libs/cua-s1
- Sandbox SDK: https://cua.ai/docs/reference/sandbox-sdk