#!/usr/bin/env bash
# skiro install v2.0
# Usage: bash install.sh
# Installs skiro harness: hooks + MCP + PATH

set -euo pipefail

SKIRO_DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$HOME/.claude/settings.json"

echo "skiro install v2.0"
echo "=================="

# 1. 실행 권한
chmod +x "$SKIRO_DIR/bin/skiro-complexity" \
         "$SKIRO_DIR/bin/skiro-learnings" \
         "$SKIRO_DIR/bin/skiro-mcp-server.mjs" \
         "$SKIRO_DIR/bin/skiro-hook-complexity" \
         "$SKIRO_DIR/bin/skiro-hook-gate" \
         "$SKIRO_DIR/bin/skiro-hook-session" \
         "$SKIRO_DIR/bin/skiro-hook-prompt"
echo "[1/5] permissions set"

# 2. npm 의존성
cd "$SKIRO_DIR/bin" && npm install --silent
echo "[2/5] npm deps installed"

# 3. PATH 등록
SHELL_RC=""
[[ -f "$HOME/.zshrc" ]]  && SHELL_RC="$HOME/.zshrc"
[[ -f "$HOME/.bashrc" ]] && SHELL_RC="$HOME/.bashrc"

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "skiro/bin" "$SHELL_RC" 2>/dev/null; then
        echo "export PATH=\"$SKIRO_DIR/bin:\$PATH\"" >> "$SHELL_RC"
        echo "export SKIRO_BIN=\"$SKIRO_DIR/bin\""   >> "$SHELL_RC"
    fi
fi
echo "[3/5] PATH registered → source your shell rc to activate"

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
    ]
}

settings["hooks"] = hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
print("merged into existing settings.json")
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
            }
        ]
    }
}
with open("$SETTINGS", "w") as f:
    json.dump(settings, f, indent=2)
print("created new settings.json")
PYEOF
fi
echo "[4/5] hooks configured in ~/.claude/settings.json"

# 5. MCP 등록
claude mcp remove skiro 2>/dev/null || true
claude mcp add skiro -s user -- node "$SKIRO_DIR/bin/skiro-mcp-server.mjs"
echo "[5/5] MCP server registered"

echo ""
echo "Done. Restart Claude Code to activate hooks."
echo ""
echo "Verify:"
echo "  claude mcp list | grep skiro"
echo "  skiro-complexity <your_file.c> --json"
