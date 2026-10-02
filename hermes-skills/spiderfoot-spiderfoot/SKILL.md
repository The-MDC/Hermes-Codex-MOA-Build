---
name: spiderfoot-spiderfoot
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


# SpiderFoot Skill

Provides capabilities to run SpiderFoot scans for OSINT gathering.

## Usage

- Initialize SpiderFoot: `sf.py -l 127.0.0.1:5001` to start web UI
- Run a scan: `sf.py -m <module> -s <target>`
- List modules: `sf.py -l`
- Scan with multiple modules: `sf.py -m sfp_whois,sfp_dnsresolve -s example.com`
- Docker: `docker run -p 5001:5001 spiderfoot/spiderfoot`

## Examples

```bash
# Start web interface
sf.py -l 127.0.0.1:5001

# Run a scan on a domain using passive DNS and whois
sf.py -m sfp_dnsresolve,sfp_whois -s example.com

# Export results to JSON
sf.py -m sfp_footprint -s example.com -o json -f result.json
```

## Notes

SpiderFoot requires Python 3.7+ and dependencies from requirements.txt.