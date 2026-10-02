---
name: crowdsecurity-crowdsec
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


# CrowdSec Skill

## Description

This skill provides commands to interact with CrowdSec, an open-source security engine that analyzes logs, detects threats, and blocks malicious IPs using a community-driven blocklist. It leverages the `cscli` command-line interface to manage scenarios, collections, parsers, postoverflows, and bans.

## Usage Examples

Check CrowdSec service status:
```bash
cscli status
```

List installed scenarios:
```bash
cscli scenarios list
```

Install a scenario from the CrowdSec Hub (e.g., SSH brute force protection):
```bash
cscli scenarios install crowdsecurity/ssh-bf
```

Update the CrowdSec Hub to get latest configurations:
```bash
cscli hub update
```

List available collections in the Hub:
```bash
cscli hub list
```

Add a manual ban on an IP address (e.g., block 1.2.3.4 for 4 hours):
```bash
cscli decisions add -i 1.2.3.4 --duration 4h
```

List active bans/decisions:
```bash
cscli decisions list
```

Remove a ban by its ID:
```bash
cscli decisions delete <ban-id>
```

Monitor CrowdSec alerts in real-time:
```bash
cscli alerts watch
```

## Notes

- CrowdSec must be installed and running on the system for these commands to work. Refer to the [official installation guide](https://doc.crowdsec.net/) for setup instructions.
- The skill assumes the `cscli` command is available in the system's PATH.
- For Windows users, CrowdSec can be installed via WSL or using the official Windows package.
- All CrowdSec configurations and data are stored in `/etc/crowdsec/` (Linux) or the equivalent platform-specific directory.
- The CrowdSec Hub (https://hub.crowdsec.net) provides community-sourced scenarios, parsers, and collections for various services.