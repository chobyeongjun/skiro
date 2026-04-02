#Requires -Version 5.1
# skiro-session.ps1 — Session handoff management (Windows PowerShell equivalent)
# Usage: pwsh skiro-session.ps1 <save|load|list> [args]

$ErrorActionPreference = "Stop"

$SkiroHome = if ($env:SKIRO_HOME) { $env:SKIRO_HOME } else { Join-Path $HOME ".skiro" }
$Cmd = if ($args.Count -ge 1) { $args[0] } else { "help" }
$Rest = if ($args.Count -ge 2) { $args[1..($args.Count - 1)] } else { @() }

switch ($Cmd) {
    "save" {
        $Project = if ($Rest.Count -ge 1) { $Rest[0] } else { "unknown" }
        $Summary = if ($Rest.Count -ge 2) { $Rest[1] } else { "" }
        $Dir = Join-Path $SkiroHome "sessions" $Project
        if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
        $Ts = Get-Date -Format "yyyyMMdd-HHmmss"
        $File = Join-Path $Dir "$Ts.md"
        $Summary | Set-Content -Path $File
        Copy-Item -Path $File -Destination (Join-Path $Dir "latest.md") -Force
        Write-Host "Session saved: $File"
    }
    "load" {
        $Project = if ($Rest.Count -ge 1) { $Rest[0] } else { "unknown" }
        $F = Join-Path $SkiroHome "sessions" $Project "latest.md"
        if (Test-Path $F) {
            Get-Content $F
        } else {
            Write-Host "NO_SESSION"
        }
    }
    "list" {
        $Project = if ($Rest.Count -ge 1) { $Rest[0] } else { "unknown" }
        $Dir = Join-Path $SkiroHome "sessions" $Project
        $files = Get-ChildItem -Path $Dir -Filter "*.md" -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 5
        if ($files) {
            $files | ForEach-Object { Write-Host $_.FullName }
        } else {
            Write-Host "NO_SESSIONS"
        }
    }
    default {
        Write-Host "skiro-session: save <project> <summary> | load <project> | list <project>"
    }
}
