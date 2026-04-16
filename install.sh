#!/usr/bin/env bash
# skiro install v4.0
# Usage: bash install.sh [--project <path>] [--vault <path>]
# Installs skiro harness: hooks + MCP + PATH
# --project: also copy CLAUDE.md template to target project
# --vault: set Obsidian vault path for knowledge integration

set -euo pipefail

SKIRO_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"
PROJECT_DIR=""
VAULT_DIR=""

# 인수 파싱
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJECT_DIR="$2"; shift 2 ;;
        --vault)   VAULT_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "skiro install v4.0"
echo "=================="

# 1. 실행 권한
chmod +x "$SKIRO_DIR/bin/skiro-complexity" \
         "$SKIRO_DIR/bin/skiro-learnings" \
         "$SKIRO_DIR/bin/skiro-mcp-server.mjs" \
         "$SKIRO_DIR/bin/skiro-hook-complexity" \
         "$SKIRO_DIR/bin/skiro-hook-gate" \
         "$SKIRO_DIR/bin/skiro-hook-session" \
         "$SKIRO_DIR/bin/skiro-hook-prompt" \
         "$SKIRO_DIR/bin/skiro-hook-error"
echo "[1/6] permissions set"

# 2. npm 의존성
cd "$SKIRO_DIR/bin" && npm install --silent
echo "[2/6] npm deps installed"

# 3. Vault config (optional)
SKIRO_CONFIG="$HOME/.skiro/config.json"
mkdir -p "$HOME/.skiro"
if [[ -n "$VAULT_DIR" ]]; then
    if [[ -d "$VAULT_DIR" ]]; then
        # Resolve to absolute path
        VAULT_ABS="$(cd "$VAULT_DIR" && pwd)"
        python3 << PYEOF
import json, os
config_path = "$SKIRO_CONFIG"
try:
    with open(config_path) as f:
        config = json.load(f)
except:
    config = {}
config["vault_path"] = "$VAULT_ABS"
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
print(f"vault_path set: $VAULT_ABS")
PYEOF
        # Copy vault template notes if they don't exist yet
        VAULT_TEMPLATES="$SKIRO_DIR/templates/vault"
        if [[ -d "$VAULT_TEMPLATES" ]]; then
            mkdir -p "$VAULT_ABS/20_Meta/skiro"
            for note in "$VAULT_TEMPLATES"/*.md; do
                DEST="$VAULT_ABS/20_Meta/skiro/$(basename "$note")"
                if [[ ! -f "$DEST" ]]; then
                    cp "$note" "$DEST"
                fi
            done
        fi
        echo "[3/6] vault configured → $VAULT_ABS (reference notes in 20_Meta/skiro/)"
    else
        echo "[3/6] WARNING: vault dir not found: $VAULT_DIR (skipped)"
    fi
else
    if [[ -f "$SKIRO_CONFIG" ]]; then
        echo "[3/6] vault config unchanged (existing ~/.skiro/config.json)"
    else
        echo "[3/6] No --vault specified (skipped, add later with --vault)"
    fi
fi

# 4. PATH 등록
SHELL_RC=""
[[ -f "$HOME/.bashrc" ]] && SHELL_RC="$HOME/.bashrc"
[[ -f "$HOME/.zshrc" ]]  && SHELL_RC="$HOME/.zshrc"

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "skiro/bin" "$SHELL_RC" 2>/dev/null; then
        echo "export PATH=\"$SKIRO_DIR/bin:\$PATH\"" >> "$SHELL_RC"
        echo "export SKIRO_BIN=\"$SKIRO_DIR/bin\""   >> "$SHELL_RC"
    fi
fi
echo "[4/6] PATH registered → source your shell rc to activate"

# 4. settings.json hooks 설정
mkdir -p "$(dirname "$SETTINGS")"

# 기존 settings.json 있으면 hooks 섹션만 병합
if [[ -f "$SETTINGS" ]]; then
    python3 << PYEOF
import json, os

settings_path = "$SETTINGS"
skiro_dir = "$SKIRO_DIR"

with open(settings_path) as f:
    settings = json.load(f)

hooks = {
    "PreToolUse": [
        {
            "matcher": "Read|Write|Edit|MultiEdit",
            "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-complexity"}]
        },
        {
            "matcher": "Bash",
            "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-gate"}]
        }
    ],
    "UserPromptSubmit": [
        {
            "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-session"}]
        },
        {
            "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-prompt"}]
        }
    ],
    "PostToolUse": [
        {
            "matcher": "Bash",
            "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-error"}]
        }
    ]
}

# Merge: keep existing non-skiro hooks per event type
existing_hooks = settings.get("hooks", {})
for event_type, new_entries in hooks.items():
    existing = existing_hooks.get(event_type, [])
    # Remove old skiro entries (contain skiro_dir in command)
    kept = [e for e in existing if not any("skiro" in h.get("command", "") for h in e.get("hooks", []))]
    kept.extend(new_entries)
    existing_hooks[event_type] = kept
settings["hooks"] = existing_hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
print("merged into existing settings.json (preserved non-skiro hooks)")
PYEOF
else
    # 신규 생성
    python3 << PYEOF
import json
skiro_dir = "$SKIRO_DIR"
settings = {
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Read|Write|Edit|MultiEdit",
                "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-complexity"}]
            },
            {
                "matcher": "Bash",
                "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-gate"}]
            }
        ],
        "UserPromptSubmit": [
            {
                "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-session"}]
            },
            {
                "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-prompt"}]
            }
        ],
        "PostToolUse": [
            {
                "matcher": "Bash",
                "hooks": [{"type": "command", "command": f"{skiro_dir}/bin/skiro-hook-error"}]
            }
        ]
    }
}
with open("$SETTINGS", "w") as f:
    json.dump(settings, f, indent=2)
print("created new settings.json")
PYEOF
fi
echo "[5/6] hooks configured in ~/.claude/settings.json"

# 5. MCP 등록
claude mcp remove skiro 2>/dev/null || true
claude mcp add skiro -s user -- node "$SKIRO_DIR/bin/skiro-mcp-server.mjs"
echo "[5/6] MCP server registered"

# 6. 프로젝트 CLAUDE.md 설치 (선택)
if [[ -n "$PROJECT_DIR" ]]; then
    if [[ -d "$PROJECT_DIR" ]]; then
        CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
        if [[ -f "$CLAUDE_MD" ]]; then
            # 기존 CLAUDE.md에 skiro 섹션이 없으면 추가
            if ! grep -q "skiro Harness" "$CLAUDE_MD" 2>/dev/null; then
                echo "" >> "$CLAUDE_MD"
                cat "$SKIRO_DIR/templates/CLAUDE.md.template" >> "$CLAUDE_MD"
                echo "[6/6] skiro section appended to $CLAUDE_MD"
            else
                echo "[6/6] skiro section already in $CLAUDE_MD (skipped)"
            fi
        else
            cp "$SKIRO_DIR/templates/CLAUDE.md.template" "$CLAUDE_MD"
            echo "[6/6] CLAUDE.md created at $CLAUDE_MD"
        fi
    else
        echo "[6/6] WARNING: project dir not found: $PROJECT_DIR"
    fi
else
    echo "[6/6] No --project specified (skipped CLAUDE.md setup)"
    echo "  To add to a project: bash install.sh --project /path/to/your/robot/project"
fi

echo ""
echo "Done. Restart Claude Code to activate hooks."
echo ""
echo "Verify:"
echo "  claude mcp list | grep skiro"
echo "  cat ~/.skiro/config.json"
echo "  skiro-complexity <your_file.c> --json"
