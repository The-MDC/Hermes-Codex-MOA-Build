#!/usr/bin/env python3
"""check-capabilities.py — hold the orchestration to capabilities.yaml.

WHY THIS EXISTS
    Capabilities in this build are duplicated across two surfaces -- .claude/skills/
    for Claude Code, hermes-skills/ for Hermes -- and the duplicates diverged with
    nothing reporting it. Two skills written so the local tier could take the handoff
    landed on one surface only and were invisible to the other.

    capabilities.yaml declares what exists and who carries it. This script is what
    makes that declaration binding: it fails the build when the tree stops matching.

WHAT IT CHECKS, and why each one earns its place

    1. Nothing on disk is undeclared. A skill nobody declared is a skill nobody
       reviewed the surface placement of -- which is how the divergence happened.

    2. Nothing declared is missing. Catches a capability deleted from one surface
       while the declaration still promises it.

    3. Every asymmetric entry states WHY. Asymmetry is legitimate and often correct
       -- hosted MCP servers cost prompt space on every Hermes request, so they are
       kept out on purpose -- but an unexplained asymmetry is indistinguishable from
       an accident, and that is what this catches.

    4. Frontmatter is valid. THIS IS THE ONE THAT WAS SILENTLY BROKEN. A skill with a
       missing or malformed metadata block loads without complaint and simply never
       triggers; the port script's own header says so and nothing ever checked it.
       Three product skills shipped with no YAML frontmatter at all and therefore
       never fired. They have since been removed from this repo entirely.

NAME RESOLUTION DIFFERS BY SURFACE, deliberately
    Hermes looks a skill up by its DIRECTORY name (hermes-skills/<cat>/<name>/SKILL.md).
    Claude Code looks it up by the frontmatter `name`, which need not match the
    filename. So the two are compared by name, never by path, and a Claude-side
    filename that differs from its declared name is reported as INFO rather than a
    failure -- it resolves correctly, it is just confusing to grep for.

usage:
  python3 scripts/check-capabilities.py            # check; exit 1 on any failure
  python3 scripts/check-capabilities.py --quiet    # only failures
  python3 scripts/check-capabilities.py --emit     # print a fresh skeleton from disk
"""

import glob
import os
import sys

import yaml

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(REPO, "capabilities.yaml")

QUIET = "--quiet" in sys.argv
EMIT = "--emit" in sys.argv

FAILURES = []
NOTES = []


def fail(msg):
    FAILURES.append(msg)


def note(msg):
    NOTES.append(msg)


def say(msg):
    if not QUIET:
        print(msg)


def frontmatter(path):
    """Return the parsed YAML frontmatter, or None if absent/unparseable.

    Both outcomes matter and are not the same: absent means someone wrote a plain
    markdown file, unparseable means someone wrote frontmatter that does not load.
    Callers treat both as invalid, but the distinction is worth preserving for the
    message.
    """
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None
    try:
        parsed = yaml.safe_load(parts[1])
    except yaml.YAMLError:
        return None
    return parsed if isinstance(parsed, dict) else None


# ----------------------------------------------------------------- disk state
def scan_claude():
    """.claude/skills/<category>/<name>.md — keyed by FRONTMATTER name."""
    found = {}
    for path in sorted(glob.glob(os.path.join(REPO, ".claude/skills/**/*.md"), recursive=True)):
        rel = os.path.relpath(path, REPO)
        category = rel.split(os.sep)[2]
        stem = os.path.basename(path)[:-3]
        fm = frontmatter(path)
        valid = bool(fm and "name" in fm and "description" in fm)
        name = (fm or {}).get("name") or stem
        found[name] = {"path": rel, "category": category, "stem": stem, "valid": valid, "fm": fm}
    return found


def scan_hermes():
    """hermes-skills/<category>/<name>/SKILL.md — keyed by DIRECTORY name."""
    found = {}
    for path in sorted(glob.glob(os.path.join(REPO, "hermes-skills/*/*/SKILL.md"))):
        rel = os.path.relpath(path, REPO)
        parts = rel.split(os.sep)
        category, name = parts[1], parts[2]
        found[name] = {"path": rel, "category": category, "fm": frontmatter(path)}
    return found


# ------------------------------------------------------------------ the checks
HERMES_REQUIRED = ("name", "description", "version", "author", "platforms", "metadata")


def check_hermes_frontmatter(name, entry, all_hermes):
    fm = entry["fm"]
    p = entry["path"]
    if fm is None:
        fail(f"{p}: no parseable YAML frontmatter — this skill loads and never triggers")
        return
    missing = [k for k in HERMES_REQUIRED if k not in fm]
    if missing:
        fail(f"{p}: frontmatter missing {missing}")
    hermes = (fm.get("metadata") or {}).get("hermes")
    if not isinstance(hermes, dict):
        fail(f"{p}: metadata.hermes is missing — Hermes' skill index reads it to decide when to offer the skill")
        return
    for key in ("tags", "category", "related_skills"):
        if key not in hermes:
            fail(f"{p}: metadata.hermes.{key} is missing")
    if fm.get("name") != name:
        fail(f"{p}: frontmatter name {fm.get('name')!r} != directory {name!r} — Hermes looks up by directory")
    if hermes.get("category") != entry["category"]:
        fail(f"{p}: metadata.hermes.category {hermes.get('category')!r} != directory {entry['category']!r}")
    for rel_skill in hermes.get("related_skills") or []:
        if rel_skill not in all_hermes:
            fail(f"{p}: related_skills names {rel_skill!r}, which does not exist")


