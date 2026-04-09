# CHECKLIST.md — skiro v0.5 MS4
# MS3 이관 + MS4 추가 항목

## [SAFETY] ISR 안전

- [ ] ISR 내 malloc/free/new/delete 없음
- [ ] ISR 내 HAL_Delay/vTaskDelay/usleep 없음
- [ ] ISR 내 printf/fprintf/std::cout 없음
- [ ] 모든 ISR 핸들러는 `void` 반환, `void` 인자 형태
- [ ] ISR 간 공유 변수: volatile 선언 확인
- [ ] ISR → main 공유 접근: __disable_irq() 또는 taskENTER_CRITICAL() 보호
- [ ] 64비트(double, int64_t) 전역 변수의 ISR 공유: 2-step 비원자성 주의
- [ ] NVIC 우선순위: 안전 비상정지(0) > CAN(1) > TIM제어(2) > UART(3)

## [SAFETY] 모터/액추에이터

- [ ] 전류 상한 변수 선언: MAX_CURRENT, I_MAX, current_limit 등
- [ ] 토크 상한 변수 선언: MAX_TORQUE, tau_max 등
- [ ] 속도 상한 변수 선언: MAX_VEL, vel_limit 등
- [ ] enable_motor() 전 safety gate 확인
- [ ] 비상 정지 함수 존재: emergency_stop_all() 또는 등가
- [ ] 모터 enable/disable/zero 명령 구현 완료
- [ ] 하드코딩 수치로 직접 set_current(5.0) 형태 없음

## [SAFETY] CAN 통신

- [ ] CAN 타임아웃 처리: last_rx_tick 기반 250ms watchdog
- [ ] CAN 에러 콜백 구현: HAL_CAN_ErrorCallback
- [ ] 버스 종단저항: 양 끝 120Ω
- [ ] CAN ID 충돌 없음 (모터별 고유 ID)
- [ ] 타임아웃 발생 시 비상 정지 연결

## [SAFETY] 코드 검토 게이트

- [ ] .skiro_safety_gate 생성 전 CRITICAL 0개 확인
- [ ] skiro-hwtest 실행 전 .skiro_safety_gate 존재 확인
- [ ] skiro-flash 실행 전 .skiro_safety_gate 존재 확인
- [ ] flash 후 UART/시리얼 출력으로 초기화 확인

## [CONTROL] 임피던스/어드미턴스

- [ ] 게인 파라미터(Kp, Kd) 초기값 보수적으로 설정
- [ ] 토크 포화 처리: if(tau > MAX) tau = MAX
- [ ] Tustin 이산화 사용 (Forward Euler 지양)
- [ ] 제어 루프 실행 시간 측정 코드 존재
- [ ] 실행 시간 > 주기 80% → WARNING 처리

## [CONTROL] ILC

- [ ] 학습률(L): 0 < L < 1 범위 확인
- [ ] 망각 인자(γ): 0.95–1.0 범위
- [ ] 피드포워드 포화: u_ff ∈ [-MAX_TORQUE, MAX_TORQUE]
- [ ] stride 완료 감지 로직 검증

## [COMM] CAN 패킷

- [ ] AK60-6 MIT 모드 패킷 구조 준수 (8바이트)
- [ ] float_to_uint / uint_to_float 변환 함수 정확도 확인
- [ ] 모터별 enable → zero → control 순서 준수

## [DATA] 로깅

- [ ] 파일명: YYYYMMDD_HHMMSS 형식
- [ ] 헤더 1회 작성 후 루프에서 추가
- [ ] 주기적 f_sync() 호출 (100회마다)
- [ ] 실험 종료 시 f_close() 확인

## [MS4] 모듈화 라우팅

- [ ] skiro-complexity 실행 후 tier 확인
- [ ] tier에 따른 phase 파일 Read 완료 후 분석 시작
- [ ] 파일 없음/오류 시 tier=full fallback 적용
- [ ] eval: run-all-ms4.sh ALL PASS 유지

## [PROCESS] 세션 관리

- [ ] 세션 시작: learnings list --last 5 확인
- [ ] current-experiment.json status 체인: planned → safety_checked → flashed/completed
- [ ] 세션 종료: skiro-retro 실행 + learnings 1개 이상 저장
- [ ] promote: 3회 이상 반복 패턴 → CHECKLIST.md 추가
