#!/usr/bin/env bash
# MS4 eval 전체 실행기

set -uo pipefail
cd "$(dirname "$0")"

TOTAL_PASS=0; TOTAL_FAIL=0

run_suite() {
  local script="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bash "$script"
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "✓ $(basename $script) SUITE PASS"
    ((TOTAL_PASS++))
  else
    echo "✗ $(basename $script) SUITE FAIL (rc=$rc)"
    ((TOTAL_FAIL++))
  fi
}

echo "╔══════════════════════════════════╗"
echo "║    skiro MS4 eval — full suite   ║"
echo "╚══════════════════════════════════╝"

run_suite test-fast-path.sh
run_suite test-partial-path.sh
run_suite test-full-path.sh
run_suite test-graceful-fallback.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUITE RESULTS: PASS=$TOTAL_PASS FAIL=$TOTAL_FAIL"
echo ""

if [[ $TOTAL_FAIL -eq 0 ]]; then
  echo "✅ MS4 eval ALL SUITES PASS — 모듈화 안전"
  exit 0
else
  echo "❌ MS4 eval FAIL — STEP 3 모듈화 중단, 원인 분석 필요"
  exit 1
fi
