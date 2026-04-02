---
name: skiro-plan
description: |
  Design and plan experiment protocols before running experiments.
  Defines conditions, independent/dependent variables, sample size,
  data collection plan, safety criteria, and statistical analysis plan.
  For experiment PLANNING only — NOT for data analysis, retrospectives,
  or running experiments.
  Keywords (EN/KR): experiment design/실험 설계, protocol/프로토콜,
  test plan/테스트 플랜, 실험 계획, 실험 조건, 독립변수, 종속변수,
  sample size/표본 크기, 랜덤화, 반복 횟수, 피험자. (skiro)
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
Read README.md, CLAUDE.md, existing protocols in docs/.
Load experiment-related learnings.

## Phase 1: Research Question (one at a time)
Ask specific research question via AskUserQuestion.
Push for specificity: "Does the robot help?" is too vague.

## Phase 2: Experimental Design (one question at a time)
1. Experimental conditions?
2. What are you measuring? Primary/secondary outcomes.
3. Participants/test objects? Criteria.
4. Sensors and frequencies? Cross-ref hardware.yaml.
5. Safety stopping criteria?
Smart-skip if already answered.

## Phase 3: Related Work Search (optional)
Offer to search for related experimental protocols.

## Phase 4: Protocol Document
Write to docs/protocol_{date}_{title}.md with full structure:
Research question, design, participants, outcomes, data collection,
procedure, safety, statistical analysis, data naming convention.
AskUserQuestion: A) Approve B) Revise C) Start over

## Phase 5: Next Step
Approved -> /skiro-safety to verify code
