---
name: skiro-retro
description: |
  Post-experiment retrospective: summarize what happened, analyze problems,
  extract lessons learned, and format results for papers. Use AFTER an
  experiment is done — NOT for designing experiments (/skiro-spec) or
  analyzing raw data (/skiro-analyze).
  Keywords (EN/KR): retrospective/회고, retro, what went wrong/뭐가 잘못됐는지,
  lessons learned/교훈, 실험 결과 정리, paper data/논문 데이터,
  실험 요약, 문제점 분석, 개선점. (skiro)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

Read VOICE.md before responding.

## Phase 0: Context
Load protocol, session history, ALL learnings.

## Phase 1: Data Inventory
Ask which experiment. Check data completeness.
Report: subjects, conditions, trials, missing data, quality.

## Phase 2: What Happened (one at a time)
1. Main results? Numbers.
2. What went wrong? HW issues, SW bugs, protocol deviations.
3. What surprised you?

## Phase 3: Problem Analysis
For each problem: root cause, impact, prevention, priority.
Log each as a learning via skiro-learnings add.

## Phase 4: Retrospective Document
Write docs/retro_{date}.md with:
Summary, results, problems table, lessons, action items, paper-ready data.

## Phase 5: GitHub Issues (optional)
Offer to create issues for action items.

## Phase 6: Paper Connection
Format key stats for IEEE/JNER LaTeX.
Suggest figure descriptions and BibTeX keys.

## Phase 7: Session Save + Sync Reminder
Save session. Remind: git add -A && git commit && git push
Next: /skiro-spec for next experiment.
