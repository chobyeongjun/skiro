#!/usr/bin/env bash
# skiro-backup: Backup skiro harness + data for machine migration
# Usage: bash skiro-backup.sh [output.tar.gz]
# Backs up: ~/skiro/, ~/.skiro/, ~/.claude/settings.json

set -euo pipefail

OUTPUT="${1:-$HOME/skiro-backup-$(date +%Y%m%d).tar.gz}"
SKIRO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "skiro backup"
echo "============"

# Collect paths to back up
PATHS=()

# 1. skiro harness code
if [[ -d "$SKIRO_DIR" ]]; then
    PATHS+=("$SKIRO_DIR")
    echo "[1/3] skiro dir: $SKIRO_DIR"
else
    echo "[1/3] WARNING: skiro dir not found: $SKIRO_DIR"
fi

# 2. ~/.skiro data (config, learnings, artifacts, papers)
SKIRO_DATA="$HOME/.skiro"
if [[ -d "$SKIRO_DATA" ]]; then
    PATHS+=("$SKIRO_DATA")
    echo "[2/3] skiro data: $SKIRO_DATA"
    # Show what's included
    if [[ -f "$SKIRO_DATA/config.json" ]]; then
        echo "  - config.json (vault path, settings)"
    fi
    if [[ -f "$SKIRO_DATA/learnings.jsonl" ]]; then
        LEARN_COUNT=$(wc -l < "$SKIRO_DATA/learnings.jsonl" 2>/dev/null || echo 0)
        echo "  - learnings.jsonl ($LEARN_COUNT entries)"
    fi
    if [[ -f "$SKIRO_DATA/artifacts.jsonl" ]]; then
        ART_COUNT=$(wc -l < "$SKIRO_DATA/artifacts.jsonl" 2>/dev/null || echo 0)
        echo "  - artifacts.jsonl ($ART_COUNT entries)"
    fi
    if [[ -d "$SKIRO_DATA/papers" ]]; then
        PAPER_COUNT=$(ls "$SKIRO_DATA/papers"/*.json 2>/dev/null | wc -l || echo 0)
        echo "  - papers/ ($PAPER_COUNT paper states)"
    fi
else
    echo "[2/3] No ~/.skiro data yet (skipped)"
fi

# 3. Claude settings (hooks config)
SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
    PATHS+=("$SETTINGS")
    echo "[3/3] settings: $SETTINGS"
else
    echo "[3/3] No settings.json (skipped)"
fi

if [[ ${#PATHS[@]} -eq 0 ]]; then
    echo "Nothing to back up."
    exit 1
fi

# Create archive (paths relative to home for portability)
cd "$HOME"
REL_PATHS=()
for p in "${PATHS[@]}"; do
    REL_PATHS+=("$(python3 -c "import os; print(os.path.relpath('$p', '$HOME'))")")
done

tar czf "$OUTPUT" "${REL_PATHS[@]}"

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo ""
echo "Backup complete: $OUTPUT ($SIZE)"
echo ""
echo "Restore on new machine:"
echo "  tar xzf $(basename "$OUTPUT") -C ~/"
echo "  bash ~/skiro/install.sh --project /path/to/project"
echo ""
echo "Note: Vault is NOT included (back up separately or use git)."
echo "  After restore, update vault path: install.sh --vault /new/vault/path"
