---
name: puppeteer
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

# puppeteer Skill

## Description
Puppeteer is a JavaScript library which provides a high-level API to control Chrome or Firefox over the DevTools Protocol or WebDriver BiDi. Puppeteer runs in headless mode by default but can be configured to run full (non-headless) Chrome or Firefox.

## Why This Skill is Valuable
- Provides browser automation and testing capabilities
- Supports headless and headed browsers
- Integrates with DevTools Protocol for deep browser control
- Can be used for web scraping, testing, and automation
- Works with both Chrome and Firefox
- Provides MCP server for external control

## Key Features
- High-level API for browser control
- Supports DevTools Protocol and WebDriver BiDi
- Headless and headed browser modes
- Screenshot and PDF generation
- Form submission and UI testing
- Web scraping and automation
- MCP server integration (chrome-devtools-mcp)
- Extensive API for browser interaction

## Usage
This skill provides access to Puppeteer's browser automation capabilities that can be used to:
- Automate browser tasks and workflows
- Perform web scraping and data extraction
- Run automated tests for web applications
- Generate screenshots and PDFs of web pages
- Control browsers via MCP for external agent coordination
- Integrate with Hermes agent for web-based tasks

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  puppeteer: true
```