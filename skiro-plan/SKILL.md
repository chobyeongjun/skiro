---
name: skiro-plan
description: |
  Research planning and brainstorming for robot experiments. Covers the
  full planning pipeline: idea brainstorming, research direction exploration,
  related work search, experiment design, protocol writing, expected results
  prediction, statistical analysis planning, and paper structure outline.
  Use for ANY planning/ideation — from vague "어떤 실험 하지?" to specific
  protocol writing. NOT for running analysis (/skiro-analyze), writing
  papers (/skiro-retro), or managing data (/skiro-data).
  Keywords (EN/KR): plan/계획, brainstorm/브레인스토밍, idea/아이디어,
  experiment design/실험 설계, protocol/프로토콜, research question/연구 질문,
  hypothesis/가설, 어떤 실험, 뭐 하지, 연구 방향, 실험 계획,
  실험 조건, 독립변수, 종속변수, sample size/표본 크기, 예상 결과,
  논문 구조, 연구 목표. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Context

1. Read hardware.yaml — 어떤 장비가 있는지 파악.
2. Read existing protocols in docs/ — 이전 실험 있는지 확인.
3. Load learnings for "experiment", "plan", "protocol" tags.
4. Scan project files to understand current state:
   ```bash
   ls docs/protocol_*.md docs/retro_*.md 2>/dev/null
   ```

## Phase 1: Planning Scope

사용자 요청의 구체성에 따라 진입점이 다름:

AskUserQuestion: "어떤 수준의 계획이 필요한가요?"
A) **아이디어 탐색** — "뭘 해야 할지 모르겠어" → Phase 2부터
B) **연구 방향 구체화** — "대략 이런 걸 하고 싶은데" → Phase 3부터
C) **실험 설계** — "이 실험을 하려는데 프로토콜 짜줘" → Phase 5부터
D) **전체 다** — 아이디어부터 논문 구조까지 → Phase 2부터 순서대로

사용자가 이미 구체적인 요청을 했으면 스킵하고 해당 Phase로 직행.

## Phase 2: Brainstorming (아이디어 탐색)

현재 장비, 기술, 연구 분야를 기반으로 가능한 연구 방향 탐색.

### 2-1. 현재 자원 파악
hardware.yaml과 프로젝트 코드에서:
- 어떤 로봇/장비가 있는지
- 어떤 센서가 달려있는지
- 어떤 제어 방식을 쓰고 있는지
- 이전 실험에서 뭘 했는지 (retro 문서 참조)

### 2-2. 연구 방향 제안
3~5개 연구 방향을 제안. 각각:
- **연구 질문**: 한 문장
- **왜 중요한지**: 임상적/공학적 의의
- **실현 가능성**: 현재 장비로 가능한지
- **예상 기간**: 데이터 수집 + 분석
- **관련 키워드**: 논문 검색용

```
=== 연구 방향 제안 ===
1. [방향명]
   질문: ...
   의의: ...
   가능성: ⭐⭐⭐⭐ (현재 장비로 바로 가능)
   기간: ~2주
   
2. [방향명]
   ...
```

AskUserQuestion: "어떤 방향이 끌리나요? 수정/조합도 가능합니다."

### 2-3. 선택된 방향 심화
선택된 방향에 대해:
- 기존 연구에서 뭘 했고 뭐가 부족한지 (gap analysis)
- 우리가 기여할 수 있는 포인트
- 예상되는 어려움/리스크

## Phase 3: Research Direction (연구 방향 구체화)

### 3-1. Research Question 정제
모호한 질문을 논문에 쓸 수 있는 수준으로 구체화.

```
❌ "로봇이 도움이 되는가?"
❌ "보행이 좋아지는가?"
✅ "하지 외골격의 능동 보조가 편마비 환자의 보행 대칭성(Symmetry Index)을 
   개선하는가? (Assist ON vs OFF, within-subject)"
```

규칙:
- **독립변수**(조작하는 것)가 명확해야 함
- **종속변수**(측정하는 것)가 구체적이어야 함
- **대상**(누구에게)이 정의되어야 함
- **비교 방법**(무엇과 비교)이 있어야 함

AskUserQuestion으로 하나씩 구체화. 한번에 다 묻지 않음.

### 3-2. Hypothesis (가설)
Research question에서 가설 도출:
- H₀ (귀무가설): "차이가 없다"
- H₁ (대립가설): "차이가 있다" + 방향 (우리가 기대하는 결과)

### 3-3. Related Work Search
WebSearch로 관련 논문 검색:
- 비슷한 장비로 비슷한 실험을 한 논문
- 사용된 메트릭, sample size, 통계 방법
- 우리 연구와의 차별점

```
검색 키워드: "{로봇 종류} {실험 유형} {메트릭}" 
예: "lower limb exoskeleton gait symmetry stroke"
```

핵심 논문 2~3개 요약 제공 (저자, 년도, 방법, 결과, 한계).

## Phase 4: Expected Results (예상 결과)

