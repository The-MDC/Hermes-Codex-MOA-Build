---
name: headroom-labs-ai-headroom
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


# headroom-labs-ai/headroom Integration for Hermes Agent

## Overview
This skill integrates the **headroom-labs-ai/headroom** context compression system into Hermes Agent, reducing token consumption by 20-60% for coding agents and 60-95% for JSON outputs, with identical answers.

## Why headroom?
- **20% fewer tokens** for coding agent outputs
- **60-95% fewer tokens** for JSON outputs
- **Lossless compression** — same answers
- **Library, proxy, or MCP server** deployment options
- Runs locally — no data leaves your machine

## Installation

```bash
# Using pip (Python)
pip install headroom-compress

# Or using the CLI
pip install headroom[all]

# Verify installation
headroom --version

# Or manual Python import
from headroom import compress
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  headroom-labs-ai-headroom: true

# Environment variables for mode selection
export HEADROOM_DEFAULT_MODE=compress  # compress | retrieve | stats
export HEADROOM_CACHE_DIR="$HOME/.hermes/cache/headroom"
```

## Usage

### Automatic Compression
Hermes automatically compresses all outputs on every `pre_llm_call` hook. No manual intervention needed.

### Manual Compression
```python
from hermes_tools import headroom_compress

# Compress messages before sending to LLM
compressed = headroom_compress(messages)
# or via CLI
headroom compress --messages file.json
```

### Compression Modes
| Mode | Description |
|------|-------------|
| `compress` | Standard compression (default) |
| `retrieve` | Retrieve original from cache |
| `stats` | Show compression statistics |

### Benefits
- **Immediate token reduction** — 20-60% for coding, 60-95% for JSON
- **Zero configuration** — works out of the box
- **Lossless** — identical answers after decompression
- **Cross-agent** — shared cache across Claude, Codex, Gemini, Grok

## Verification

```bash
# Check Hermes recognizes headroom
hermes doctor

# View compression stats
headroom stats --dir ~/.hermes/cache/headroom

# Test compression
echo '[{"role":"user","content":"Hello world"}]' | headroom compress
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| headroom not found | Ensure PATH includes headroom binary |
| No compression | Check `HEADROOM_DEFAULT_MODE` env variable |
| Cache corruption | Delete `~/.hermes/cache/headroom` and restart |
| Incompatible Python version | Requires Python 3.8+ |

## References
- Original repo: https://github.com/headroomlabs-ai/headroom
- Docs: https://headroomlabs.ai/docs
- License: Apache-2.0
- PyPI: https://pypi.org/project/headroom-compress/