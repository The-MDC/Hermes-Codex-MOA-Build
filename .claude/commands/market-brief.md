---
name: market-brief
description: Research and brief on a target market, competitor, or partnership opportunity
allowed_tools: ["Read", "Write", "Bash"]
---
# /market-brief

## Goal
Produce a structured competitive or market intelligence brief.

## Pre-execution
1. Read .claude/skills/madhats/mpp-platform.md
2. Read .claude/skills/sales/competitive-intelligence.md
3. Read .claude/skills/product/competitive-brief.md
4. Use AskUserQuestion: target entity, purpose (partnership/competition/acquisition)

## Brief Structure
1. Executive Summary (3 sentences max)
2. What They Do (product, market position)
3. Relevance to MADHATs (why this matters)
4. Opportunities (integration, partnership, differentiation)
5. Risks (competitive threat, dependencies)
6. Recommended Action

## Output: OUTPUTS/research/{entity}-brief.md
