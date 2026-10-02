---
name: hoppscotch
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

# hoppscotch Skill

## Description
Hoppscotch is an open-source API development ecosystem that provides a lightweight, fast, and versatile interface for testing and developing APIs. It supports HTTP methods, WebSocket, Socket.io, GraphQL, and more. Available as web, desktop, and CLI applications.

## Why This Skill is Valuable
- Provides API testing and development capabilities
- Lightweight and fast
- Supports multiple protocols (HTTP, WebSocket, Socket.io, GraphQL)
- Available offline, on-prem, and cloud
- Open-source alternative to Postman and Insomnia
- Can be used by agents to test and interact with APIs

## Key Features
- Lightweight and fast UI
- Supports all HTTP methods (GET, POST, PUT, PATCH, DELETE, HEAD, CONNECT, OPTIONS)
- WebSocket and Socket.io support
- GraphQL support
- Environment variables and authentication helpers
- Request/response history and collections
- Code generation for multiple languages
- Offline and on-prem capable
- Web, desktop, and CLI versions

## Usage
This skill provides access to Hoppscotch's API development capabilities that can be used to:
- Test and develop APIs
- Debug API interactions
- Generate API documentation
- Automate API testing workflows
- Integrate with agent workflows for API-driven tasks

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  hoppscotch: true
```