#!/usr/bin/env bash
# MS4 eval: fast path — score < 30, p3-fork 없어야 함
SCORER="$(dirname "$0")/../../bin/skiro-complexity"
PASS=0; FAIL=0

run_test() {
  local name="$1" file="$2" must_absent="${3:-}" must_present="${4:-}"
  local result tier modules ok=1

  result=$("$SCORER" "$file" 2>/dev/null) || result="tier=full modules=p1-scope,p2-checklist,p3-fork,p4-gate"
  tier=$(echo "$result"   | grep -oP 'tier=\K\w+')
  modules=$(echo "$result" | grep -oP 'modules=\K\S+' || echo "")

  [[ -n "$must_absent"  ]] && echo "$modules" | grep -q "$must_absent"  && ok=0
  [[ -n "$must_present" ]] && ! echo "$modules" | grep -q "$must_present" && ok=0

  if [[ $ok -eq 1 ]]; then
    echo "  PASS [$name] tier=$tier"
    PASS=$((PASS+1))
  else
    echo "  FAIL [$name] tier=$tier modules=$modules"
    echo "       absent='$must_absent' present='$must_present'"
    FAIL=$((FAIL+1))
  fi
}

echo "=== MS4 EVAL: fast path ==="
FIXTURE_DIR="$(mktemp -d)"
trap "rm -rf $FIXTURE_DIR" EXIT

cat > "$FIXTURE_DIR/led_blink.c" << 'EOF'
#include "main.h"
void blink_loop(void) {
  HAL_GPIO_TogglePin(GPIOB, GPIO_PIN_3);
  HAL_Delay(500);
}
EOF

cat > "$FIXTURE_DIR/simple_uart.c" << 'EOF'
#include "main.h"
#include <stdio.h>
int __io_putchar(int ch) {
  HAL_UART_Transmit(&huart2, (uint8_t*)&ch, 1, HAL_MAX_DELAY);
  return ch;
}
void print_hello(void) { printf("Hello!\r\n"); }
EOF

cat > "$FIXTURE_DIR/adc_temp.c" << 'EOF'
#include "main.h"
uint16_t TS_CAL1 = 0;
uint16_t TS_CAL2 = 0;
float read_temperature(void) {
  HAL_ADC_Start(&hadc1);
  HAL_ADC_PollForConversion(&hadc1, HAL_MAX_DELAY);
  uint16_t raw = HAL_ADC_GetValue(&hadc1);
  return (110.0f - 30.0f) / (TS_CAL2 - TS_CAL1) * (raw - TS_CAL1) + 30.0f;
}
EOF

run_test "LED blink"    "$FIXTURE_DIR/led_blink.c"   "p3-fork" "p1-scope"
run_test "UART printf"  "$FIXTURE_DIR/simple_uart.c" "p3-fork" "p2-checklist"
run_test "ADC temp"     "$FIXTURE_DIR/adc_temp.c"    "p3-fork" "p1-scope"

echo "fast path: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && echo "RESULT: ALL PASS" && exit 0 || { echo "RESULT: FAIL"; exit 1; }
