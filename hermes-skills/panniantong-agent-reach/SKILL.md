---
name: panniantong-agent-reach
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


# Panniantong/Agent-Reach Integration for Hermes Agent

## Overview
This skill integrates **Panniantong/Agent-Reach** into Hermes Agent, providing internet access capabilities including Twitter, Reddit, YouTube, GitHub, Bilibili, XiaoHongShu, and full web search functionality with zero API fees.

## Why Agent-Reach?
- **Zero API fees** — all tools open-source, no paid APIs required
- **One CLI, multiple platforms** — Twitter/X, Reddit, YouTube, GitHub, Bilibili, XiaoHongShu
- **Platform resilience** — primary + fallback backends for each platform
- **Auto-route** — when one access method fails, automatically switches to next
- **Privacy-first** — cookies only exist locally, nothing uploaded

## Installation

```bash
# Using OpenClaw (recommended for Hermes)
openclaw install agent-reach

# Or direct CLI install
pip install agent-reach

# Or via the one-command method
# Copy this to your Hermes agent:
# "帮我安装 Agent Reach：https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md"

# Verify installation
agent-reach --version
agent-reach doctor

# Platform-specific setup
# Twitter: 告诉 Agent 「帮我配 Twitter」
# Bilibili: 告诉 Agent 「帮我配 B站」
# GitHub: 告诉 Agent 「帮我登录 GitHub」
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  panniantong-agent-reach: true

# Environment variables
export AGENT_REACH_DEFAULT_MODE=full  # lite | full | ultra | off
export AGENT_REACH_CACHE_DIR="$HOME/.hermes/cache/agent-reach"

# Per-platform settings (auto-configured)
# - Web: auto-enabled
# - YouTube: auto-enabled (subtitle extraction)
# - Twitter/X: needs config — 告诉 Agent 「帮我配 Twitter」
# - Reddit: needs config (anonymous interface may be blocked)
# - GitHub: needs login — 告诉 Agent 「帮我登录 GitHub」
# - Bilibili:字幕需 OpenCLI 配置
# - XiaoHongShu: needs config
```

## Usage

### Quick Start — One Command
```bash
# Install with one command (copy to Hermes agent)
# "帮我安装 Agent Reach：https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md"

# Or via CLI
agent-reach install

# Check status
agent-reach status

# Test platforms
agent-reach test twitter
agent-reach test reddit
agent-reach test youtube
agent-reach test github
agent-reach test bilibili
agent-reach test xiaohongshu
```

### Platform-Specific Usage

#### Twitter/X
```bash
# Read single tweet
agent-reach read-tweet --username user123 --tweet-id 1234567890

# Search tweets
agent-reach search-tweets --query "AI agents" --limit 10

# Browse timeline
agent-reach browse-timeline --user user123
```

#### YouTube
```bash
# Search videos
agent-reach search-youtube --query "fluid simulation tutorial"

# Get subtitles
agent-reach get-subtitles --video-id abc123

# Download transcripts
agent-reach download-transcript --video-id abc123
```

#### GitHub
```bash
# Read public repo
agent-reach read-repo --owner magnus919 --repo hermes-SkillOpt

# Search code
agent-reach search-code --query "fluid dynamics" --lang python

# Create issue
agent-reach create-issue --owner magnus919 --repo hermes-SkillOpt --title "Bug" --body "Description"
```

#### Reddit
```bash
# Read subreddit
agent-reach read-subreddit --subreddit machinelearning

# Search posts
agent-reach search-posts --query "LLM" --subreddit technology

# Read comments
agent-reach read-comments --post-id abc123
```

#### Bilibili
```bash
# Search videos
agent-reach search-bilibili --query "技术视频"

# Get video details
agent-reach get-video-detail --bvid BV1234567890

# Download with bili-cli
agent-reach download-bilibili --bvid BV1234567890
```

#### XiaoHongShu
```bash
# Search notes
agent-reach search-xhs --query "产品评测"

# Read notes
agent-reach read-xhs --note-id abc123
```

### Benefits
- **Internet access** for Hermes agent — fundamental capability
- **Zero API fees** — all tools open-source
- **Platform resilience** — auto-fallback on failures
- **Privacy-first** — no data uploaded
- **One CLI** — unified interface for all platforms

## Verification

```bash
# Check Hermes recognizes agent-reach
hermes doctor

# Test platform access
hermes ask "Search Twitter for AI agent news"

# Verify YouTube access
hermes ask "Find YouTube tutorials on fluid simulation"

# Test GitHub access
hermes ask "Read the README from magnus919/hermes-SkillOpt"
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| agent-reach not found | Ensure PATH includes agent-reach binary |
| Twitter blocked | Run `agent-reach doctor --fix-twitter` |
| YouTube unavailable | Check `agent-reach config --youtube` |
| GitHub auth needed | Run `agent-reach login --github` |
| Bilibili restricted | Configure bili-cli via `agent-reach config --bilibili` |
| Reddit 403 | Try `agent-reach set-mode --reddit anonymous` |

## References
- Original repo: https://github.com/Panniantong/Agent-Reach
- Docs: https://github.com/Panniantong/Agent-Reach/wiki
- License: MIT
- Trendshift: #1 Repository of the Day
- Supported platforms: Web, YouTube, RSS, GitHub, Twitter/X, Bilibili, Reddit (partial), XiaoHongShu