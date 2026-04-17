---
type: meeting
date: YYYY-MM-DD
attendees: []
tags: [meeting]
---

# Meeting — YYYY-MM-DD

## Recent Learnings (auto)
```dataview
TABLE file.ctime as "When", category, severity
FROM "20_Learnings"
WHERE file.ctime >= date(today) - dur(2 weeks)
SORT file.ctime DESC
LIMIT 15
```

## Experiments in Progress
```dataview
TABLE project, status
FROM #experiment
WHERE status = "running"
```

## Demo Items
-

## Discussion
-

## Feedback Received
-

## Action Items
- [ ]

## Next Meeting Agenda
-
