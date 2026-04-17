#!/usr/bin/env python3
"""
skiro learnings JSONL → Obsidian markdown sync.

Reads: ~/.skiro/learnings.jsonl
Writes: $VAULT/20_Learnings/<category>/<date>-<slug>.md

Idempotent: existing md files are not overwritten.
Incremental: last processed JSONL offset is kept in ~/.skiro/md-sync-state.json
Graceful: silently exits if vault_path not set.

Schema (skiro learnings.jsonl):
  date, category, severity, problem, solution, status,
  context, count, last_seen, promoted
"""
import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime

HOME = Path.home()
SKIRO_DIR = HOME / ".skiro"
CONFIG_FILE = SKIRO_DIR / "config.json"
LEARNINGS_FILE = Path(os.environ.get("SKIRO_LEARNINGS", SKIRO_DIR / "learnings.jsonl"))
STATE_FILE = SKIRO_DIR / "md-sync-state.json"


def get_vault_path():
    v = os.environ.get("SKIRO_VAULT")
    if v:
        return Path(v)
    if CONFIG_FILE.exists():
        try:
            cfg = json.loads(CONFIG_FILE.read_text())
            p = cfg.get("vault_path")
            if p:
                return Path(p)
        except Exception:
            return None
    return None


def slugify(text: str) -> str:
    text = re.sub(r"[^\w\s-]", "", (text or "").lower())
    text = re.sub(r"[\s_-]+", "-", text).strip("-")
    return text[:50] or "untitled"


def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except Exception:
            return {}
    return {}


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, indent=2))
    tmp.replace(STATE_FILE)


def entry_to_markdown(entry: dict) -> str:
    date = entry.get("date", datetime.now().date().isoformat())
    problem = entry.get("problem") or entry.get("lesson") or "untitled"
    category = entry.get("category", "process")
    severity = entry.get("severity", "WARNING")
    status = entry.get("status", "unsolved")
    count = entry.get("count", 1)
    last_seen = entry.get("last_seen", date)
    solution = entry.get("solution", "")
    context = entry.get("context", "")

    tags = ["learning", category, severity.lower()]
    if status == "unsolved":
        tags.append("unsolved")
    tags_str = ", ".join(tags)

    return f"""---
date: {date}
category: {category}
severity: {severity}
status: {status}
count: {count}
last_seen: {last_seen}
source: skiro
tags: [{tags_str}]
---

# {problem}

## Context
{context}

## Problem
{problem}

## Solution
{solution if solution else "_(pending)_"}

## Recurrence
- First seen: {date}
- Last seen: {last_seen}
- Count: {count}
"""


def sync(vault: Path) -> int:
    if not LEARNINGS_FILE.exists():
        return 0

    target_root = vault / "20_Learnings"
    target_root.mkdir(parents=True, exist_ok=True)

    state = load_state()
    key = str(LEARNINGS_FILE)
    last_offset = state.get(key, 0)

    written = 0
    updated = 0
    try:
        with LEARNINGS_FILE.open("r", encoding="utf-8") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            if last_offset > size:
                last_offset = 0
            f.seek(last_offset)
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                date = entry.get("date", datetime.now().date().isoformat())
                problem = entry.get("problem") or entry.get("lesson") or "untitled"
                category = entry.get("category", "process")
                slug = slugify(problem)

                cat_dir = target_root / category
                cat_dir.mkdir(parents=True, exist_ok=True)
                md_path = cat_dir / f"{date}-{slug}.md"

                body = entry_to_markdown(entry)
                if md_path.exists():
                    old = md_path.read_text(encoding="utf-8")
                    if old != body:
                        md_path.write_text(body, encoding="utf-8")
                        updated += 1
                else:
                    md_path.write_text(body, encoding="utf-8")
                    written += 1
            state[key] = f.tell()
    except OSError:
        return 0

    save_state(state)

    # Incremental run cannot catch updates to older entries (count/solution),
    # so on every invocation we also rescan the tail for entries with count > 1
    # that need refresh. Cheap since write is skipped when content matches.
    try:
        with LEARNINGS_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get("count", 1) < 2 and entry.get("status") != "solved":
                    continue
                date = entry.get("date", "")
                problem = entry.get("problem") or entry.get("lesson") or "untitled"
                category = entry.get("category", "process")
                slug = slugify(problem)
                md_path = target_root / category / f"{date}-{slug}.md"
                if not md_path.exists():
                    continue
                body = entry_to_markdown(entry)
                if md_path.read_text(encoding="utf-8") != body:
                    md_path.write_text(body, encoding="utf-8")
                    updated += 1
    except OSError:
        pass

    return written + updated


def main() -> int:
    vault = get_vault_path()
    if vault is None or not vault.exists():
        return 0
    n = sync(vault)
    if n and os.environ.get("SKIRO_MDSYNC_VERBOSE"):
        print(f"skiro-md-sync: {n} md files changed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Never block the caller
        sys.exit(0)
