---
name: codecrafters-build-your-own
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


# codecrafters-io/build-your-own-x Integration for Hermes Agent

## Overview
This skill integrates **codecrafters-io/build-your-own-x** into Hermes Agent, providing step-by-step guides for recreating technologies from scratch, enabling deep understanding through hands-on implementation.

## Why Build Your Own X?
- **Deep understanding** — "What I cannot create, I do not understand" (Feynman)
- **Step-by-step guides** — Comprehensive tutorials for complex systems
- **Technology breadth** — 3D renderer, AI model, blockchain, OS, databases, etc.
- **Language diversity** — Guides in Python, C++, Java, JavaScript, C#, Go, Rust, etc.
- **Production quality** — Real implementations, not toy examples

## What's Included
- **3D Renderer** — Ray tracing, OpenGL, Wolfenstein 3D engine
- **AI Model** — LLMs, Diffusion Models, RAG for document search
- **Augmented Reality** — Vuforia, Unity, ARKit, ARCore tutorials
- **Blockchain/Cryptocurrency** — From-scratch implementations
- **Bot** — IRC bots, Twitter bots, chatbots
- **Command-Line Tool** — Git clones, shell implementations
- **Database** — SQL, NoSQL, Redis, Kafka-like systems
- **Docker** — Container runtime from scratch
- **Emulator/VM** — CPU, Game Boy, NES emulators
- **Front-end Framework** — React, Vue, vanilla JS frameworks
- **Game** — 2D/3D games, physics engines
- **Git** — Version control system implementation
- **Memory Allocator** — malloc/free implementations
- **Network Stack** — TCP/IP, HTTP, WebSocket implementations
- **Neural Network** — From-scratch ML implementations
- **Operating System** — Simple OS kernels, schedulers
- **Physics Engine** — Rigid body, collision detection
- **Processor** — CPU architecture, instruction sets
- **Regex Engine** — Regular expression implementations
- **Search Engine** — Full-text search, indexing, ranking
- **Shell** — Unix shell implementations
- **Template Engine** — Jinja2, Handlebars, EJS clones
- **Text Editor** — Vim, VS Code, nano implementations
- **Visual Recognition** — Object detection, facial recognition
- **Voxel Engine** — Minecraft-like voxel rendering
- **Web Browser** — HTML/CSS/JS rendering engine
- **Web Server** — HTTP servers, REST APIs

## Installation

```bash
# No installation required — it's a reference guide
# Access via: https://codecrafters.io or local clone

# Optional: Clone for offline access
git clone https://github.com/codecrafters-io/build-your-own-x.git
cd build-your-own-x

# Or use the website directly
# https://codecrafters.io
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  codecrafters-build-your-own: true

# Environment variables
export BUILD_YOUR_OWN_X_PATH="$HOME/.hermes/resources/build-your-own-x"  # if cloned locally
export BUILD_YOUR_OWN_X_DEFAULT_LANG="python"  # python | cpp | java | js | go | rust
export BUILD_YOUR_OWN_X_CACHE_DIR="$HOME/.hermes/cache/build-your-own-x"
```

## Usage

### Learning a Technology

```python
from hermes_tools import buildyourown

# Get tutorial for a technology
tutorial = buildyourown.get_tutorial(
    technology="database",
    language="python",
    difficulty="intermediate"
)

# Or via CLI
build-your-own-x database --language python

# Get step-by-step guidance
buildyourown.start_tutorial(
    technology="http-server",
    language="rust",
    current_step=3  # Resume from step 3
)

# Generate code from tutorial
buildyourown.generate_code(
    technology="blockchain",
    language="go",
    target_dir="$HOME/projects/my-blockchain"
)
```

### Hermes Agent Commands

```bash
# Start learning a technology
hermes build-you-own-x learn --technology "ai-model" --language "python"

# Get current step help
hermes build-you-own-x help --technology "database" --step 5

# Generate implementation
hermes build-you-own-x build --technology "web-server" --language "nodejs" --output "./my-server"

# List available technologies
hermes build-you-own-x list

# Search tutorials
hermes build-you-own-x search "real-time" --language "cpp"
```

### Example Workflows

#### Build Your Own Database
```bash
hermes build-you-own-x learn --technology "database" --language "python"
# Follows tutorial: B+Tree, indexing, query parser, transaction manager, etc.

hermes build-you-own-x build --technology "database" --language "python" --output "./my-db"
```

#### Build Your Own AI Model
```bash
hermes build-you-own-x learn --technology "ai-model" --language "python"
# Covers: transformer architecture, attention mechanism, training loop

hermes build-you-own-x build --technology "ai-model" --language "python" --output "./my-llm"
```

#### Build Your Own Web Server
```bash
hermes build-you-own-x learn --technology "http-server" --language "rust"
# Implements: socket handling, HTTP parsing, routing, middleware

hermes build-you-own-x build --technology "http-server" --language "rust" --output "./my-http-server"
```

## Benefits
- **Deep technical understanding** through implementation
- **Structured learning path** — beginner to advanced
- **Language-agnostic** — learn concepts in your preferred language
- **Production-ready patterns** — industry-standard implementations
- **Agent-enhanced learning** — Hermes guides you through each step
- **Cross-pollination** — concepts transfer between technologies

## Verification

```bash
# Check Hermes recognizes the skill
hermes doctor

# Test tutorial access
hermes build-you-own-x list | head -20

# Get specific tutorial
hermes build-you-own-x learn --technology "git" --language "bash"

# Verify code generation
hermes build-you-own-x build --technology "shell" --language "bash" --output "./test.sh"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Tutorial not found | Check spelling or use `list` command |
| Language not supported | Check available languages for that technology |
| Code generation fails | Ensure target directory is writable |
| Missing dependencies | Tutorial will list required tools/libraries |
| Complex tutorial overwhelming | Use `help` command for current step guidance |

## References
- Original repo: https://github.com/codecrafters-io/build-your-own-x
- Website: https://codecrafters.io
- License: MIT
- Tutorial count: 20+ technologies with multiple language variants
- Difficulty levels: Beginner, Intermediate, Advanced