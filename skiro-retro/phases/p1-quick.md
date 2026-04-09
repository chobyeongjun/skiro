# p1-quick.md — 빠른 회고 템플릿
# skiro-retro | always load | ~380 tok

## 5분 회고 (모든 세션 공통)

### 완료한 것
- 계획 대비 달성률: N%
- 실제로 완료된 항목 목록

### 안 된 것
- 미완료 항목과 이유 (시간/기술/장비/환경)

### 발견한 것
- 예상 밖의 동작, 버그, 인사이트
- "이게 왜 됐지?" or "이게 왜 안 됐지?" 케이스

### 다음 세션 첫 번째 할 일
- 구체적으로 1가지만

---

## learnings JSONL 저장 (최소 1개)

회고마다 최소 1개의 교훈을 저장한다. 없으면 "재확인된 것"이라도.

```bash
skiro-learnings add \
  --category <범주> \
  --severity <INFO|WARNING|CRITICAL> \
  --lesson "<한 줄 교훈>" \
  --context "<파일명 또는 작업명>"
```

범주 목록: safety / control / hardware / software / protocol / process / experiment

---

## promote 체크

```bash
skiro-learnings promote --threshold 3
# 동일 category 3회 이상 → CHECKLIST.md 승격 제안
```
