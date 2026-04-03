$ErrorActionPreference = "Stop"

$SkiroHome = if ($env:SKIRO_HOME) { $env:SKIRO_HOME } else { Join-Path $HOME ".claude\skills\skiro" }

# 1. Check skiro installation
if (-not (Test-Path $SkiroHome)) {
    $ans = Read-Host "skiro가 설치되지 않았습니다. git clone으로 설치할까요? (y/n)"
    if ($ans -match '^[yY]') {
        git clone https://github.com/chobyeongjun/skiro.git $SkiroHome
    } else {
        Write-Host "설치를 취소합니다."
        exit 1
    }
}

# 2. Check if already initialized
if (Test-Path ".skiro") {
    $ans = Read-Host "이미 초기화된 프로젝트입니다. 덮어쓸까요? (y/n)"
    if ($ans -notmatch '^[yY]') {
        Write-Host "초기화를 취소합니다."
        exit 0
    }
}

# 3. Create project-local directories
New-Item -ItemType Directory -Force -Path ".skiro\learnings" | Out-Null

# 4. Copy hardware.yaml.template
$tmpl = Join-Path $SkiroHome "hardware.yaml.template"
if (Test-Path $tmpl) {
    Copy-Item $tmpl -Destination ".\hardware.yaml.template" -Force
} else {
    Write-Warning "hardware.yaml.template을 찾을 수 없습니다 ($SkiroHome)"
}

# 5. Create/append CLAUDE.md
$section = @"
# skiro 규칙

- 모터 제어 코드 수정 시 반드시 /skiro-safety 실행
- hardware.yaml 없는 프로젝트에서는 안전 기본값 사용
- CHECKLIST.md의 CRITICAL 항목은 예외 없이 적용
"@

if (Test-Path "CLAUDE.md") {
    $content = Get-Content "CLAUDE.md" -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch "# skiro") {
        Add-Content "CLAUDE.md" "`n`n$section"
    }
} else {
    Set-Content "CLAUDE.md" $section -Encoding UTF8
}

# 6. Update .gitignore
$ignoreLines = @(".skiro/learnings/", "*.bag", "*.bag.active")
if (-not (Test-Path ".gitignore")) {
    New-Item ".gitignore" -ItemType File | Out-Null
}
$existing = Get-Content ".gitignore" -ErrorAction SilentlyContinue
foreach ($line in $ignoreLines) {
    if ($existing -notcontains $line) {
        Add-Content ".gitignore" $line
    }
}

# 7. Summary
Write-Host @"
skiro init 완료.
 - .skiro/ 디렉토리 생성
 - hardware.yaml.template 복사
 - CLAUDE.md 업데이트
 다음: /skiro-hwtest로 하드웨어 설정을 시작하세요.
"@
