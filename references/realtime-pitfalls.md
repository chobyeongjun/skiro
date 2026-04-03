# Real-Time Embedded Bug Patterns

> 실시간 임베디드 시스템에서 반복적으로 발생하는 버그 패턴 모음.
> 각 패턴에 코드 예시, grep 감지 패턴, 수정 방법 포함.

---

## 카테고리 목차

1. [타이밍/스케줄링 버그](#1-타이밍스케줄링-버그)
2. [인터럽트 관련 버그](#2-인터럽트-관련-버그)
3. [메모리/자원 버그](#3-메모리자원-버그)
4. [동기화/동시성 버그](#4-동기화동시성-버그)
5. [수치/오버플로우 버그](#5-수치오버플로우-버그)
6. [하드웨어 인터페이스 버그](#6-하드웨어-인터페이스-버그)
7. [상태 머신 버그](#7-상태-머신-버그)

---

## 1. 타이밍/스케줄링 버그

### P01: delay() 기반 타이밍

루프에서 `delay()`로 주기를 맞추면 처리 시간이 누적되어 jitter 발생.

```c
// BAD
void control_loop() {
    while (1) {
        read_sensors();
        compute_control();
        send_command();
        delay(10);  // 처리 시간 미포함 → 주기 > 10ms
    }
}

// GOOD — 절대 시간 기준
void control_loop() {
    TickType_t last_wake = xTaskGetTickCount();
    while (1) {
        read_sensors();
        compute_control();
        send_command();
        vTaskDelayUntil(&last_wake, pdMS_TO_TICKS(10));
    }
}
```

**grep 감지:** `grep -rn "delay(" --include="*.c" --include="*.cpp" | grep -v "DelayUntil\|delay_until"`

---

### P02: 타이머 오버플로우 무시

`millis()` 또는 `HAL_GetTick()`은 32비트에서 약 49.7일 후 오버플로우.

```c
// BAD — 오버플로우 시 음수 차이
if (HAL_GetTick() - start_time > timeout) { ... }

// GOOD — unsigned 연산으로 자연스럽게 처리 (이미 unsigned면 OK)
uint32_t elapsed = (uint32_t)(HAL_GetTick() - start_time);
if (elapsed > timeout) { ... }
```

**grep 감지:** `grep -rn "millis()\s*-\|GetTick()\s*-" --include="*.c" --include="*.cpp"`

---

### P03: 하드코딩된 타이밍 상수

시스템 클럭이나 주기 변경 시 하드코딩 값이 안 맞음.

```c
// BAD
#define CONTROL_DELAY 1000  // 무슨 단위? ms? us? ticks?

// GOOD
#define CONTROL_PERIOD_MS    10
#define CONTROL_PERIOD_TICKS pdMS_TO_TICKS(CONTROL_PERIOD_MS)
```

**grep 감지:** `grep -rn "#define.*DELAY\s\+[0-9]" --include="*.h" --include="*.c"`

---

### P04: Deadline miss 미감지

제어 루프가 데드라인을 놓쳐도 아무 경고 없이 계속 실행.

```c
// BAD — 데드라인 초과 무시
void control_task(void *arg) {
    TickType_t last = xTaskGetTickCount();
    while (1) {
        do_heavy_computation();
        vTaskDelayUntil(&last, pdMS_TO_TICKS(1));
    }
}

// GOOD — 초과 감지 및 로깅
void control_task(void *arg) {
    TickType_t last = xTaskGetTickCount();
    while (1) {
        TickType_t start = xTaskGetTickCount();
        do_heavy_computation();
        TickType_t elapsed = xTaskGetTickCount() - start;
        if (elapsed > pdMS_TO_TICKS(1)) {
            log_warning("deadline miss: %lu ms", elapsed);
            deadline_miss_count++;
        }
        vTaskDelayUntil(&last, pdMS_TO_TICKS(1));
    }
}
```

**grep 감지:** `grep -rn "vTaskDelayUntil" --include="*.c" | grep -v "deadline\|overrun\|miss"`

---

### P05: 주기적 태스크에서 가변 실행 경로

조건에 따라 실행 시간이 크게 달라지면 worst-case에서 데드라인 위반.

```c
// BAD
void control_loop() {
    read_sensors();
    if (need_calibration) {
        calibrate_all_sensors();  // 100ms 소요
    }
    compute_pid();  // 1ms 소요
}

// GOOD — 캘리브레이션은 별도 태스크로 분리
void control_loop() {
    read_sensors();
    compute_pid();
}
void calibration_task() {  // 낮은 우선순위
    calibrate_all_sensors();
}
```

**grep 감지:** `grep -rn "calibrat\|init\|setup" --include="*.c" | grep -i "loop\|task\|periodic"`

---

### P06: 부동소수점 연산의 타이밍 변동

FPU 없는 MCU에서 float 연산은 소프트웨어 에뮬레이션으로 수십~수백 배 느림.

```c
// BAD — Cortex-M0 (FPU 없음)에서
float angle = atan2f(y, x);  // ~500us 소프트웨어 에뮬

// GOOD — 정수 연산 또는 룩업 테이블
int16_t angle = fast_atan2_lut(y_q15, x_q15);  // ~5us
```

**grep 감지:** `grep -rn "atan2f\|sinf\|cosf\|sqrtf\|powf" --include="*.c" --include="*.cpp"`

---

### P07: Watchdog 미설정

무한 루프에 빠져도 리셋 메커니즘이 없음.

```c
// BAD — watchdog 없음
int main(void) {
    init_all();
    while (1) { control_loop(); }
}

// GOOD
int main(void) {
    init_all();
    HAL_IWDG_Init(&hiwdg);
    while (1) {
        control_loop();
        HAL_IWDG_Refresh(&hiwdg);
    }
}
```

**grep 감지:** `grep -rLn "IWDG\|WDT\|watchdog" --include="*.c" --include="*.h"`

---

## 2. 인터럽트 관련 버그

### P08: 인터럽트 내 긴 처리

ISR에서 오래 걸리는 작업 수행 → 다른 인터럽트 지연.

```c
// BAD
void EXTI0_IRQHandler(void) {
    read_encoder();
    compute_velocity();    // 수학 연산
    update_display();      // I2C 통신
    HAL_GPIO_EXTI_IRQHandler(GPIO_PIN_0);
}

// GOOD — flag만 설정, 메인 루프에서 처리
volatile uint8_t encoder_flag = 0;
void EXTI0_IRQHandler(void) {
    encoder_flag = 1;
    HAL_GPIO_EXTI_IRQHandler(GPIO_PIN_0);
}
```

**grep 감지:** `grep -rn "IRQHandler" --include="*.c" -A 20 | grep -E "printf\|delay\|HAL_I2C\|HAL_SPI\|HAL_UART_Transmit[^_]"`

---

### P09: 공유 변수 비원자 접근

ISR과 메인 루프가 volatile 없이 변수를 공유.

```c
// BAD
int32_t encoder_count = 0;
void TIM_IRQHandler(void) { encoder_count++; }
void main_loop() {
    int32_t pos = encoder_count;  // 32비트 읽기가 원자적이지 않을 수 있음
}

// GOOD
volatile int32_t encoder_count = 0;
void main_loop() {
    __disable_irq();
    int32_t pos = encoder_count;
    __enable_irq();
}
```

**grep 감지:** `grep -rn "IRQHandler" --include="*.c" -A 10 | grep -E "[a-z_]+\+\+|[a-z_]+\s*=" | grep -v "volatile"`

---

### P10: 인터럽트 우선순위 역전

낮은 우선순위 인터럽트가 높은 우선순위 태스크를 블로킹.

```c
// BAD — UART ISR(낮은 우선순위)가 긴 버퍼 복사 중
//        모터 제어 ISR(높은 우선순위)이 대기
void USART1_IRQHandler(void) {
    for (int i = 0; i < 256; i++)
        rx_buf[i] = USART1->DR;  // 오래 걸림
}

// GOOD — DMA 사용
HAL_UART_Receive_DMA(&huart1, rx_buf, 256);
```

**grep 감지:** `grep -rn "IRQHandler" --include="*.c" -A 15 | grep -E "for\s*\(|while\s*\(|memcpy"`

---

### P11: 인터럽트 비활성화 장시간 유지

Critical section이 너무 길어서 실시간성 파괴.

```c
// BAD
__disable_irq();
send_spi_data(large_buffer, 1024);  // 수 ms 소요
__enable_irq();

// GOOD — 최소한의 critical section
__disable_irq();
uint32_t local_copy = shared_var;
__enable_irq();
send_spi_data(buffer_from(local_copy), 1024);
```

**grep 감지:** `grep -rn "__disable_irq\|taskENTER_CRITICAL" --include="*.c" -A 20 | grep -E "send\|transmit\|write\|read\|SPI\|I2C\|UART"`

---

### P12: 인터럽트 재진입 미방지

동일 ISR이 처리 중 다시 트리거됨.

```c
// BAD — 외부 인터럽트에서 재진입 가능
void EXTI_IRQHandler(void) {
    process_event();  // 이 안에서 같은 인터럽트 재발생 가능
    __HAL_GPIO_EXTI_CLEAR_IT(pin);
}

// GOOD — 플래그 먼저 클리어, 재진입 방지
void EXTI_IRQHandler(void) {
    __HAL_GPIO_EXTI_CLEAR_IT(pin);
    if (processing) return;
    processing = 1;
    process_event();
    processing = 0;
}
```

**grep 감지:** `grep -rn "CLEAR_IT\|CLEAR_FLAG" --include="*.c" -B 5 | grep "IRQHandler" | grep -v "CLEAR"`

---

## 3. 메모리/자원 버그

### P13: 스택 오버플로우

재귀나 큰 로컬 배열이 스택을 초과.

```c
// BAD
void process_data(void) {
    float buffer[2048];  // 8KB 스택 사용 — FreeRTOS 기본 스택(1KB)초과
    for (int i = 0; i < 2048; i++)
        buffer[i] = read_adc();
}

// GOOD — static 또는 힙 할당
static float buffer[2048];  // BSS 세그먼트
void process_data(void) {
    for (int i = 0; i < 2048; i++)
        buffer[i] = read_adc();
}
```

**grep 감지:** `grep -rn "\(float\|double\|int32_t\|uint8_t\)\s\+[a-z_]*\[" --include="*.c" | grep -E "\[[0-9]{3,}\]"`

---

### P14: 힙 단편화

빈번한 malloc/free가 힙 단편화를 유발, 결국 할당 실패.

```c
// BAD
void periodic_task(void) {
    char *msg = malloc(64);
    sprintf(msg, "sensor: %d", val);
    send_uart(msg);
    free(msg);  // 매 주기 할당/해제 → 단편화
}

// GOOD — 정적 버퍼
void periodic_task(void) {
    static char msg[64];
    snprintf(msg, sizeof(msg), "sensor: %d", val);
    send_uart(msg);
}
```

**grep 감지:** `grep -rn "malloc\|calloc\|realloc\|new " --include="*.c" --include="*.cpp"`

---

### P15: malloc 반환값 미확인

임베디드에서 메모리 부족 시 NULL 반환을 무시.

```c
// BAD
float *data = (float *)malloc(n * sizeof(float));
data[0] = 1.0f;  // NULL이면 HardFault

// GOOD
float *data = (float *)malloc(n * sizeof(float));
if (data == NULL) {
    error_handler(ERR_MALLOC);
    return;
}
```

**grep 감지:** `grep -rn "malloc\|calloc" --include="*.c" -A 1 | grep -v "NULL\|null\|if\|assert"`

---

### P16: DMA 버퍼 캐시 불일치

DMA가 사용하는 버퍼를 CPU 캐시가 갱신하지 않아 오래된 데이터 읽음.

```c
// BAD — Cortex-M7 D-Cache 활성화 상태
uint8_t rx_buf[256];  // 캐시 가능 영역
HAL_UART_Receive_DMA(&huart, rx_buf, 256);
// rx_buf 읽으면 캐시의 오래된 값

// GOOD — 캐시 무효화 또는 비캐시 영역 사용
SCB_InvalidateDCache_by_Addr((uint32_t *)rx_buf, 256);
// 또는 MPU로 비캐시 영역 설정
```

**grep 감지:** `grep -rn "DMA" --include="*.c" | grep -v "InvalidateDCache\|CleanDCache\|__attribute__"`

---

### P17: 링 버퍼 경계 오류

인덱스 wrap-around에서 off-by-one 또는 full/empty 구분 실패.

```c
// BAD — full과 empty 구분 불가
typedef struct {
    uint8_t buf[256];
    uint8_t head, tail;  // 8비트 → 256 원소면 정확히 0으로 wrap
} RingBuf;
bool is_empty(RingBuf *rb) { return rb->head == rb->tail; }
bool is_full(RingBuf *rb) { return rb->head == rb->tail; }  // 같은 조건!

// GOOD — count 변수 별도 관리
typedef struct {
    uint8_t buf[256];
    volatile uint16_t head, tail, count;
} RingBuf;
bool is_full(RingBuf *rb) { return rb->count == 256; }
bool is_empty(RingBuf *rb) { return rb->count == 0; }
```

**grep 감지:** `grep -rn "head\s*==\s*tail" --include="*.c" --include="*.h"`

---

## 4. 동기화/동시성 버그

### P18: TOCTOU (Time-of-check to time-of-use)

확인과 사용 사이에 값이 변경될 수 있음.

```c
// BAD
if (motor_enabled) {           // 여기서 확인
    // ISR에서 motor_enabled = 0 될 수 있음
    set_motor_pwm(duty_cycle);  // 여기서 사용
}

// GOOD — 원자적 처리
__disable_irq();
bool enabled = motor_enabled;
if (enabled) set_motor_pwm(duty_cycle);
__enable_irq();
```

**grep 감지:** `grep -rn "if\s*(.*motor\|.*sensor\|.*flag" --include="*.c" -A 3 | grep "set_\|write_\|send_"`

---

### P19: 뮤텍스 없는 다중 태스크 접근

FreeRTOS 태스크 간 공유 구조체를 보호 없이 접근.

```c
// BAD
typedef struct { float x, y, theta; } Pose;
Pose robot_pose;  // 두 태스크가 동시 읽기/쓰기

// GOOD
SemaphoreHandle_t pose_mutex;
void update_pose(float x, float y, float th) {
    xSemaphoreTake(pose_mutex, portMAX_DELAY);
    robot_pose.x = x; robot_pose.y = y; robot_pose.theta = th;
    xSemaphoreGive(pose_mutex);
}
```

**grep 감지:** `grep -rn "typedef struct" --include="*.h" -A 5 | grep -v "mutex\|semaphore\|lock"`

---

### P20: 데드락 — 뮤텍스 획득 순서 불일치

태스크 A가 mutex1→mutex2, 태스크 B가 mutex2→mutex1 순서로 획득.

```c
// BAD
// Task A                          // Task B
xSemaphoreTake(motor_mtx, ...);   xSemaphoreTake(sensor_mtx, ...);
xSemaphoreTake(sensor_mtx, ...);  xSemaphoreTake(motor_mtx, ...);
// → 교차 대기 → 데드락

// GOOD — 항상 같은 순서
// Task A & B 모두: motor_mtx 먼저, sensor_mtx 나중
xSemaphoreTake(motor_mtx, ...);
xSemaphoreTake(sensor_mtx, ...);
```

**grep 감지:** `grep -rn "xSemaphoreTake" --include="*.c" -A 5 | grep "xSemaphoreTake"`

---

### P21: 큐 오버플로우 미처리

FreeRTOS 큐가 꽉 찼을 때 데이터 유실.

```c
// BAD
xQueueSend(cmd_queue, &cmd, 0);  // 즉시 반환, 실패 무시

// GOOD
if (xQueueSend(cmd_queue, &cmd, pdMS_TO_TICKS(10)) != pdPASS) {
    log_error("cmd queue full, dropping command %d", cmd.id);
    queue_overflow_count++;
}
```

**grep 감지:** `grep -rn "xQueueSend\|xQueueReceive" --include="*.c" | grep -v "pdPASS\|errQUEUE_FULL\|if\s*(" `

---

## 5. 수치/오버플로우 버그

### P22: 정수 오버플로우 (엔코더 카운트)

32비트 카운터가 고속 회전 시 오버플로우.

```c
// BAD
int32_t position = encoder_count * 360 / 4096;
// encoder_count = 1,000,000 이면 360,000,000 → 오버플로우 근접

// GOOD — 64비트 중간 연산
int32_t position = (int32_t)((int64_t)encoder_count * 360 / 4096);
```

**grep 감지:** `grep -rn "encoder.*\*\s*[0-9]" --include="*.c" --include="*.cpp"`

---

### P23: 부동소수점 비교

float == 비교는 거의 항상 잘못됨.

```c
// BAD
if (angle == 0.0f) { stop_motor(); }

// GOOD
if (fabsf(angle) < 1e-6f) { stop_motor(); }
```

**grep 감지:** `grep -rn "==\s*0\.0\|!=\s*0\.0\|==\s*[0-9]*\.[0-9]*f" --include="*.c" --include="*.cpp"`

---

### P24: 나누기 0 미검사

센서 값이 0일 때 나누기 발생.

```c
// BAD
float velocity = delta_pos / delta_time;  // delta_time == 0 → inf/NaN

// GOOD
float velocity = 0.0f;
if (fabsf(delta_time) > 1e-9f) {
    velocity = delta_pos / delta_time;
}
```

**grep 감지:** `grep -rn "/\s*delta\|/\s*dt\b\|/\s*period\|/\s*interval" --include="*.c" --include="*.cpp"`

---

### P25: 단위 혼동 (라디안 vs 도)

삼각 함수에 도(degree)를 넣으면 완전히 잘못된 결과.

```c
// BAD
float torque = K * sinf(angle_deg);  // sinf()는 라디안 입력

// GOOD
float torque = K * sinf(angle_deg * M_PI / 180.0f);
```

**grep 감지:** `grep -rn "sinf\|cosf\|tanf\|atan2f" --include="*.c" -B 3 | grep -i "deg\|degree"`

---

### P26: 누적 오차 (적분기 드리프트)

오일러 적분의 부동소수점 오차가 시간에 따라 누적.

```c
// BAD — 단순 오일러 적분
position += velocity * dt;  // dt가 작으면 velocity*dt도 작아 정밀도 손실

// GOOD — 보상 합산 (Kahan summation) 또는 주기적 리셋
static float compensation = 0.0f;
float y = velocity * dt - compensation;
float t = position + y;
compensation = (t - position) - y;
position = t;
```

**grep 감지:** `grep -rn "+= .*\* dt\|+= .*\* delta" --include="*.c" --include="*.cpp"`

---

## 6. 하드웨어 인터페이스 버그

### P27: GPIO 초기 상태 미설정

부팅 시 GPIO 기본 상태가 하이-Z → 모터 오동작 가능.

```c
// BAD — GPIO 설정 전 모터 드라이버 활성화
enable_motor_driver();
HAL_GPIO_Init(...);

// GOOD — GPIO 먼저 안전 상태로 설정
HAL_GPIO_WritePin(MOTOR_EN_PORT, MOTOR_EN_PIN, GPIO_PIN_RESET);
HAL_GPIO_Init(...);
// 초기화 완료 후에만 모터 활성화
```

**grep 감지:** `grep -rn "enable.*motor\|motor.*enable" --include="*.c" -B 5 | grep -v "GPIO_Init\|PinMode"`

---

### P28: ADC 읽기 순서 오류

멀티채널 ADC에서 채널 전환 후 첫 번째 읽기는 이전 채널 값.

```c
// BAD
HAL_ADC_ConfigChannel(&hadc, &ch_config);
HAL_ADC_Start(&hadc);
HAL_ADC_PollForConversion(&hadc, 10);
uint32_t value = HAL_ADC_GetValue(&hadc);  // 이전 채널의 잔류 값 가능

// GOOD — 더미 읽기 후 실제 읽기
HAL_ADC_ConfigChannel(&hadc, &ch_config);
HAL_ADC_Start(&hadc);
HAL_ADC_PollForConversion(&hadc, 10);
(void)HAL_ADC_GetValue(&hadc);  // 더미 읽기
HAL_ADC_Start(&hadc);
HAL_ADC_PollForConversion(&hadc, 10);
uint32_t value = HAL_ADC_GetValue(&hadc);  // 정확한 값
```

**grep 감지:** `grep -rn "ConfigChannel" --include="*.c" -A 5 | grep "GetValue" | grep -v "dummy\|discard"`

---

### P29: SPI/I2C 버스 경합

다중 태스크에서 동일 SPI 버스를 보호 없이 접근.

```c
// BAD — IMU와 Flash가 같은 SPI1 사용
void imu_task()  { HAL_SPI_Transmit(&hspi1, ...); }
void log_task()  { HAL_SPI_Transmit(&hspi1, ...); }

// GOOD
SemaphoreHandle_t spi1_mutex;
void imu_task() {
    xSemaphoreTake(spi1_mutex, portMAX_DELAY);
    HAL_SPI_Transmit(&hspi1, ...);
    xSemaphoreGive(spi1_mutex);
}
```

**grep 감지:** `grep -rn "HAL_SPI_Transmit\|HAL_I2C_Master" --include="*.c" | awk -F: '{print $1}' | sort | uniq -d`

---

### P30: PWM 주파수/해상도 불일치

타이머 설정이 원하는 PWM 해상도를 지원하지 않음.

```c
// BAD — 72MHz 클럭, Prescaler=72, ARR=100 → 10kHz PWM, 해상도 100단계만
// 16비트 서보 제어에 부족

// GOOD — 해상도 계산 확인
// 72MHz / 72 / 1000 = 1kHz PWM, 해상도 1000단계
// PWM_Resolution = Timer_Clock / (Prescaler * Frequency)
#define PWM_FREQ_HZ     1000
#define TIMER_CLOCK_HZ  72000000
#define PRESCALER        72
#define ARR_VALUE       (TIMER_CLOCK_HZ / PRESCALER / PWM_FREQ_HZ - 1)
_Static_assert(ARR_VALUE >= 999, "PWM resolution too low");
```

**grep 감지:** `grep -rn "TIM_.*Prescaler\|\.Prescaler\s*=" --include="*.c" --include="*.h"`

---

## 7. 상태 머신 버그

### P31: 기본 케이스 누락

switch 문에서 default 없이 예외 상태 미처리.

```c
// BAD
switch (robot_state) {
    case IDLE:   handle_idle();   break;
    case RUN:    handle_run();    break;
    case FAULT:  handle_fault();  break;
    // 새 상태 추가 시 여기 빠뜨리면 무동작
}

// GOOD
switch (robot_state) {
    case IDLE:   handle_idle();   break;
    case RUN:    handle_run();    break;
    case FAULT:  handle_fault();  break;
    default:
        log_error("unknown state: %d", robot_state);
        enter_safe_state();
        break;
}
```

**grep 감지:** `grep -rn "switch\s*(.*state" --include="*.c" -A 30 | grep -c "default:" | grep "^0$"`

---

### P32: 상태 전이 검증 누락

어떤 상태에서든 다른 어떤 상태로든 전이 가능 → 위험한 상태 천이.

```c
// BAD
void set_state(State new_state) {
    current_state = new_state;  // 아무 검증 없이 전이
}

// GOOD — 전이 테이블 기반 검증
static const bool valid_transitions[STATE_MAX][STATE_MAX] = {
    [IDLE][RUN] = true, [RUN][IDLE] = true,
    [RUN][FAULT] = true, [FAULT][IDLE] = true,
};
bool set_state(State new_state) {
    if (!valid_transitions[current_state][new_state]) {
        log_error("invalid transition: %d -> %d", current_state, new_state);
        return false;
    }
    current_state = new_state;
    return true;
}
```

**grep 감지:** `grep -rn "state\s*=\s*" --include="*.c" | grep -v "valid_transition\|transition_table\|if\s*(" `

---

### P33: 비상 정지 후 자동 재시작

E-Stop 해제 후 확인 없이 자동으로 모터 재가동.

```c
// BAD
void estop_handler(void) {
    disable_all_motors();
    current_state = ESTOP;
}
void main_loop(void) {
    if (current_state == ESTOP && !estop_active()) {
        current_state = RUN;  // 자동 재시작 → 위험!
    }
}

// GOOD — 수동 확인 필요
void main_loop(void) {
    if (current_state == ESTOP && !estop_active()) {
        current_state = ESTOP_RELEASED;
        // 오퍼레이터가 RESET 버튼을 눌러야 RUN으로 전이
    }
}
```

**grep 감지:** `grep -rn "estop\|e_stop\|emergency" --include="*.c" -A 10 | grep -i "RUN\|start\|enable\|resume"`

---

### P34: Watchdog feed가 상태와 무관

모든 상태에서 무조건 watchdog를 갱신하면, 장시간 FAULT 상태도 리셋 안 됨.

```c
// BAD
while (1) {
    state_machine();
    HAL_IWDG_Refresh(&hiwdg);  // FAULT 상태에서도 갱신 → 영원히 FAULT
}

// GOOD — 정상 상태에서만 갱신
while (1) {
    state_machine();
    if (current_state != FAULT && current_state != ESTOP) {
        HAL_IWDG_Refresh(&hiwdg);
    }
    // FAULT 유지 → watchdog timeout → 시스템 리셋
}
```

**grep 감지:** `grep -rn "IWDG_Refresh\|WDT_Feed\|wdt_reset" --include="*.c" -B 5 | grep -v "if\|state\|fault"`

---

## 빠른 참조 — 전체 grep 감지 명령

```bash
# 전체 스캔 (프로젝트 루트에서 실행)
echo "=== P01: delay() 기반 타이밍 ==="
grep -rn "delay(" --include="*.c" --include="*.cpp" | grep -v "DelayUntil\|delay_until"

echo "=== P09: volatile 없는 ISR 공유 변수 ==="
grep -rn "IRQHandler" --include="*.c" -A 10 | grep -E "[a-z_]+\+\+|[a-z_]+ *=" | grep -v "volatile"

echo "=== P14: 동적 메모리 할당 ==="
grep -rn "malloc\|calloc\|realloc" --include="*.c" --include="*.cpp"

echo "=== P23: float 비교 ==="
grep -rn "==\s*0\.0\|!=\s*0\.0" --include="*.c" --include="*.cpp"

echo "=== P24: 나누기 0 위험 ==="
grep -rn "/\s*delta\|/\s*dt\b\|/\s*period" --include="*.c" --include="*.cpp"

echo "=== P33: 비상 정지 후 자동 재시작 ==="
grep -rn "estop\|e_stop\|emergency" --include="*.c" -A 10 | grep -i "RUN\|start\|enable"
```

---

## 심각도 등급

| 등급 | 패턴 | 영향 |
|------|-------|------|
| CRITICAL | P07, P09, P13, P15, P24, P27, P33 | 시스템 크래시/물리적 위험 |
| HIGH | P01, P04, P08, P11, P18, P22, P29, P32, P34 | 제어 품질 저하/간헐적 오류 |
| MEDIUM | P02, P03, P10, P14, P16, P17, P19-21, P23, P25-26, P28, P30-31 | 잠재적 오류/유지보수 부담 |
| LOW | P05, P06, P12 | 성능 최적화 |
