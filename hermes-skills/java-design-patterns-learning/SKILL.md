---
name: java-design-patterns-learning
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


# iluwatar/java-design-patterns Learning Integration for Hermes Agent

## Overview
This skill integrates **iluwatar/java-design-patterns** into Hermes Agent as an educational reference for understanding common design patterns implemented in Java. While primarily Java-focused, the patterns are language-agnostic and can inspire custom implementations for Hermes Agent workflows.

## Why Java Design Patterns?
- **94K+ stars** — Highly regarded repository of design patterns
- **Comprehensive coverage** — 80+ patterns across all categories
- **Proven implementations** — Real, production-quality Java code
- **Language-agnostic concepts** — Pattern principles transfer to any language
- **Educational value** — Excellent for learning pattern intent and structure
- **Code quality reference** — Clean, well-documented implementations

## Pattern Categories
### Creational Patterns (8 patterns)
- Simple Factory
- Factory Method
- Abstract Factory
- Builder
- Prototype
- Singleton
- Object Pool
- Builder Variations

### Structural Patterns (8 patterns)
- Adapter
- Bridge
- Composite
- Decorator
- Facade
- Flyweight
- Proxy
- Variations

### Behavioral Patterns (11 patterns)
- Chain of Responsibility
- Command
- Iterator
- Mediator
- Memento
- Observer
- State
- Strategy
- Template Method
- Visitor
- Variations

### Architectural Patterns
- Clean Architecture
- Hexagonal Architecture
- Microservices Patterns
- Event-Driven Architecture
- Serverless Patterns
- CQRS (Command Query Responsibility Segregation)
- Event Sourcing

## Installation

```bash
# Clone for local access (recommended for learning)
git clone https://github.com/iluwatar/java-design-patterns.git
cd java-design-patterns

# Or access via GitHub directly
# https://github.com/iluwatar/java-design-patterns

# Verify installation
ls -la  # Should see all pattern directories, AGENTS.md, README.md
```

## Configuration

```yaml
# ~/.hermes/config.yaml
plugins:
  java-design-patterns-learning: true

# Environment variables
export JAVA_DESIGN_PATTERNS_PATH="$HOME/.hermes/resources/java-design-patterns"  # if cloned locally
export JAVA_DESIGN_PATTERNS_DEFAULT_CATEGORY="creational"  # creational | structural | behavioral | architectural
export JAVA_DESIGN_PATTERNS_CACHE_DIR="$HOME/.hermes/cache/java-design-patterns"
```

## Usage

### Exploring Patterns

```python
from hermes_tools import japdesignpatterns

# List all available patterns
patterns = japdesignpatterns.list_all_patterns()

# Get patterns by category
creational = japdesignpatterns.get_by_category("creational")
structural = japdesignpatterns.get_by_category("structural")
behavioral = japdesignpatterns.get_by_category("behavioral")

# Get specific pattern details
pattern = japdesignpatterns.get_pattern("singleton")
pattern_details = japdesignpatterns.get_pattern_details("adapter")

# Search for pattern by intent
patterns = japdesignpatterns.search_by_intent("decoupling")
patterns = japdesignpatterns.search_by_intent("object-creation")

# Or via CLI
java-design-patterns list
java-design-patterns category creational
java-design-patterns singleton
java-design-patterns search intent "decoupling"
```

### Hermes Agent Commands

```bash
# List all available patterns
hermes java-design-patterns list

# List patterns by category
hermes java-design-patterns category creational

# Get specific pattern details
hermes java-design-patterns singleton
hermes java-design-patterns adapter

# Search patterns by intent
hermes java-design-patterns search intent "decoupling"
hermes java-design-patterns search intent "object-creation"

# Get architectural patterns
hermes java-design-patterns architectural

# Compare pattern implementations across languages
hermes java-design-patterns compare "singleton" "rust"
```

### Example Workflows

#### Learn Creational Patterns for Agent Factories
```bash
# List creational patterns
hermes java-design-patterns category creational

# Get Singleton pattern details
hermes java-design-patterns singleton

# Apply to Hermes Agent
hermes ask "Design a thread-safe singleton agent factory in Python following this Java pattern"

# Learn Factory Method
hermes java-design-patterns factory-method

# Implement agent creation factory
hermes ask "Create a Python factory pattern for agent instantiation inspired by this Java example"
```

#### Structural Patterns for Agent Composition
```bash
# Get Adapter pattern
hermes java-design-patterns adapter

# Understand how to adapt interfaces
hermes ask "How can I adapt this legacy agent interface to work with the new Hermes API?"

# Learn Facade pattern
hermes java-design-patterns facade

# Create agent subsystem facade
hermes ask "Design a facade that provides simplified access to these 5 Hermes agent capabilities"
```

#### Behavioral Patterns for Agent Communication
```bash
# Get Observer pattern
hermes java-design-patterns observer

# Understand publish-subscribe for agent events
hermes ask "Design an event system where agents can subscribe to state changes in other agents"

# Learn Strategy pattern
hermes java-design-patterns strategy

# Implement different agent behavior strategies
hermes ask "Design strategy patterns for different trading approaches in my Clodds trading agent"
```

## Benefits
- **Pattern library** — 80+ proven design patterns at your fingertips
- **Educational resource** — Learn pattern intent, structure, and trade-offs
- **Language transfer** — Java concepts adapt to Python, Rust, Go, etc.
- **Code quality reference** — Clean implementations with documentation
- **Agent workflow inspiration** — Patterns apply to agent architecture
- **Cross-language applicability** — Principles transfer regardless of language

## Verification

```bash
# Check Hermes recognizes the skill
hermes doctor

# Test category listing
hermes java-design-patterns category creational

# Test specific pattern
hermes java-design-patterns singleton

# Test search functionality
hermes java-design-patterns search intent "decoupling"

# Test architectural patterns
hermes java-design-patterns architectural
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Pattern not found | Check spelling or use `list` command |
| Category not recognized | Use `list` to see valid categories |
| Repository not cloned | Run `git clone https://github.com/iluwatar/java-design-patterns.git` |
| Query too broad | Add more specific pattern name or intent |
| Search results too many | Add more specific intent or category |
| Difficult to understand | Use `help` command for pattern summary |

## References
- Original repo: https://github.com/iluwatar/java-design-patterns
- License: MIT
- Star count: 94,730+ (as of 2026)
- Fork count: 27,370+
- Pattern count: 80+ across creational, structural, behavioral, and architectural categories
- Last updated: Active maintenance with new patterns added regularly
- Educational value: Excellent for learning design patterns systematically