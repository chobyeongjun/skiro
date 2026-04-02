---
name: skiro-mocap
description: |
  Motion capture data conversion. Converts Visual3D TXT exports to clean CSV.
  Handles 5-row header parsing, group+axis column naming (L_HipMoment_X),
  dual-condition file splitting (Nosuit/Suit), and multi-destination output.
  Currently supports Visual3D format — extensible to Vicon, OptiTrack, Xsens.
  For data validation after conversion, use /skiro-data. For gait analysis
  on converted CSV, use /skiro-gait. NOT for general CSV editing or
  non-mocap data formats.
  Keywords (EN/KR): mocap/모캡, motion capture/모션 캡처, Visual3D,
  c3d, 변환, convert, TXT to CSV, 모션 데이터, 관절각, joint angle,
  hip moment, knee angle, 보행 데이터 변환, 탭 구분. (skiro)
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

1. Load learnings for "mocap", "visual3d", "motion capture" tags.

## Phase 1: 입력 파일 확인

AskUserQuestion: "변환할 모션 캡처 데이터가 어디에 있나요?"
A) 경로를 알려줄게 (파일 또는 폴더)
B) 현재 폴더에서 TXT 찾아줘
C) Google Drive 공유 드라이브에 있어

경로 확인 후 TXT 파일 스캔:
```bash
find <path> -name "*.txt" 2>/dev/null | head -20
```

### 포맷 자동 감지
각 TXT 파일의 2번째 행을 읽어서 Visual3D 포맷인지 확인:
- `ANALOGTIME`, `TIME`, `FRAME_NUMBERS` 키워드 존재 → Visual3D
- 없으면 → "이 파일은 Visual3D 포맷이 아닙니다. 어떤 모캡 시스템에서 내보낸 건가요?"

파일 목록 표시:
```
=== 감지된 MoCap 파일 ===
| # | 파일명 | 포맷 | 크기 |
|---|--------|------|------|
| 1 | subject01_nosuit.txt | Visual3D | 2.3MB |
| 2 | subject01_suit.txt | Visual3D | 2.1MB |
| 3 | readme.txt | 일반 텍스트 | 0.5KB (스킵) |
```

## Phase 2: 출력 설정

AskUserQuestion: "변환된 CSV를 어디에 저장할까요?"
A) 원본 파일과 같은 폴더에 csv/ 하위 폴더
B) 경로를 직접 지정
C) paper_data/raw/ 에 저장 (논문 데이터로 바로 연결)

### 파일명 규칙
변환 결과 파일명은 원본에서 자동 결정:
- 단일 조건: `{원본파일명}.csv`
- 듀얼 조건 (Nosuit/Suit): c3d 경로에서 조건명 추출 → `{조건명}.csv`

사용자가 원하면 파일명 규칙 변경 가능:
```
{날짜}_{피험자}_{조건}.csv  (예: 260402_S01_Nosuit.csv)
```

## Phase 3: 변환 실행

### Visual3D TXT → CSV 변환 로직

**Visual3D TXT 구조** (5행 헤더 + 데이터):
```
Row 1: c3d 파일 경로 (탭 구분)
Row 2: 변수 그룹명 (ANALOGTIME, L_HipMoment, R_KneeAngle, ...)
Row 3: LINK_MODEL_BASED (버림)
Row 4: ORIGINAL (버림)
Row 5: 축 라벨 (X, Y, Z)
Row 6~: 데이터 (탭 구분 숫자)
```

**변환 규칙**:
1. Row 1: 파일 경로 → 듀얼 조건 분할 판단용 (ANALOGTIME 2번 = 듀얼)
2. Row 2 + Row 5 결합 → 칼럼명: `L_HipMoment` + `X` → `L_HipMoment_X`
3. Row 3, 4: 버림
4. Row 6~: 데이터 행 → CSV
5. 단일값 변수 (ANALOGTIME, TIME): 축 접미사 안 붙임
6. 첫 칼럼: `Frame`으로 고정

**듀얼 조건 파일 처리**:
- ANALOGTIME이 2번 나타나면 → 분할 지점
- 앞쪽: 첫 번째 조건 CSV
- 뒤쪽: 두 번째 조건 CSV (Frame 칼럼 복사 추가)

