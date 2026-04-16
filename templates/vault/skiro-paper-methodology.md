---
title: AI 활용 논문 작성 방법론
created: 2026-04-16
updated: 2026-04-16
sources: [The AI Scientist (Nature 651, 2026), skiro COWORK]
tags: [paper, methodology, ai-scientist, workflow, skiro]
summary: The AI Scientist의 4-phase 워크플로우를 skiro COWORK에 맞춰 적용하는 방법
confidence_score: 0.95
---

# [[AI 활용 논문 작성 방법론]]

The AI Scientist (Lu et al., Nature 2026)의 end-to-end 자동 연구 파이프라인을
skiro COWORK 환경에 맞춰 적용한 방법론.

## 4-Phase 워크플로우

### Phase 1: Ideation (아이디어 + 구조 설계)

**AI Scientist**: LLM이 연구 방향 제안 → Semantic Scholar로 novelty 검증 → 아이디어 archive 유지
**skiro 적용**:

```
1. cowork_scan_experiments(project_path)     → 기존 실험 전체 파악
2. cowork_get_learnings(format="paper")      → 방법론 변경 이력 (왜 바꿨나?)
3. skiro_vault_search(folder:"Decisions")    → 과거 설계 결정 참조
4. Claude가 연구 내러티브 추출:
   - 어떤 문제를 풀었나
   - 어떤 방법을 시도했나 (+ 실패한 것들)
   - 핵심 기여가 무엇인가
5. cowork_paper_state(action="set") → 구조 저장
6. cowork_paper_check() → 검증
```

**핵심**: 단순히 "논문 써줘"가 아니라, 기존 데이터에서 narrative를 자동 추출.
learnings에 기록된 문제→해결 이력이 곧 Methods 섹션의 근거가 된다.

### Phase 2: Experimentation (실험 + 데이터 축적)

**AI Scientist**: 4단계 tree search
1. Preliminary investigation
2. Hyperparameter tuning
3. Research agenda execution
4. Ablation studies

**skiro 적용** (Claude Code에서):

```
각 실험 단계마다:
  - 코드 작성/실행 → skiro_record_problem/solution으로 이슈 추적
  - 실험 완료 → skiro_archive_experiment(name, source_dir, description)
    → ~/research/experiments/{name}/raw/ 에 보존
  - 결과 기록 → skiro_vault_write()로 vault에 정리
  - 중요 figure → skiro_save_artifact(category="figure")
```

**3-tier 데이터 관리**:
- `raw/` — 실험 전체 데이터 (archive_experiment이 자동 생성)
- `ppt/` — 발표용 선별 (cowork_promote_data)
- `paper/` — 출판용 최종 (cowork_promote_data)

### Phase 3: Write-up (논문 작성)

**AI Scientist**: 실험 log + plot → LaTeX 템플릿 채우기 → Semantic Scholar로 reference 수집
**skiro 적용** (COWORK에서):

```
섹션별 순서:
1. cowork_paper_state(action="get") → 현재 구조 확인
2. cowork_paper_data(section="methods") → 해당 섹션 데이터만 추출
3. vault_read(note, section) → 기술 배경 부분 로드
4. Claude가 해당 섹션 초안 작성
5. cowork_paper_state(action="update") → 진행률 갱신
```

**섹션별 데이터 소스**:
| Section | 데이터 소스 | skiro 도구 |
|---------|-----------|-----------|
| Introduction | git 통계, 기술 영역 | paper_data(section="introduction") |
| Methods | 문제→해결 이력, 방법론 변경 | paper_data(section="methods") + vault |
| Results | figure 목록, 데이터 파일, 이슈 통계 | paper_data(section="results") |
| Discussion | 미해결 이슈, 반복 문제, 교훈 | paper_data(section="discussion") |

### Phase 4: Review (자기 검증)

**AI Scientist**: Automated Reviewer (NeurIPS 기준, ensemble 5회 리뷰 → meta-review)
**skiro 적용**:

```
1. cowork_paper_check(paper_id, project_path) → 구조적 일관성 검증
   - 참조된 실험 존재 여부
   - key_figures 등록 여부
   - completion_pct vs 실제 section status
   - 미해결 high-priority gap
2. Claude가 각 섹션을 비판적으로 리뷰
3. gap이 있으면 → Phase 2로 돌아가서 추가 실험
```

## The AI Scientist와 skiro의 차이

| | AI Scientist | skiro COWORK |
|--|-------------|-------------|
| 목표 | 완전 자동 논문 생성 | 인간-AI 협업 논문 작성 |
| 실험 | 자동 코드 실행 | Code MCP에서 인간과 함께 |
| Figure | 자동 plot | PaperBanana 등 외부 도구 + artifact 등록 |
| Reference | Semantic Scholar API | 인간이 선택 |
| Review | Automated Reviewer (5회 ensemble) | paper_check + Claude 리뷰 + 인간 판단 |
| 상태 관리 | 메모리 내 | paper_state (파일 영속, 세션 간 연속) |

## 핵심 원칙

1. **데이터 먼저, 작성 나중**: 실험 데이터가 충분히 쌓이기 전에 논문 구조를 먼저 설계
2. **Methods는 learnings에서**: problem→solution 이력이 곧 방법론 변경 근거
3. **증분 업데이트**: 전체 재설계 금지. 새 실험 추가 시 해당 섹션만 update
4. **부분 로드**: vault/데이터 전체 로드 절대 금지. 섹션 단위만
5. **검증 후 진행**: 매 state 변경 후 paper_check 실행
6. **Figure는 독립**: 어떤 도구로 만들든, artifact 등록만 하면 paper_check가 인식
