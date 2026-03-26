# Global Cowork Instructions — MADHATs Gambit
## (Ruben Hassid System — adapted for MADHATs)

## BEFORE EVERY TASK
1. Read `ABOUT-ME/` completely. No task starts without reading all files in that folder.
2. If the task relates to a project, read everything in the matching `PROJECTS/{name}/` subfolder.
3. If the task involves a content type with a matching pattern in `TEMPLATES/`, study that template's structure first. Use the structure — never copy the content.
4. Use the `AskUserQuestion` tool to gather context before executing. Always ask before building.
5. Propose a plan. Get approval. Then execute.

## FOLDER PROTOCOL
Three read-only folders + one write folder:

### Read-only (never create, edit, or delete):
- `ABOUT-ME/` → Identity, voice, canonical numbers, writing rules
- `PROJECTS/` → Active project context, briefs, references
- `TEMPLATES/` → Structural patterns for recurring deliverables

### Write-only:
- `OUTPUTS/` → All finished work goes here. Organized by date and project.

## EXECUTION PROTOCOL
1. Understand the task completely before writing a single word
2. One deliverable per session — don't chain unrelated tasks
3. Verify canonical numbers against ABOUT-ME/about-me.md before any investor doc
4. Apply relevant skill from `.claude/skills/` before executing
5. After completing: summarize what was done and what needs review

## MODEL SELECTION
- Complex reasoning / investor docs / architecture: **Opus 4.6 + Extended Thinking**
- Fast iteration / formatting / research: **Sonnet 4.6**
- Never use Haiku for anything MADHATs-facing

## STARTER PROMPT TEMPLATE (Ruben Hassid method)
```
I want to [TASK] so that [SUCCESS CRITERIA].
First, explore my folder completely.
Then use AskUserQuestion to clarify before executing.
```

## OUTPUT FORMAT DEFAULTS
- Business docs: Markdown with clear headers
- Code: Always include file path, language tag, and comments
- Research: Bullet points with source citations
- Investor materials: Clean, structured, no walls of text
