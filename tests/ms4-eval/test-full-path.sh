#!/usr/bin/env bash
# MS4 eval: full path — score ≥ 80 (H-Walker 수준)
SCORER="$(dirname "$0")/../../bin/skiro-complexity"
PASS=0; FAIL=0

echo "=== MS4 EVAL: full path ==="
FIXTURE_DIR="$(mktemp -d)"
trap "rm -rf $FIXTURE_DIR" EXIT

cat > "$FIXTURE_DIR/hwalker_fw.c" << 'EOF'
#include "main.h"
#include "FreeRTOS.h"
#include "cmsis_os.h"
#define MAX_TORQUE 15.0f
#define MAX_CURRENT 8.0f
#define CAN_TIMEOUT_MS 250

volatile float g_pos[6];
volatile float g_vel[6];
volatile float g_curr[6];
volatile uint32_t last_can_rx_tick;

void CAN1_RX0_IRQHandler(void) {
  HAL_CAN_IRQHandler(&hcan1);
  last_can_rx_tick = HAL_GetTick();
}
void TIM2_IRQHandler(void) {
  HAL_TIM_IRQHandler(&htim2);
  for(int i=0;i<6;i++){
    float tau=10.0f*(0.0f-g_pos[i])-0.5f*g_vel[i];
    if(tau> MAX_TORQUE)tau= MAX_TORQUE;
    if(tau<-MAX_TORQUE)tau=-MAX_TORQUE;
    motor_can_send(&hcan1,i+1,0,0,10,0.5f,tau);
  }
}
void TIM3_IRQHandler(void) {
  HAL_TIM_IRQHandler(&htim3);
  if(HAL_GetTick()-last_can_rx_tick>CAN_TIMEOUT_MS) emergency_stop_all();
}
void ilc_task(void *arg) {
  float u_ff[200]={0},e_k[200]={0};
  while(1){
    for(int t=0;t<200;t++){
      u_ff[t]=0.95f*u_ff[t]+0.5f*e_k[t];
      if(u_ff[t]> MAX_TORQUE)u_ff[t]= MAX_TORQUE;
      if(u_ff[t]<-MAX_TORQUE)u_ff[t]=-MAX_TORQUE;
    }
    osDelay(1);
  }
}
void log_task(void *arg) {
  while(1){ f_printf(&SDFile,"%.4f\r\n",g_pos[0]); f_sync(&SDFile); osDelay(90); }
}
void motor_can_send(CAN_HandleTypeDef *hcan,uint8_t id,
  float p,float v,float kp,float kd,float t) {
  uint8_t buf[8]; HAL_CAN_AddTxMessage(hcan,&TxHeader,buf,&TxMailbox);
}
void emergency_stop_all(void) {
  uint8_t buf[8]={0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFD};
  for(int i=1;i<=6;i++) HAL_CAN_AddTxMessage(&hcan1,&TxHeader,buf,&TxMailbox);
}
osThreadId_t ilcHandle,logHandle;
void main_init(void) {
  ilcHandle=osThreadNew(ilc_task,NULL,NULL);
  logHandle=osThreadNew(log_task,NULL,NULL);
  osKernelStart();
}
EOF

result=$("$SCORER" "$FIXTURE_DIR/hwalker_fw.c" --json 2>/dev/null)
score=$(echo "$result"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['score'])" 2>/dev/null || echo 0)
tier=$(echo "$result"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['tier'])"  2>/dev/null || echo "?")
modules=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['modules'])" 2>/dev/null || echo "")

echo "  [H-Walker fw] score=$score tier=$tier"

[[ "$tier" == "full" ]] && { echo "  PASS [tier=full]"; PASS=$((PASS+1)); } \
                        || { echo "  FAIL [tier=$tier expected=full]"; FAIL=$((FAIL+1)); }

[[ $score -ge 80 ]] && { echo "  PASS [score=$score ≥ 80]"; PASS=$((PASS+1)); } \
                    || { echo "  FAIL [score=$score < 80]";  FAIL=$((FAIL+1)); }

for mod in "p3-fork" "p4-gate" "p1-scope" "p2-checklist"; do
  echo "$modules" | grep -q "$mod" \
    && { echo "  PASS [module $mod present]"; PASS=$((PASS+1)); } \
    || { echo "  FAIL [module $mod missing]"; FAIL=$((FAIL+1)); }
done

# JSON 유효성
echo "$result" | python3 -c "import sys,json; json.load(sys.stdin); print('  PASS [JSON valid]')" 2>/dev/null \
  && PASS=$((PASS+1)) || { echo "  FAIL [JSON invalid]"; FAIL=$((FAIL+1)); }

echo "full path: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && echo "RESULT: ALL PASS" && exit 0 || { echo "RESULT: FAIL"; exit 1; }
