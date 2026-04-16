# skiro-cowork

**COWORK MCP Server for claude.ai**

Claude Code에서 축적한 데이터 (artifacts, learnings, git log)를 claude.ai에서 읽어서 PPT, 논문, 발표자료를 작성할 때 활용합니다.

---

## Setup

### 1. Install dependencies

```bash
cd ~/skiro/cowork && npm install
```

### 2. Register in claude.ai

claude.ai > Settings > MCP Servers > Add:

```
Name: skiro-cowork
Command: node
Args: /path/to/skiro/cowork/skiro-cowork-server.mjs
```

Or via Claude Code CLI:
```bash
claude mcp add skiro-cowork -s user -- node ~/skiro/cowork/skiro-cowork-server.mjs
```

---

## Tools

| Tool | Purpose | When to use |
|------|---------|-------------|
| `cowork_list_artifacts` | Find files saved during Code sessions | "그 EMG 그래프 어디있어?" |
| `cowork_get_learnings` | Problem-solution history | "방법론 변경 근거 정리해줘" |
| `cowork_project_summary` | Structured project overview | "미팅 자료 준비해줘" |
| `cowork_paper_data` | Paper section data extraction | "Results 섹션 데이터 정리" |
| `cowork_read_file` | Read actual file content | "그 데이터 파일 내용 보여줘" |
| `cowork_scan_experiments` | Scan experiments/meetings inventory | "이 프로젝트 실험 전체 현황 파악해줘" |
| `cowork_paper_state` | Paper design state (list/get/set/update) | "논문 구조 설계 저장해줘" / "현재 논문 상태 보여줘" |
| `cowork_paper_check` | Validate paper state consistency | "논문 상태 검증해줘" (set/update 후 필수) |
| `cowork_paper_guide` | 4-phase paper methodology (AI Scientist ref.) | 논문 세션 시작 시 자동 호출 |

---

## Data Flow

```
Claude Code (daily work)              →    claude.ai COWORK
                                            │
skiro_save_artifact → artifacts.jsonl  ───→ cowork_list_artifacts
                                            ───→ cowork_read_file
skiro_record_problem → learnings.jsonl ───→ cowork_get_learnings
git commits                            ───→ cowork_project_summary
                                            │
                                            ↓
                                       PPT / Paper / Tech Brief
```

---

## Usage Examples

### Meeting prep
```
"다음 주 교수님 미팅 자료 준비해줘"
→ cowork_project_summary(project_path="/path/to/robot", purpose="meeting")
```

### Paper writing
```
"Results 섹션에 쓸 데이터 정리해줘"
→ cowork_paper_data(section="results", project_path="/path/to/robot")

"방법론 변경 이력 정리해줘"
→ cowork_get_learnings(format="paper", category="control")
```

### Find and read file
```
"지난주 만든 보행 분석 그래프 어디있어?"
→ cowork_list_artifacts(query="보행", category="figure")

"그 데이터 파일 내용 보여줘"
→ cowork_read_file(path="/path/to/data.csv")
```

### Autonomous paper design workflow

**Phase 1: 구조 설계 (첫 세션)**
```
"이 프로젝트로 논문 쓰고 싶어"
  → cowork_paper_state(action="list")              # 기존 논문 있나 확인
  → cowork_scan_experiments(project_path="...")    # 실험 전체 현황
  → cowork_get_learnings(format="paper")           # 방법론 변경 이력
  → Claude가 title/contributions/sections 제안
  → 사용자 확인 후:
  → cowork_paper_state(action="set", paper_id="walking-2026", state={...})
  → cowork_paper_check(paper_id="walking-2026")   # 일관성 검증 (필수)
```

**Phase 2: 섹션 작성**
```
"Methods 섹션 쓰자"
  → cowork_paper_state(action="get", paper_id="walking-2026")
  → cowork_paper_data(section="methods")           # 해당 섹션 데이터만
  → (Code MCP) skiro_vault_read(note="...", section="...")  # 필요한 vault 섹션만
  → Claude가 초안 작성
  → cowork_paper_state(action="update", state={sections:[...], completion_pct: 40})
```

**Phase 3: 실험 추가 시 증분 갱신**
```
"새 실험 2개 끝났어"
  → cowork_scan_experiments(...)                   # 새 실험 감지
  → cowork_paper_state(action="get", ...)          # 기존 설계 로드
  → Claude가 영향받는 섹션만 업데이트
  → cowork_paper_state(action="update", state={...})  # 변경분만 저장
  → cowork_paper_check(...)                        # 재검증
```

**Phase 4: 미팅/출판 준비**
```
"논문 현재 상태 알려줘"
  → cowork_paper_state(action="get")               # 완성도, gaps
  → cowork_paper_check(...)                        # 실제 일관성

"발표 자료 만들자"
  → cowork_promote_data(experiment_path="...", from_tier="raw", to_tier="ppt", files=[...])

"출판용 figure 선정"
  → cowork_promote_data(from_tier="ppt", to_tier="paper", files=[...])
```

### Action reference (paper_state)

| Action | Purpose | 특징 |
|--------|---------|------|
| `list` | 모든 저장된 논문 조회 | paper_id 불필요 |
| `get` | 특정 논문 상태 읽기 | 포맷된 테이블로 출력 |
| `set` | 전체 덮어쓰기 | 스키마 검증 + atomic write |
| `update` | 부분 병합 | 기존 state 유지 + 변경분만 덮어씀 |

### Schema (검증됨)

```json
{
  "title": "string (set 시 필수)",
  "contributions": ["array of strings"],
  "sections": [
    { "name": "필수", "status": "done|draft|todo|...", "key_experiments": ["exp-id"] }
  ],
  "key_figures": ["figure filename or path"],
  "completion_pct": "0-100 (검증됨)",
  "gaps": [
    { "description": "필수", "priority": "high|medium|low", "type": "experiment|writing|..." }
  ]
}
```
