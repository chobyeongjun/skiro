# p3-fork.md — Phase 3: Fork Agent 분석
# skiro-safety | partial: §A only | full: §A + §B | ~1420 tok

## 목적
Phase 2를 통과한 코드에 대해 specialist 관점의 심층 분석을 수행한다.
grep으로 잡히지 않는 **원리적 이슈** (타이밍, 선점 관계, 없는 코드)를 탐지한다.

---

## §A — 단독 코드 심층 분석 (partial/full 공통)

### A-1. ISR 간 데이터 레이스 분석

**분석 방법**: 모든 ISR 핸들러 목록을 추출하고, 각 ISR이 읽고 쓰는 전역 변수를 매핑한다.

```
ISR_A: 쓰기 {x, y}  읽기 {z}
ISR_B: 쓰기 {z}     읽기 {x}
→ x는 ISR_A(쓰기)와 ISR_B(읽기) 간 레이스 → CRITICAL
```

**확인 항목**:
- [ ] ISR 간 공유 변수: volatile 선언 여부
- [ ] ISR → main 방향 공유: `__disable_irq()` / `taskENTER_CRITICAL()` 보호 여부
- [ ] main → ISR 방향 쓰기: atomic 연산 또는 critical section 여부
- [ ] 64비트 변수(double, int64_t) 비원자적 읽기/쓰기 (Cortex-M4 = 32bit bus)

**Cortex-M4 특수 규칙**:
```
double/int64_t의 읽기·쓰기는 2회 버스 트랜잭션 = 비원자적.
ISR와 main이 동일 double 공유 시: ISR 접근 전후 __disable_irq() 필수.
대안: float + union trick 또는 별도 32bit 변수 2개로 분리.
```

---

### A-2. 선점 관계 분석 (NVIC 우선순위)

**목적**: 높은 우선순위 ISR이 낮은 우선순위 ISR을 선점할 때 발생하는 이슈 탐지.

**분석 절차**:
1. `HAL_NVIC_SetPriority()` 호출 목록 추출 → 우선순위 맵 작성
2. 같은 리소스(변수, 하드웨어 레지스터)에 접근하는 ISR 쌍 식별
3. 높은 우선순위가 낮은 우선순위 실행 중 선점 → 보호 여부 확인

**확인 항목**:
- [ ] SysTick(Cortex 최고 우선순위)이 접근하는 공유 변수
- [ ] TIM ISR < CAN ISR 우선순위인데 CAN ISR에서 TIM 관련 변수 수정
- [ ] `__disable_irq()`로 모든 ISR 막는 구간의 최대 길이 (>10μs = WARNING)

**H-Walker 기준 우선순위 매핑**:
```
Priority 0 (최고): 안전 비상정지
Priority 1:        CAN TX/RX (모터 명령)
Priority 2:        TIM 제어 루프 (111Hz impedance)
Priority 3:        UART 디버그
Priority 15 (최저): SysTick HAL tick
```
기준에서 벗어난 설정 = WARNING.

---

### A-3. 없는 코드 탐지 (Structural Gap Analysis)

Phase 1의 MUST-EXIST에서 잡힌 MISSING 항목에 대해 구조적 대안이 있는지 확인한다.

```
질문 1: 전류 상한이 코드에 없는데, 하드웨어 OCP가 있는가?
  → AK60-6은 내부 OCP 있음 → WARNING 유지 (CRITICAL 해제 가능)
  → 없음 → CRITICAL 유지

질문 2: 비상 정지가 없는데, 워치독이 있는가?
  → IWDG 설정 확인 → 있으면 WARNING, 없으면 CRITICAL

질문 3: CAN 타임아웃이 없는데, 모터가 자체 타임아웃을 갖는가?
  → AK60-6 기본 250ms watchdog → WARNING으로 격하 가능
```

---

### A-4. 타이밍 분석 (제어 루프)

제어 루프 주기 일관성 분석.

**확인 항목**:
- [ ] 제어 루프 실행 시간 측정 코드 존재 여부 (`DWT->CYCCNT` 또는 TIM capture)
- [ ] 루프 내 최악 실행 시간 > 주기의 80% → WARNING (jitter 위험)
- [ ] HAL_Delay / vTaskDelay가 제어 루프 내부에 있으면 CRITICAL

**H-Walker 기준**:
```
impedance loop: 111Hz → 9ms 주기, 실행 < 7ms
ILC update:     stride-to-stride → 비동기, 주기 무관
CAN TX:         1kHz → 1ms 주기, 실행 < 0.5ms
```

---

## §B — 멀티 에이전트 Fork 분석 (full only, score ≥ 80)

### B-1. Fork 구성

코드 복잡도가 full tier인 경우, 분석을 전문 에이전트로 분기한다.

```
메인 에이전트 (coordinator):
  - Phase 1–2 결과 수집
  - §A 결과 수집
  - §B 에이전트 할당 및 merge

전문 에이전트 A — ISR/타이밍 specialist:
  - A-1 (데이터 레이스) + A-2 (선점) 전담
  - grep 패턴: ISR_PATTERNS 사용

전문 에이전트 B — 제어 알고리즘 specialist:
  - A-3 (structural gap) + A-4 (타이밍) 전담
  - 제어 이론 관점 (안정성, 수렴 조건)

전문 에이전트 C — 하드웨어 인터페이스 specialist:
  - CAN/UART/SPI 프로토콜 정확성
  - 레지스터 설정값 검증 (클럭, 보레이트, DMA 채널 충돌)
```

### B-2. 에이전트별 그랩 패턴

**에이전트 A — ISR/타이밍**:
```bash
grep -n "IRQHandler\|__disable_irq\|portDISABLE\|NVIC_SetPriority\|volatile" <file>
grep -n "double\s\+g_\|int64_t\s\+g_" <file>   # 비원자적 64bit 전역
```

**에이전트 B — 제어 알고리즘**:
```bash
grep -n "Kp\|Ki\|Kd\|gain\|stiffness\|damping\|admittance\|impedance" <file>
grep -n "inv\s*(\|det\s*(\|eig\s*(" <file>   # 수치 불안정 연산
grep -n "for.*stride\|ILC\|iterative" <file>
```

**에이전트 C — 하드웨어 인터페이스**:
```bash
grep -n "HAL_CAN\|CAN_TxHeader\|CAN_RxHeader\|hcan" <file>
grep -n "HAL_UART\|huart\|baud" <file>
grep -n "HAL_DMA\|DMA_HandleTypeDef\|hdma" <file>
```

### B-3. 에이전트 실행 가이드라인

- 각 에이전트는 독립적으로 분석하고 결과를 [AGENT_X] 태그로 반환한다.
- 에이전트 간 공유 파일 없음: 각자 원본 코드에서 직접 분석.
- merge 우선순위: CRITICAL > WARNING > OK (더 심각한 판정 우선)
- 이견 발생 시 coordinator가 컨텍스트 기반 최종 판정.

### B-4. Merge 결과 양식

```
[FORK MERGE] Phase 3 완료
  에이전트 A (ISR): CRITICAL <N>개, WARNING <M>개
  에이전트 B (제어): CRITICAL <K>개, WARNING <L>개
  에이전트 C (HW):  CRITICAL <P>개, WARNING <Q>개
  중복 제거 후: CRITICAL <총>, WARNING <총>
  → Phase 4로 전달
```
