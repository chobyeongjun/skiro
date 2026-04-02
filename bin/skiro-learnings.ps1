#Requires -Version 5.1
# skiro-learnings.ps1 — Manage hardware learnings (Windows PowerShell equivalent)
# Usage: pwsh skiro-learnings.ps1 <search|add|list|count> [args]

$ErrorActionPreference = "Stop"

$SkiroHome = if ($env:SKIRO_HOME) { $env:SKIRO_HOME } else { Join-Path $HOME ".skiro" }
$LearnDir = Join-Path $SkiroHome "learnings"
if (-not (Test-Path $LearnDir)) { New-Item -ItemType Directory -Path $LearnDir -Force | Out-Null }

$Cmd = if ($args.Count -ge 1) { $args[0] } else { "help" }
$Rest = if ($args.Count -ge 2) { $args[1..($args.Count - 1)] } else { @() }

switch ($Cmd) {
    "search" {
        $Keyword = if ($Rest.Count -ge 1) { $Rest[0] } else { "" }
        if (-not $Keyword) {
            Write-Host "Usage: skiro-learnings search <keyword>"
            exit 1
        }
        $files = Get-ChildItem -Path $LearnDir -Filter "*.jsonl" -ErrorAction SilentlyContinue
        $results = @()
        foreach ($f in $files) {
            $matches = Select-String -Path $f.FullName -Pattern $Keyword -SimpleMatch -AllMatches
            foreach ($m in $matches) {
                $results += $m.Line
            }
        }
        $results | Select-Object -First 10
    }
    "add" {
        $Json = if ($Rest.Count -ge 1) { $Rest[0] } else { "" }
        if (-not $Json) {
            Write-Host "Usage: skiro-learnings add '<json>'"
            exit 1
        }
        # Extract tag
        $Tag = "general"
        if ($Json -match '"tags":\["([^"]*)"') {
            $Tag = $Matches[1].ToLower()
        }
        $File = Join-Path $LearnDir "$Tag.jsonl"

        # Extract key and handle update
        if ($Json -match '"key":"([^"]*)"') {
            $Key = $Matches[1]
            if ($Key -and (Test-Path $File)) {
                $existing = Get-Content $File -ErrorAction SilentlyContinue
                $filtered = $existing | Where-Object { $_ -notmatch [regex]::Escape("`"key`":`"$Key`"") }
                if ($filtered -and ($filtered.Count -lt $existing.Count)) {
                    $filtered | Set-Content $File
                    Write-Host "Updated: $Key"
                }
            }
        }

        # Add timestamp if missing
        if ($Json -notmatch '"ts"') {
            $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $Json = $Json -replace '^\{', "{`"ts`":`"$ts`","
        }
        Add-Content -Path $File -Value $Json
        Write-Host "Saved to $File"
    }
    "list" {
        $files = Get-ChildItem -Path $LearnDir -Filter "*.jsonl" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
            Write-Host "=== $name ==="
            Get-Content $f.FullName
            Write-Host ""
        }
    }
    "count" {
        $Total = 0
        $files = Get-ChildItem -Path $LearnDir -Filter "*.jsonl" -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $lines = (Get-Content $f.FullName | Measure-Object -Line).Lines
            $Total += $lines
        }
        Write-Host $Total
    }
    default {
        Write-Host "skiro-learnings: search <keyword> | add <json> | list | count"
    }
}