```python
"""Visual3D TXT → CSV 변환. convert_mocap.py가 없을 때 인라인 실행용."""
import csv
from pathlib import Path

VISUAL3D_KEYWORDS = {"ANALOGTIME", "TIME", "FRAME_NUMBERS"}
SINGLE_VALUE_VARS = {"ANALOGTIME", "TIME", "ITEM", ""}

def convert_visual3d(filepath: Path, output_dir: Path) -> list[Path]:
    with open(filepath, "r", encoding="utf-8-sig") as f:
        rows = f.readlines()

    row1 = rows[0].rstrip("\n\r").split("\t")  # 파일 경로
    row2 = rows[1].rstrip("\n\r").split("\t")  # 변수 그룹명
    row5 = rows[4].rstrip("\n\r").split("\t")  # X/Y/Z 축

    # 칼럼 수 맞추기
    max_cols = max(len(row1), len(row2), len(row5))
    row1 += [""] * (max_cols - len(row1))
    row2 += [""] * (max_cols - len(row2))
    row5 += [""] * (max_cols - len(row5))

    # 듀얼 분할 감지
    at_indices = [i for i, v in enumerate(row2) if v == "ANALOGTIME"]
    split_idx = at_indices[1] if len(at_indices) >= 2 else -1

    # 칼럼명 생성
    col_names = []
    for i in range(max_cols):
        g, a = row2[i].strip(), row5[i].strip()
        if i == 0:
            col_names.append("Frame")
        elif g in SINGLE_VALUE_VARS or g == "":
            col_names.append(g if g else f"col_{i}")
        elif a in ("X", "Y", "Z"):
            col_names.append(f"{g}_{a}")
        else:
            col_names.append(g)

    # 데이터 파싱
    data = []
    for line in rows[5:]:
        fields = line.rstrip("\n\r").split("\t")
        if all(f.strip() == "" for f in fields):
            continue
        data.append(fields)

    # CSV 출력
    output_dir.mkdir(parents=True, exist_ok=True)
    created = []

    def write_csv(out_path, headers, data, start, end, prepend_frame=False):
        h = (["Frame"] + headers[start:end]) if prepend_frame else headers[start:end]
        with open(out_path, "w", encoding="utf-8-sig", newline="") as f:
            w = csv.writer(f)
            w.writerow(h)
            for fields in data:
                padded = fields + [""] * (end - len(fields))
                r = padded[start:end]
                if prepend_frame:
                    r = [padded[0]] + r
                w.writerow(r)
        return len(data)

    if split_idx > 0:
        # 듀얼: 두 CSV로 분리
        from pathlib import PureWindowsPath
        name1 = next((PureWindowsPath(p.strip()).stem for p in row1[1:split_idx] if p.strip().endswith(".c3d")), filepath.stem + "_part1")
        name2 = next((PureWindowsPath(p.strip()).stem for p in row1[split_idx:] if p.strip().endswith(".c3d")), filepath.stem + "_part2")
        out1 = output_dir / f"{name1}.csv"
        out2 = output_dir / f"{name2}.csv"
        c1 = write_csv(out1, col_names, data, 0, split_idx)
        c2 = write_csv(out2, col_names, data, split_idx, len(col_names), prepend_frame=True)
        print(f"  [생성] {out1.name} ({split_idx}칼럼, {c1}행)")
        print(f"  [생성] {out2.name} ({len(col_names)-split_idx+1}칼럼, {c2}행)")
        created.extend([out1, out2])
    else:
        out = output_dir / f"{filepath.stem}.csv"
        c = write_csv(out, col_names, data, 0, len(col_names))
        print(f"  [생성] {out.name} ({len(col_names)}칼럼, {c}행)")
        created.append(out)

    return created
```

### 실행 방법
위 코드를 직접 Python으로 실행. 별도 스크립트 파일 불필요 — Claude Code 내에서 바로 처리.

## Phase 4: 변환 결과 확인

변환 완료 후 각 CSV를 빠르게 검증:

```python
import pandas as pd
df = pd.read_csv(output_csv)
print(f"Columns: {len(df.columns)}")
print(f"Rows: {len(df)}")
print(f"NaN: {df.isna().sum().sum()}")
print(f"Sample columns: {list(df.columns[:5])}")
```

결과 리포트:
```
=== MoCap 변환 결과 ===
입력 파일: 4개 TXT
생성된 CSV: 6개 (듀얼 2개 → 4개 + 단일 2개)
총 칼럼: 85개 (일관)
총 데이터 행: ~25,000
NaN: 0
저장 위치: paper_data/raw/
```

## Phase 5: Next Step

- 변환 완료 → `/skiro-data`로 무결성 검증
- 보행 분석 → `/skiro-gait`
- 논문 데이터 정리 → `/skiro-data Phase 6`

## Supported Formats

| 포맷 | 상태 | 감지 방법 |
|------|------|----------|
| Visual3D TXT | **지원** | Row 2에 ANALOGTIME/TIME/FRAME_NUMBERS |
| Vicon CSV | 계획 | 추후 추가 |
| OptiTrack TXT | 계획 | 추후 추가 |
| Xsens MVN | 계획 | 추후 추가 |