실험 전에 "이런 결과가 나올 것"을 미리 그려봄.

### 4-1. 예상 데이터 패턴
- 어떤 메트릭이 어떻게 변할지
- 효과 크기 예상 (관련 논문 참고)
- 예상되는 문제점 (학습 효과, 피로, 순서 효과)

### 4-2. Power Analysis (표본 크기 결정)
```python
# 예상 효과 크기와 power로 필요한 n 계산
from scipy import stats
# Cohen's d = 0.5 (medium), alpha = 0.05, power = 0.8
# → paired t-test: n ≈ 34
# → independent t-test: n ≈ 64 per group
```

관련 논문의 효과 크기를 참고하여 현실적인 n 제안.

### 4-3. 논문 Figure 미리 스케치
"이런 그래프가 나올 것" 텍스트로 설명:
```
예상 Fig 1: GCP-normalized force profile
  - X: 0-100% GCP, Y: Force (N)
  - Assist ON: 피크 낮아지고 smooth
  - Assist OFF: 피크 높고 변동 큼
  - 의미: 보조 시 힘 부담 감소

예상 Fig 2: Temporal-spatial bar chart
  - Stride time: 두 조건 비슷 (p > 0.05 예상)
  - Symmetry Index: Assist ON에서 감소 (p < 0.05 예상)
```

## Phase 5: Experiment Design (실험 설계)

### 5-1. 실험 구조
AskUserQuestion (하나씩):
1. **실험 설계**: within-subject / between-subject / crossover?
2. **조건**: 몇 개, 이름, 순서 (랜덤화?)
3. **측정 변수**: primary outcome, secondary outcomes
4. **피험자/대상**: 포함 기준, 제외 기준, 몇 명
5. **센서 + 샘플링**: hardware.yaml 참조
6. **안전 중지 기준**: 어떤 상황에서 실험 중단

이미 답변된 항목은 스킵.

### 5-2. 실험 절차 (Timeline)
```
실험 당일 순서:
1. 동의서 + 인구통계 수집 (5분)
2. 장비 착용 + 캘리브레이션 (10분)
3. 연습 보행 (2분)
4. Baseline 측정 — 조건 없음 (3분)
5. 조건 A — 3회 반복 (15분)
6. 휴식 (5분)
7. 조건 B — 3회 반복 (15분)
8. 장비 제거 + 설문 (5분)
총 ~60분
```

### 5-3. 데이터 수집 계획
- 파일 이름 규칙: `YYMMDD_SXX_CondName_TN.csv`
- 저장 위치: SD카드 + 실시간 BLE 백업
- 채널 목록 (hardware.yaml에서)
- 샘플링 주파수

### 5-4. 통계 분석 계획 (사전 등록용)
- Primary outcome → 어떤 테스트 (paired t-test? Wilcoxon?)
- Secondary outcomes → 다중 비교 보정 (Bonferroni?)
- 유의 수준: α = 0.05
- 효과 크기 보고: Cohen's d

## Phase 6: Paper Structure Outline (논문 구조)

실험 시작 전에 논문 뼈대를 미리 잡아둠.

### 6-1. 논문 구조 초안
```
Title: [working title]
Target Journal: [IEEE/JNER/Gait & Posture/Sensors/ICRA]

Abstract: [1줄 요약 — 실험 후 작성]

1. Introduction
   - 배경: [연구 분야 + 문제점]
   - 관련 연구: [2-3개 핵심 논문 + gap]
   - 목적: [research question 재진술]

2. Methods
   - 2.1 장치: [로봇/장비 설명]
   - 2.2 참가자: [n명, demographics]
   - 2.3 프로토콜: [Phase 5에서 작성한 절차]
   - 2.4 데이터 분석: [메트릭 + 통계 방법]

3. Results
   - Fig 1: [Phase 4에서 예상한 figure]
   - Fig 2: [...]
   - Table 1: [temporal-spatial parameters]

4. Discussion
   - 주요 발견
   - 관련 연구와 비교
   - 한계점
   - 임상적/공학적 의의

5. Conclusion
```

### 6-2. 예상 기여점 (Contribution Statement)
이 논문이 기존 연구 대비 뭐가 새로운지 1-3줄.

## Phase 7: Protocol Document 생성

위 모든 내용을 `docs/plan_{date}_{title}.md`에 정리:
- Research question + hypothesis
- Experiment design + timeline
- Data collection plan
- Statistical analysis plan
- Paper structure outline
- 예상 결과 + figure 스케치

AskUserQuestion: "계획서가 완성되었습니다."
A) 승인 → 다음 단계로
B) 수정 필요
C) 처음부터 다시

## Phase 8: Next Step

계획 완료 후 워크플로우:
- 코드 준비 → /skiro-safety (안전 검증)
- 펌웨어 수정 → /skiro-flash
- 통신 설정 → /skiro-comm
- GUI 필요 → /skiro-gui
- 바로 실험 → 데이터 수집 후 /skiro-data
