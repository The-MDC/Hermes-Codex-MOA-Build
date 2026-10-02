---
name: rtk-ai-rtk
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


# rtk-ai/rtk Integration for Hermes Agent

## Overview
This skill integrates the **rtk-ai/rtk** CLI proxy into Hermes Agent, reducing LLM token consumption by 60-90% on common development commands.

## Why rtk?
- **60-90% token savings** on commands: `ls`/`tree`, `cat`/`read`, `grep`/`rg`, `git status`, `git diff`, `git log`, `git add/commit/push`, `cargo test`/`npm test`, `ruff check`, `pytest`, `go test`, `docker ps`
- **Single Rust binary**, zero dependencies
- **<10ms overhead** per command
- Pre-built binaries available for Linux/macOS/Windows

## Installation

```bash
# Using Homebrew (recommended)
brew install rtk

# Quick Install (Linux/macOS)
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

# Cargo
cargo install --git https://github.com/rtk-ai/rtk

# Verify installation
which rtk
rtk --version
```

## Configuration

Hermes automatically detects rtk when installed. To enable integration:

```yaml
# ~/.hermes/config.yaml
plugins:
  rtk-ai-rtk: true
  
# Or via environment variable
export RTK_BIN_PATH="/usr/local/bin/rtk"  # or your installed path
```

## Usage

Hermes Agent will automatically compress command outputs before they reach the LLM context. No manual invocation needed — it activates on every `pre_llm_call` hook.

### Token Savings Example

| Command | Standard | rtk | Savings |
|---------|----------|-----|---------|
| `ls` / `tree` | 2,000 tokens | 400 tokens | -80% |
| `cat` / `read` | 40,000 tokens | 12,000 tokens | -70% |
| `git diff` | 10,000 tokens | 2,500 tokens | -75% |
| `cargo test` / `npm test` | 25,000 tokens | 2,500 tokens | -90% |

### Benefits
- **Dramatically reduced token costs** for all dev workflows
- **Faster agent responses** — less context to process
- **Same answers** — compression is lossless
- **Zero configuration** — works out of the box

## Verification

```bash
# Check Hermes recognizes rtk
hermes doctor

# Verify token savings
hermes metrics --token-reduction

# Test with a dev command
hermes ask "List files in current directory"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| rtk not found | Ensure PATH includes rtk binary |
| No token reduction | Check `RTK_BIN_PATH` env variable |
| Compression errors | Run `rtk doctor` for diagnostics |
| Binary not compatible | Download prebuilt from releases |

## References
- Original repo: https://github.com/rtk-ai/rtk
- Docs: https://rtk-ai.github.io/
- License: MIT