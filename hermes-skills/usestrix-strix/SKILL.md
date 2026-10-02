---
name: usestrix-strix
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

# usestrix-strix Skill

## Description
Open-source AI penetration testing tool to find and fix your app’s vulnerabilities. Provides autonomous AI pentesters that run your code dynamically, find vulnerabilities, and validate them through actual proofs-of-concept.

## Why This Skill is Valuable
- Provides AI-powered penetration testing capabilities
- Offers real exploit validation (working PoCs, not false positives)
- Includes multi-agent orchestration for scalable testing
- Integrates with CI/CD pipelines for automated security testing
- Generates actionable findings with remediation guidance
- Produces compliance-ready pentest reports

## Key Features
- Full pentesting toolkit (reconnaissance, exploitation, validation)
- Multi-agent orchestration for collaborative scaling
- Real exploit validation with working proofs-of-concept
- Developer-first CLI with actionable findings
- Auto-fix and reporting capabilities
- GitHub Actions and CI/CD integration
- Supports multiple LLM providers (OpenAI, Anthropic, Google, etc.)

## Usage
This skill provides access to Strix AI pentesting capabilities that can be used to:
- Perform application security testing
- Conduct rapid penetration testing
- Automate bug bounty research
- Integrate security testing into CI/CD pipelines
- Generate compliance-ready reports

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  usestrix-strix: true
```