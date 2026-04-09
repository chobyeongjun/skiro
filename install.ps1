# skiro install v4.0 (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1 [-Project "C:\path\to\project"]
# Installs skiro harness: hooks + MCP + PATH

param(
    [string]$Project = ""
)

$ErrorActionPreference = "Stop"
$SkiroDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Settings = Join-Path $env:USERPROFILE ".claude\settings.json"

Write-Host "skiro install v4.0 (Windows)" -ForegroundColor Cyan
Write-Host "=============================="

# 1. npm dependencies
Write-Host "[1/5] Installing npm deps..."
Push-Location (Join-Path $SkiroDir "bin")
npm install --silent 2>$null
Pop-Location
Write-Host "[1/5] npm deps installed" -ForegroundColor Green

# 2. PATH registration
$BinPath = Join-Path $SkiroDir "bin"
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$BinPath;$UserPath", "User")
    [Environment]::SetEnvironmentVariable("SKIRO_BIN", $BinPath, "User")
    Write-Host "[2/5] PATH registered (restart terminal to activate)" -ForegroundColor Green
} else {
    Write-Host "[2/5] PATH already registered" -ForegroundColor Green
}

# 3. settings.json hooks configuration
$SettingsDir = Split-Path -Parent $Settings
if (-not (Test-Path $SettingsDir)) {
    New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null
}

$HooksConfig = @{
    PreToolUse = @(
        @{
            matcher = "Read|Write|Edit|MultiEdit"
            hooks = @(@{
                type = "command"
                command = "sh `"$($SkiroDir -replace '\\','/')/bin/skiro-hook-complexity`""
            })
        },
        @{
            matcher = "Bash"
            hooks = @(@{
                type = "command"
                command = "sh `"$($SkiroDir -replace '\\','/')/bin/skiro-hook-gate`""
            })
        }
    )
    UserPromptSubmit = @(
        @{
            hooks = @(@{
                type = "command"
                command = "sh `"$($SkiroDir -replace '\\','/')/bin/skiro-hook-session`""
            })
        },
        @{
            hooks = @(@{
                type = "command"
                command = "sh `"$($SkiroDir -replace '\\','/')/bin/skiro-hook-prompt`""
            })
        }
    )
    PostToolUse = @(
        @{
            matcher = "Bash"
            hooks = @(@{
                type = "command"
                command = "sh `"$($SkiroDir -replace '\\','/')/bin/skiro-hook-error`""
            })
        }
    )
}

if (Test-Path $Settings) {
    $existing = Get-Content $Settings -Raw | ConvertFrom-Json
    $existingHooks = @{}
    if ($existing.hooks) {
        $existing.hooks.PSObject.Properties | ForEach-Object {
            $eventType = $_.Name
            $entries = @($_.Value)
            # Remove old skiro entries
            $kept = @($entries | Where-Object {
                $dominated = $false
                if ($_.hooks) {
                    $_.hooks | ForEach-Object {
                        if ($_.command -and $_.command -like "*skiro*") { $dominated = $true }
                    }
                }
                -not $dominated
            })
            $existingHooks[$eventType] = $kept
        }
    }
    # Merge new hooks
    foreach ($eventType in $HooksConfig.Keys) {
        $prev = @()
        if ($existingHooks.ContainsKey($eventType)) { $prev = $existingHooks[$eventType] }
        $existingHooks[$eventType] = @($prev) + @($HooksConfig[$eventType])
    }
    $existing | Add-Member -NotePropertyName "hooks" -NotePropertyValue $existingHooks -Force
    $existing | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8
    Write-Host "[3/5] hooks merged into settings.json (preserved existing hooks)" -ForegroundColor Green
} else {
    @{ hooks = $HooksConfig } | ConvertTo-Json -Depth 10 | Set-Content $Settings -Encoding UTF8
    Write-Host "[3/5] settings.json created with hooks" -ForegroundColor Green
}

# 4. MCP registration
Write-Host "[4/5] Registering MCP server..."
try { claude mcp remove skiro 2>$null } catch {}
$McpServer = Join-Path $SkiroDir "bin\skiro-mcp-server.mjs"
claude mcp add skiro -s user -- node $McpServer
Write-Host "[4/5] MCP server registered" -ForegroundColor Green

# 5. Project CLAUDE.md setup
if ($Project -ne "") {
    if (Test-Path $Project) {
        $ClaudeMd = Join-Path $Project "CLAUDE.md"
        $Template = Join-Path $SkiroDir "templates\CLAUDE.md.template"
        if (Test-Path $ClaudeMd) {
            $content = Get-Content $ClaudeMd -Raw -ErrorAction SilentlyContinue
            if ($content -notmatch "skiro Harness") {
                Add-Content $ClaudeMd "`n"
                Get-Content $Template | Add-Content $ClaudeMd
                Write-Host "[5/5] skiro section appended to $ClaudeMd" -ForegroundColor Green
            } else {
                Write-Host "[5/5] skiro section already in CLAUDE.md (skipped)" -ForegroundColor Green
            }
        } else {
            Copy-Item $Template $ClaudeMd
            Write-Host "[5/5] CLAUDE.md created at $ClaudeMd" -ForegroundColor Green
        }
    } else {
        Write-Host "[5/5] WARNING: project dir not found: $Project" -ForegroundColor Yellow
    }
} else {
    Write-Host "[5/5] No -Project specified (skipped CLAUDE.md)"
    Write-Host "  To add: .\install.ps1 -Project C:\path\to\your\project"
}

Write-Host ""
Write-Host "Done. Restart Claude Code to activate hooks." -ForegroundColor Cyan
Write-Host ""
Write-Host "Prerequisites check:" -ForegroundColor Yellow
Write-Host "  - Git Bash (git-scm.com) must be installed for hooks to work"
Write-Host "  - 'sh' command must be available in PATH"
Write-Host ""
Write-Host "Verify:"
Write-Host "  claude mcp list | grep skiro"
