---
name: skiro-spec
description: |
  Design experiment protocols. Conditions, variables, data collection,
  safety, statistics. Manual invocation only.
  Keywords: experiment design, protocol, test plan, data collection. (skiro)
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
