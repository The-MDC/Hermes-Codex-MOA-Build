---
name: ciso-assistant
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

# ciso-assistant Skill

## Description
CISO Assistant is a one-stop-shop GRC platform for Risk Management, AppSec, Compliance & Audit, TPRM, BIA, Privacy, and Reporting. It supports 150+ global frameworks with automatic control mapping, including ISO 27001, NIST CSF, SOC 2, CIS, PCI DSS, NIS2, DORA, GDPR, HIPAA, CMMC, and more.

## Why This Skill is Valuable
- Centralized GRC (Governance, Risk, and Compliance) platform
- Supports 150+ global frameworks
- Automatic control mapping between frameworks
- Multi-paradigm tool adapting to different backgrounds
- API-first approach for automation
- Built-in risk assessment and remediation tracking

## Key Features
- Connects multiple cybersecurity concepts with smart linking
- Decouples compliance from cybersecurity controls for reusability
- API-first approach for UI interaction and external automation
- Wide range of built-in standards, security controls, and threat libraries
- Open format for custom objects and frameworks
- Built-in risk assessment and remediation tracking workflows
- Custom frameworks support via simple syntax and tooling
- Rich import/export capabilities across various channels and formats

## Usage
This skill provides access to CISO Assistant capabilities that can be used to:
- Governance, risk, and compliance management
- Framework mapping and control implementation
- Risk assessment and remediation tracking
- Automated compliance workflows
- Security policy and procedure management

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  ciso-assistant: true
```