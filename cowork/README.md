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
| `cowork_paper_state` | Persistent paper design state (get/set) | "논문 구조 설계 저장해줘" / "현재 논문 상태 보여줘" |

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

### Autonomous paper design (Skill 3)
```
1. "이 프로젝트 실험 전체 현황 파악해줘"
   → cowork_scan_experiments(project_path="/path/to/research")
   (모든 실험의 meta, summary, feedback, figures, data 파악)

2. Claude가 연구 내러티브 추출 + 논문 구조 자율 설계

3. "논문 구조 저장해줘"
   → cowork_paper_state(paper_id="walking-robot-2026", action="set", state={...})
   (title, contributions, sections, key_figures, completion_pct, gaps 저장)

4. 실험 추가 후: "논문 상태 업데이트해줘"
   → cowork_scan_experiments → 새 데이터 확인
   → cowork_paper_state(action="get") → 기존 설계 로드
   → Claude가 영향받는 섹션만 증분 업데이트
   → cowork_paper_state(action="set") → 저장

5. "논문 완성도 알려줘"
   → cowork_paper_state(action="get")
   → "현재 72%. 부족: baseline 비교 실험, ablation study"
```
