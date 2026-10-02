---
name: nextlevelbuilder-goclaw
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


# nextlevelbuilder/goclaw Integration for Hermes Agent

## Overview
This skill integrates the **nextlevelbuilder/goclaw** multi-tenant AI agent platform into Hermes Agent, providing a production-tested multi-tenant AI gateway with 20+ LLM providers, 7 channels, and multi-tenant PostgreSQL support.

## Why GoClaw?
- **Single binary** — no Docker, no PostgreSQL, no infrastructure needed for desktop edition
- **20+ LLM providers** — OpenAI, Anthropic, Google Gemini, Anthropic, etc.
- **7 channels** — WhatsApp, Telegram, Discord, Email, etc.
- **Multi-tenant PostgreSQL** — isolated tenant data
- **Production-tested** — used in production deployments
- **GoClaw Lite** — native desktop app for local AI agents

## Installation

### GoClaw Desktop Edition (GoClaw Lite) — Recommended for Hermes

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/nextlevelbuilder/goclaw/main/scripts/install-lite.sh | bash

# Windows (PowerShell)
# (see repo for PowerShell install command)
```

### Full GoClaw — Server Edition

```bash
# From source
git clone -b main https://github.com/nextlevelbuilder/goclaw.git && cd goclaw
make build

# Or via Docker
docker pull nextlevelbuilder/goclaw:latest

# Docker Compose
docker compose up -d --build
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  nextlevelbuilder-goclaw: true

# Environment variables
export GOCLAW_BIN_PATH="$HOME/.local/bin/goclaw"  # or wherever installed
export GOCLAW_TENANT_ID="hermes-default"          # your tenant identifier
export GOCLAW_PROVIDERS="openai,anthropic,gemini"  # comma-separated list
export GOCLAW_CHANNELS="telegram,whatsapp"         # comma-separated list

# GoClaw Lite specific
export GOCLAW_LITE_MODE=1                          # desktop edition mode
export GOCLAW_LITE_SQLITE_PATH="$HOME/.hermes/goclaw.db"
```

## Usage

### GoClaw Desktop Edition (Lite)

```bash
# Onboard (interactive setup wizard)
goclaw onboard

# Start the app
goclaw

# Chat with agents
goclaw chat --tenant hermes-default

# Manage agents
goclaw agent --list --tenant hermes-default

# Check status
goclaw status --tenant hermes-default
```

### GoClaw Full (Server)

```bash
# Health check
curl http://localhost:18790/health

# List markets/tenants
curl http://localhost:18790/tenants

# Create a task
curl -X POST http://localhost:18790/tasks \
  -H "Content-Type: application/json" \
  -d '{"tenant": "hermes-default", "task": "design a dashboard"}'

# Query results
curl http://localhost:18790/results?task_id=abc123
```

### Multi-Tenant Operations

```bash
# Switch tenant
goclaw tenant --switch hermes-production

# List agents per tenant
goclaw agent --list --all-tenants

# Cross-tenant communication
goclaw message --to tenant=billing --subject "Urgent"
```

## Benefits
- **Multi-tenant isolation** — each tenant's data isolated in PostgreSQL
- **20+ LLM provider** flexibility — switch providers per task
- **7 communication channels** — reach users wherever they are
- **Single binary deployment** — especially Lite edition, no infra needed
- **Production-tested** — proven in real-world deployments
- **Kanban board** — task tracking within GoClaw dashboard

## Verification

```bash
# Check Hermes recognizes goclaw
hermes doctor

# Test GoClaw Lite startup
goclaw --version

# Test tenant management
goclaw tenant --list

# Test provider configuration
goclaw provider --list --tenant hermes-default
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| goclaw not found | Ensure `GOCLAW_BIN_PATH` is in PATH |
| Lite edition won't start | Check SQLite path permissions |
| Provider connection fails | Verify API keys in `~/.hermes/.env` |
| Tenant switching fails | Verify `GOCLAW_TENANT_ID` setting |
| Channel not working | Check credentials for that channel |
| Docker compose issues | Check port conflicts (18790 default) |

## References
- Original repo: https://github.com/nextlevelbuilder/goclaw
- Docs: https://docs.goclaw.sh
- License: MIT
- GoClaw Lite: https://github.com/nextlevelbuilder/goclaw#desktop-edition-gooclave
- Docker: https://docs.docker.com/compose/
- Project status: CHANGELOG.md for feature status