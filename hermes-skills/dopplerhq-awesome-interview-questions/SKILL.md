---
name: dopplerhq-awesome-interview-questions
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

# dopplerhq-awesome-interview-questions Skill

## Description
Curated awesome list of lists of interview questions covering programming, data structures, algorithms, and technical topics for various languages and experience levels. Provides structured interview question categories for agent training and assessment.

## Why This Skill is Valuable
- Structured interview question categories
- Covers multiple programming languages and topics
- Useful for agent assessment and training
- Organized by topic and difficulty level

## Key Features
- Organized question categories (C++, general programming, etc.)
- Coverage of data structures and algorithms
- Multiple difficulty levels
- Contribution-friendly structure
- Ready-to-use question sets for agent evaluation

## Usage
This skill provides access to interview question collections that can be applied to:
- Agent assessment and evaluation
- Technical interview preparation
- Knowledge base for agent training
- Structured testing of agent capabilities

## Integration
Activates automatically via Hermes' pre_llm_call hook. No manual invocation needed.

## Configuration
Add to ~/.hermes/config.yaml:
```yaml
plugins:
  dopplerhq-awesome-interview-questions: true
```