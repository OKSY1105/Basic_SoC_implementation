# 검증 프로세스 — Claude Code 작성 · Codex 독립 검증

8bit_SoC의 RTL·TB는 작성자와 검증자를 분리해 개발한다. 이 폴더는 그 규칙과 블록별 검증 기록(요청서·결과 원문)을 공개 보관한다.

| 역할 | 담당 | 권한 |
|---|---|---|
| 작성자 | Claude Code | RTL·TB·스크립트·설계 문서 작성, 브랜치 push, main 병합 |
| 검증자 | Codex | 지정 커밋의 독립 실행·검토, 결과 작성. 저장소는 읽기 전용(push 없음) |
| 승인자 | 사용자 | 병합 승인, 규칙·지침 변경 승인 |

검증자 지침: [CODEX_GUIDE.md](CODEX_GUIDE.md)

---

## 1. 진행 흐름

1. Claude: RTL·TB 작성 → 자체 시뮬레이션(ModelSim Intel FPGA Edition 2020.1) → `feat/<블록>` 브랜치 push
2. Claude: 검증 요청서 작성 (작업 중에는 로컬 교환 폴더 `handoff/requests/`)
3. 사용자: Codex에 검증 지시
4. Codex: 요청서의 커밋을 checkout해 실행·검토(Vivado XSim 등) → Notion 상세 기록 → 결과 파일 작성 (`handoff/results/`)
5. Claude: 결과 확인 → FAIL이면 수정 후 재검증 요청(`_rK`)
6. PASS: 7절 병합 규칙에 따라 Claude가 main에 병합
7. Claude: 해당 블록의 모든 회차 요청서·결과를 이 폴더의 `VR-NNN_<블록>/`에 **원문 그대로** 커밋해 공개

검증 중에는 기록을 브랜치에 넣지 않는다. 브랜치에 커밋이 추가되면 "검증한 커밋 = 병합할 커밋" 조건이 깨지기 때문이다.

---

## 2. 파일 이름 규칙

| 대상 | 작업 중 (로컬 `handoff/`) | 공개 기록 (이 폴더) |
|---|---|---|
| 요청서 | `requests/VR-NNN_<블록>.md` | `VR-NNN_<블록>/request.md` |
| 재검증 요청 | `requests/VR-NNN_<블록>_rK.md` | `VR-NNN_<블록>/request_rK.md` |
| 결과 | `results/VR-NNN_<블록>.md` | `VR-NNN_<블록>/result.md` |
| 재검증 결과 | `results/VR-NNN_<블록>_rK.md` | `VR-NNN_<블록>/result_rK.md` |
| 결과에 대한 답변 | `results/VR-NNN_<블록>_note.md` | `VR-NNN_<블록>/note.md` |

- NNN은 001부터 순차 증가하며 Claude가 매긴다. VR-000은 절차 시험용이다.
- 이름에는 영문·숫자·`_`·`-`만 쓴다.
- 요청서·결과는 작성 후 수정하지 않는다. 정정은 새 회차(`_rK`) 또는 `_note`로 한다.

---

## 3. 요청서 양식 (Claude 작성)

```markdown
# VR-NNN — <블록 이름>

- 작성: Claude Code, YYYY-MM-DD
- 브랜치 / 커밋: feat/<블록> @ <40자리 SHA>
- 이전 요청: (재검증이면 이전 요청서·결과)
- 변경 파일: <저장소 기준 경로 목록>
- 명세 근거: <설계 문서 경로와 절>

## 실행
- 명령: <저장소 루트 기준, 그대로 실행 가능한 명령>
- 기대 출력: <TB의 PASS 문자열>
- Claude 자체 결과: <도구·버전, PASS/FAIL, 핵심 로그 1~3줄>

## 검증 요청 항목
1. <확인할 동작과 통과 조건>

## 범위 밖
- <이번에 검증하지 않아도 되는 것>
```

결과 양식은 [CODEX_GUIDE.md](CODEX_GUIDE.md) 5절에 있다.

---

## 4. 병합 규칙

다음 조건을 모두 만족할 때만 Claude가 main에 병합한다.

1. 결과 판정이 PASS
2. 결과의 검증 커밋 SHA = 브랜치 최신 커밋 SHA (검증 뒤 커밋이 추가됐으면 재검증)
3. 사용자 승인
4. `git merge --ff-only`로만 병합. 불가하면 브랜치를 최신 main 위로 옮긴 뒤 재검증
5. push 후 원격 SHA 확인, 이어서 1절 7번의 검증 기록 커밋

---

## 5. 공개 범위

| 항목 | 위치 | 공개 |
|---|---|---|
| 요청서·결과 원문 (FAIL·재검증 회차 포함) | 이 폴더 `VR-NNN_<블록>/` | 공개 (병합 후) |
| 검증 규칙·검증자 지침 | 이 폴더 | 공개 |
| 블록별 결과 요약 | `04_unit/<블록>/test.md` | 공개 |
| 작업 중 교환 파일·Codex 실행 로그 전체 | 로컬 `handoff/` | 비공개 (결과 파일에 핵심 로그 인용) |
| Notion 상세 기록 | Notion "8bit_SoC 검증 기록" DB | 비공개 |
| 세션 기록 `history.md` | 로컬 | 비공개 (`.gitignore`) |