def check_claude_frontmatter(name, entry):
    if not entry["valid"]:
        fail(f"{entry['path']}: no usable frontmatter (needs name + description) — never triggers")
        return
    if entry["stem"] != name:
        note(f"{entry['path']}: filename {entry['stem']!r} differs from declared name {name!r} (resolves fine; harder to grep)")


def main():
    claude = scan_claude()
    hermes = scan_hermes()

    if EMIT:
        emit_skeleton(claude, hermes)
        return 0

    if not os.path.exists(REGISTRY):
        print(f"check-capabilities: {REGISTRY} not found — the declaration is the point of this check")
        return 1
    reg = yaml.safe_load(open(REGISTRY, encoding="utf-8"))

    declared = {s["name"]: s for s in reg.get("skills") or []}

    # 1. nothing on disk is undeclared
    for name in sorted(set(claude) | set(hermes)):
        if name not in declared:
            where = "claude" if name in claude else "hermes"
            fail(f"skill {name!r} exists on the {where} surface but is not in capabilities.yaml")

    # 2. nothing declared is missing, and 3. asymmetry is explained
    for name, entry in sorted(declared.items()):
        surfaces = entry.get("surfaces") or []
        if not surfaces:
            fail(f"{name}: declares no surfaces")
            continue
        for surface in surfaces:
            present = name in (claude if surface == "claude" else hermes)
            if not present:
                fail(f"{name}: capabilities.yaml claims the {surface} surface, but it is not on disk there")
        actual = [s for s in ("claude", "hermes") if name in (claude if s == "claude" else hermes)]
        if sorted(actual) != sorted(surfaces):
            fail(f"{name}: declared surfaces {surfaces} != actual {actual}")
        if len(surfaces) == 1 and not (entry.get("asymmetry_reason") or "").strip():
            fail(f"{name}: on one surface only and states no asymmetry_reason — "
                 f"an unexplained asymmetry is indistinguishable from an accident")

    # 4. frontmatter validity
    for name, entry in sorted(hermes.items()):
        check_hermes_frontmatter(name, entry, hermes)
    for name, entry in sorted(claude.items()):
        check_claude_frontmatter(name, entry)

    # MCP servers are declared but their presence is checked against the two config
    # files rather than the filesystem.
    declared_mcp = {m["name"]: m for m in reg.get("mcp_servers") or []}
    import json
    cm = set(json.load(open(os.path.join(REPO, ".mcp.json"), encoding="utf-8"))["mcpServers"])
    hm = set(yaml.safe_load(open(os.path.join(REPO, "configs/hermes/config.yaml"),
                                 encoding="utf-8"))["mcp_servers"])
    for name in sorted(cm | hm):
        if name not in declared_mcp:
            fail(f"mcp server {name!r} is configured but not in capabilities.yaml")
    for name, entry in sorted(declared_mcp.items()):
        actual = [s for s, have in (("claude", name in cm), ("hermes", name in hm)) if have]
        if sorted(actual) != sorted(entry.get("surfaces") or []):
            fail(f"mcp {name}: declared surfaces {entry.get('surfaces')} != actual {actual}")
        if len(actual) == 1 and not (entry.get("asymmetry_reason") or "").strip():
            fail(f"mcp {name}: on one surface only and states no asymmetry_reason")

    # ------------------------------------------------------------------ report
    say("capabilities")
    say(f"  registry      {len(declared)} skill(s), {len(declared_mcp)} mcp server(s)")
    say(f"  on disk       claude {len(claude)}, hermes {len(hermes)}, "
        f"both {len(set(claude) & set(hermes))}")
    for n in NOTES:
        say(f"  info  {n}")

    if FAILURES:
        print("")
        print(f"capabilities: {len(FAILURES)} problem(s)")
        for f in FAILURES:
            print(f"  FAIL  {f}")
        print("")
        print("Either fix the tree, or change capabilities.yaml deliberately. The")
        print("declaration is the contract; drifting from it silently is what this")
        print("check exists to stop.")
        return 1

    say("")
    say("capabilities: OK — every capability declared, every asymmetry explained")
    return 0


def emit_skeleton(claude, hermes):
    """Print a registry skeleton from disk. Reasons cannot be inferred; they are left
    blank on purpose so the check fails until a human writes them."""
    skills = []
    for name in sorted(set(claude) | set(hermes)):
        surfaces = [s for s in ("claude", "hermes") if name in (claude if s == "claude" else hermes)]
        entry = {
            "name": name,
            "surfaces": surfaces,
            "source": "ported" if name in hermes else "claude-native",
            "category": hermes[name]["category"] if name in hermes else claude[name]["category"],
        }
        if len(surfaces) == 1:
            entry["asymmetry_reason"] = ""
        skills.append(entry)
    print(yaml.safe_dump({"version": 1, "skills": skills}, sort_keys=False,
                         width=100, allow_unicode=True))


if __name__ == "__main__":
    sys.exit(main())
