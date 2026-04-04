#!/usr/bin/env bash
# MS4 eval: partial path — score 30–79
SCORER="$(dirname "$0")/../../bin/skiro-complexity"
PASS=0; FAIL=0

run_test() {
  local name="$1" file="$2" expected_tier="$3" must_present="${4:-}" must_absent="${5:-}"
  local result tier modules ok=1

  result=$("$SCORER" "$file" 2>/dev/null) || result="tier=full modules=p1-scope,p2-checklist,p3-fork,p4-gate"
  tier=$(echo "$result"    | grep -oP 'tier=\K\w+')
  modules=$(echo "$result" | grep -oP 'modules=\K\S+' || echo "")

  [[ "$tier" != "$expected_tier" ]] && ok=0
  [[ -n "$must_present" ]] && ! echo "$modules" | grep -q "$must_present" && ok=0
  [[ -n "$must_absent"  ]] &&   echo "$modules" | grep -q "$must_absent"  && ok=0

  if [[ $ok -eq 1 ]]; then
    echo "  PASS [$name] tier=$tier"
    PASS=$((PASS+1))
  else
    score=$("$SCORER" "$file" --json 2>/dev/null | grep -oP '"score":\s*\K[0-9]+' || echo "?")
    echo "  FAIL [$name] tier=$tier (expected=$expected_tier) score=$score modules=$modules"
    FAIL=$((FAIL+1))
  fi
}

echo "=== MS4 EVAL: partial path ==="
FIXTURE_DIR="$(mktemp -d)"
trap "rm -rf $FIXTURE_DIR" EXIT

# ISR 1개(15) + thread 1개(12) = 27 → fast ← 아슬아슬
# ISR 2개(30) + thread 1개(12) = 42 → partial ✓
cat > "$FIXTURE_DIR/dual_isr_simple.c" << 'EOF'
#include "main.h"
#include "cmsis_os.h"

static float g_adc_val = 0.0f;
static uint8_t g_tim_flag = 0;

void ADC1_IRQHandler(void) {
  HAL_ADC_IRQHandler(&hadc1);
  g_adc_val = (float)HAL_ADC_GetValue(&hadc1) / 4095.0f * 3.3f;
}

void TIM2_IRQHandler(void) {
  HAL_TIM_IRQHandler(&htim2);
  g_tim_flag = 1;
}

void process_task(void *arg) {
  while(1) {
    if(g_tim_flag) {
      g_tim_flag = 0;
      // 처리
    }
    osDelay(10);
  }
}

osThreadId_t procHandle;
void app_start(void) {
  procHandle = osThreadNew(process_task, NULL, NULL);
}
EOF

# ISR 1개(15) + thread 1개(12) + RTOS(20) = 47 → partial ✓
cat > "$FIXTURE_DIR/rtos_single_isr.c" << 'EOF'
#include "FreeRTOS.h"
#include "task.h"
#include "main.h"

static volatile float g_sensor = 0.0f;

void EXTI0_IRQHandler(void) {
  HAL_GPIO_EXTI_IRQHandler(GPIO_PIN_0);
  g_sensor += 1.0f;
}

void sensor_task(void *arg) {
  while(1) {
    float val = g_sensor;
    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

void vApplicationIdleHook(void) {}
TaskHandle_t sensorTask;
void main_init(void) {
  xTaskCreate(sensor_task, "sensor", 256, NULL, 1, &sensorTask);
  vTaskStartScheduler();
}
EOF

run_test "dual ISR + thread (partial)"    "$FIXTURE_DIR/dual_isr_simple.c"  "partial" "p3-fork"  ""
run_test "FreeRTOS single ISR (partial)"  "$FIXTURE_DIR/rtos_single_isr.c"  "partial" "p3-fork"  ""
# partial tier는 §B full fork 없어야 함
run_test "partial: domain check"          "$FIXTURE_DIR/dual_isr_simple.c"  "partial" "p1-scope" ""

echo "partial path: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && echo "RESULT: ALL PASS" && exit 0 || { echo "RESULT: FAIL"; exit 1; }
