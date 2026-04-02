#Requires -Version 5.1
# setup-skiro.ps1 v2.0.0
# Self-contained installer for Skiro — AI Development Pipeline for Robot Engineers
# Usage: powershell -ExecutionPolicy Bypass -File setup-skiro.ps1
# Tries git clone first; falls back to GitHub zip download if clone fails.

$ErrorActionPreference = "Stop"

$SkiroDir = Join-Path $HOME ".claude\skills\skiro"
$RepoUrl = "https://github.com/chobyeongjun/skiro.git"
$ZipUrl = "https://github.com/chobyeongjun/skiro/archive/refs/heads/main.zip"
$Version = "1.0.0"
$UsedGit = $false

Write-Host "============================================"
Write-Host " Skiro v$Version Installer (Windows)"
Write-Host "============================================"

# ── Step 1: Try git clone ────────────────────────────────────────────
$gitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)

if ($gitAvailable) {
    Write-Host "[1/4] Trying git clone from $RepoUrl ..."
    try {
        git clone $RepoUrl $SkiroDir 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "      git clone succeeded."
            $UsedGit = $true
        } else {
            throw "git clone failed"
        }
    } catch {
        Write-Host "      git clone failed. Falling back to zip download."
    }
} else {
    Write-Host "[1/4] git not found. Falling back to zip download."
}

# ── Step 2: Zip download fallback (skipped if git clone succeeded) ───
if (-not $UsedGit) {
    Write-Host "[1/4] Downloading from GitHub ..."
    $TempZip = Join-Path $env:TEMP "skiro-main.zip"
    $TempExtract = Join-Path $env:TEMP "skiro-extract"

    try {
        # Clean up any previous temp files
        if (Test-Path $TempZip) { Remove-Item $TempZip -Force }
        if (Test-Path $TempExtract) { Remove-Item $TempExtract -Recurse -Force }

        # Download zip
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TempZip -UseBasicParsing

        # Extract
        Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force

        # Move extracted content to target directory
        $extractedDir = Get-ChildItem -Path $TempExtract -Directory | Select-Object -First 1
        if (-not $extractedDir) {
            throw "No directory found in downloaded zip"
        }

        # Create parent directory if needed
        $parentDir = Split-Path $SkiroDir -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        # Move to final location
        if (Test-Path $SkiroDir) { Remove-Item $SkiroDir -Recurse -Force }
        Move-Item -Path $extractedDir.FullName -Destination $SkiroDir -Force

        Write-Host "      Download and extraction succeeded."

        # Clean up temp files
        Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
        Remove-Item $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "      ERROR: Download failed. $_"
        Write-Host ""
        Write-Host "Please install manually:"
        Write-Host "  1. Install git: https://git-scm.com/download/win"
        Write-Host "  2. Run: git clone $RepoUrl `"$SkiroDir`""
        Write-Host ""
        exit 1
    }
}

# ── Step 3: Create flat copies of sub-skill SKILL.md files ───────────
Write-Host "[2/4] Creating flat skill copies ..."
$skills = @("safety", "hwtest", "flash", "spec", "retro", "gui", "data", "analyze", "gait", "comm")
foreach ($skill in $skills) {
    $flatDir = Join-Path $HOME ".claude\skills\skiro-$skill"
    $sourceFile = Join-Path $SkiroDir "skiro-$skill\SKILL.md"
    if (-not (Test-Path $flatDir)) {
        New-Item -ItemType Directory -Path $flatDir -Force | Out-Null
    }
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination (Join-Path $flatDir "SKILL.md") -Force
        Write-Host "      skiro-$skill -> $flatDir\SKILL.md"
    } else {
        Write-Host "      WARNING: $sourceFile not found, skipping."
    }
}

# ── Step 4: Git init if zip install ──────────────────────────────────
if (-not $UsedGit) {
    if ($gitAvailable) {
        Write-Host "[3/4] Initializing git repo ..."
        Push-Location $SkiroDir
        git init -q
        git add -A
        git commit -q -m "Initial zip install v$Version"
        Pop-Location
    } else {
        Write-Host "[3/4] Skipping git init (git not available)."
    }
} else {
    Write-Host "[3/4] Skipping git init (cloned from remote)."
}

# ── Step 4: Verify PowerShell scripts ────────────────────────────────
Write-Host "[4/4] Verifying installation ..."
$binDir = Join-Path $SkiroDir "bin"
$psScripts = @("skiro-learnings.ps1", "skiro-session.ps1")
foreach ($script in $psScripts) {
    $scriptPath = Join-Path $binDir $script
    if (Test-Path $scriptPath) {
        Write-Host "      $script OK"
    } else {
        Write-Host "      WARNING: $script not found"
    }
}

# ── Summary ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================"
Write-Host " Skiro v$Version installed successfully!"
Write-Host "============================================"
Write-Host ""
Write-Host "Location : $SkiroDir"
Write-Host "Skills   : 10 (safety hwtest flash spec retro gui data analyze gait comm)"
Write-Host "Scripts  : bin/skiro-learnings.ps1  bin/skiro-session.ps1"
Write-Host ""
Write-Host "Flat copies:"
foreach ($skill in $skills) {
    Write-Host "  $HOME\.claude\skills\skiro-$skill\SKILL.md"
}
Write-Host ""
Write-Host "Quick start:"
Write-Host "  Open Claude Code and type: /skiro-hwtest"
Write-Host ""
