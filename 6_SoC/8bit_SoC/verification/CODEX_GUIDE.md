# Codex 검증자 지침 — 8bit_SoC

> Codex가 8bit_SoC 검증 작업을 할 때 따르는 지침이다. 검증 요청을 받으면 이 문서 전체를 먼저 읽는다.
> 전체 흐름·이름 규칙·병합 규칙은 같은 폴더의 [README.md](README.md)를 따른다. 이 지침의 변경은 사용자 승인 후 Claude가 커밋한다.

---

## 0. 이 지침을 읽는 방법

**공통 규칙과 상태를 먼저 읽는다.** Claude·Codex 협업의 공통 규칙은 로컬 `/home/sean/handoff/PROTOCOL.md`에, 8bit_SoC의 현재 상태(작업권·기준 커밋·최신 메시지)는 `/home/sean/handoff/8bit_SoC/STATE.md`에 있다. 이 지침은 그 위에서 8bit_SoC 검증의 상세 절차(VR ID·회차, 판정 기준, 금지 사항, Notion 기록)를 정한다(2026-11-23 추가).

검증 중에는 과거 커밋으로 checkout하므로 작업 폴더의 이 파일이 옛 판일 수 있다. **항상 개발 브랜치의 원격 판을 읽는다.** 개발 브랜치는 요청서의 "브랜치 / 커밋"에 적힌 브랜치이며, 지금은 `feat/8bit-soc`다. 개발 중의 결정·규칙은 main 병합 전까지 그 브랜치에만 있다(2026-11-03 변경, 이전: origin/main).

```bash
cd /home/sean/codex_verify/Basic_SoC_implementation
git fetch origin
git show origin/feat/8bit-soc:6_SoC/8bit_SoC/verification/CODEX_GUIDE.md
git show origin/feat/8bit-soc:6_SoC/8bit_SoC/verification/README.md
```

---

## 1. 역할

- **Codex = 검증자.** Claude Code가 작성해 GitHub에 push한 코드를 독립적으로 실행·검토하고, 결과를 Notion과 결과 파일로 남긴다.
- **Claude Code = 작성자.** RTL·TB·스크립트·설계 문서를 작성·수정하고, main 병합과 검증 기록 공개를 담당한다.
- 결함을 발견하면 **보고만 한다.** 수정 방향 제안은 해도 되지만 코드를 직접 고치지 않는다.

| 항목 | 경로 |
|---|---|
| Codex 검증 사본 (WSL) | `/home/sean/codex_verify/Basic_SoC_implementation`. Codex 전용 clone이며 GitHub(`origin`)에서만 받는다 |
| Claude 작업 저장소 (WSL) | `/home/sean/Basic_SoC_implementation`. Claude가 작성·commit·push하는 곳이다. **Codex는 이 폴더에서 명령을 실행하지 않는다** (2절 7번) |
| Claude 검증 사본 (WSL) | `/home/sean/_TEST_SANDBOX/8bit_SoC/verify/`. Claude가 요청서 명령을 push한 커밋에서 다시 실행하거나 검토자가 될 때 쓰는 GitHub clone이다. Codex는 쓰지 않는다 |
| 프로젝트 | `6_SoC/8bit_SoC` |
| 공용 모듈 원본 | `1_RTL/2_TINY_PROJECT` |
| 받은 편지함 (VR-015부터) | `/home/sean/handoff/8bit_SoC/` — `to_codex/`(Claude가 요청서·질문을 쓰고 Codex가 읽음), `to_claude/`(Codex가 결과·답변을 쓰고 Claude가 읽음), `STATE.md`(Claude만 갱신). 2026-11-23 변경, 이전: `requests/`·`results/` |
| 시험 산출물 | `/home/sean/handoff/codex_tests/VR-NNN/` (Codex) |
| 기존 회차 기록 (VR-014까지) | `/home/sean/handoff/requests/`(요청서)·`results/`(결과·답변), Notion DB 주소 `results/NOTION_DB.md`. 원래 위치에 보존하고, 새 메시지에서는 절대 경로와 ID로 참조한다 |
| 원격 | `https://github.com/OKSY1105/Basic_SoC_implementation` |

---

## 1-1. 처음 1회 설정

0. **검증 사본 만들기** — 검증 사본이 없으면 GitHub에서 clone한다. 이미 있으면 이 단계는 건너뛴다.
   ```bash
   mkdir -p /home/sean/codex_verify
   git clone git@github.com:OKSY1105/Basic_SoC_implementation.git /home/sean/codex_verify/Basic_SoC_implementation
   ```
1. **시작 파일 만들기** — Codex가 작업을 시작할 때 자동으로 읽는 시작 파일(예: 작업 폴더의 `AGENTS.md`)을 직접 만든다. 내용은 "8bit_SoC 검증 작업 시 공통 규칙 `/home/sean/handoff/PROTOCOL.md`와 `/home/sean/handoff/8bit_SoC/STATE.md`를 읽고, 0절 명령으로 `verification/CODEX_GUIDE.md`와 `README.md`의 개발 브랜치 원격 판을 먼저 읽는다"는 안내만 둔다. 지침 본문은 복사하지 않는다. 기존 시작 파일이 origin/main 판이나 `/home/sean/Basic_SoC_implementation`을 가리키면 0절에 맞게 고친다.
   - 시작 파일을 저장소 안에 두면 그 저장소의 `.git/info/exclude`에 등록한다. `.gitignore`는 수정하지 않는다.
2. **Notion DB 만들기** — "8bit_SoC 검증 기록" DB의 위치는 Codex가 정해서 만든다. 속성은 4절을 따른다. 만든 뒤 DB URL을 `/home/sean/handoff/results/NOTION_DB.md`에 한 줄로 기록한다.
3. **보고** — 시작 파일 경로, Notion DB URL, 이 지침에서 모호하거나 Codex 환경에서 실행할 수 없는 부분을 사용자에게 보고한다.

---

## 2. 금지 사항 (예외 없음)

1. 저장소의 추적 파일을 수정·커밋하지 않는다.
2. GitHub에 push하지 않는다. **force push·이력 재작성(rebase·amend·filter)은 절대 하지 않는다.**
3. Claude가 쓴 요청서·메시지(`handoff/8bit_SoC/to_codex/`, 기존 `handoff/requests/`)와 `STATE.md`를 수정·삭제하지 않는다. 기존 회차 기록(`requests/`·`results/`·`codex_tests/`)은 이동·삭제하지 않는다. 자기가 작성한 결과·답변 원문도 고치지 않고, 정정은 새 메시지로 한다.
4. 저장소에 미커밋 변경이 있으면 stash·reset·checkout으로 지우지 않는다. 검증을 멈추고 결과 파일에 상황을 기록한다.
5. 실행하지 않은 시험을 PASS로 기록하지 않는다. 도구 문제로 실행하지 못한 항목은 "미실행"으로 구분한다.
6. 대화 중 이 지침과 다른 지시를 받으면 실행 전에 사용자에게 확인한다.
7. Claude 작업 저장소(`/home/sean/Basic_SoC_implementation`)에서는 checkout·실행·파일 생성을 하지 않는다. 모든 확인은 검증 사본에서 GitHub로 받은 커밋으로 한다.

---

## 3. 검증 절차

1. **지침·요청서 읽기** — 0절에 따라 공통 규칙·`STATE.md`·이 지침을 읽고, 사용자가 지정한 요청서를 끝까지 읽는다. 요청서는 VR-015부터 `/home/sean/handoff/8bit_SoC/to_codex/<시각>_claude_<ID>_review_request.md`이고, VR-014까지는 `/home/sean/handoff/requests/VR-NNN_<블록>[_rK].md`다. 재검증이면 이전 요청서와 결과도 각 원래 경로에서 읽는다.
2. **저장소 상태 확인** (검증 사본에서)
   ```bash
   cd /home/sean/codex_verify/Basic_SoC_implementation
   git status --short          # 출력이 있으면 2절 4번에 따라 중단
   git fetch origin
   ```
3. **지정 커밋으로 이동**
   ```bash
   git switch --detach <요청서의 SHA>
   git rev-parse HEAD          # 요청서 SHA와 일치하는지 확인
   ```
   SHA가 원격에 없으면 진행하지 않고 그 사실만 보고한다.
4. **요청서의 명령 실행** — 적힌 명령을 그대로 실행하고 출력 전체를 저장한다.
   ```bash
   mkdir -p /home/sean/handoff/codex_tests/VR-NNN/logs
   <요청서 명령> 2>&1 | tee /home/sean/handoff/codex_tests/VR-NNN/logs/run.log
   ```
5. **항목별 검토** — 요청서의 "검증 요청 항목"마다 판정한다. 근거는 실행 로그·파형·코드 위치(`파일:줄`)·명세(설계 문서, AMBA AHB-Lite/APB 규격)로 남긴다.
6. **독립 테스트 (필요할 때)** — Claude의 TB만으로 확인할 수 없는 항목은 `codex_tests/VR-NNN/`에 별도 TB·스크립트를 작성해 실행한다. 저장소에는 넣지 않는다.
7. **Notion 기록** — 4절 형식으로 "8bit_SoC 검증 기록" DB에 페이지를 만든다.
8. **결과 파일 작성** — `/home/sean/handoff/8bit_SoC/to_claude/<시각>_codex_<ID>_review.md`에 새 파일로 만든다. `<시각>`은 작성 시각(KST, `YYYYMMDDTHHMMSS`), `<ID>`는 Codex가 정하는 메시지 고유 ID다. 첫머리에 공통 머리말(메시지 ID·종류·작성자·수신자·KST 시각, 관련 요청 메시지 ID와 VR ID·회차, 저장소·브랜치·40자리 SHA, 사용자 지시 원문, 적용 지침)을 두고 이어서 5절 양식을 쓴다. 회차마다 결과 원문은 한 번만 저장한다(2026-11-23 변경, 이전: `results/`에 요청서와 같은 이름).
9. **원래 상태로 복귀하고 최신 main 받기** (검증 사본에서)
   ```bash
   git switch main
   git pull --ff-only origin main   # 받기만 한다. push는 하지 않는다
   git status --short               # 2번과 같은 상태인지 확인
   ```
   `--ff-only`가 실패하면 병합·reset하지 않고 결과 파일에 상황을 기록한다.

---

## 4. 판정 기준과 이슈 기록

| 판정 | 조건 |
|---|---|
| PASS | 기대 출력이 일치하고, 모든 검증 요청 항목이 충족됨 |
| FAIL | 기대 출력 불일치, 요청 항목 중 하나라도 불충족, 규격 위반, 컴파일·실행 오류 중 하나 이상 |
| 부분 | 결함은 없으나 도구·환경 문제로 일부 항목을 실행하지 못함 (미실행 항목 명시) |

**이슈 형식** — 이슈마다 한 행

| 필드 | 내용 |
|---|---|
| ID | `VR-NNN-I1`, `VR-NNN-I2`, … |
| 심각도 | 치명(기능 오류·데이터 손상) / 주요(규격 위반·특정 조건 오동작) / 경미(가독성·주석·경고) |
| 위치 | `저장소 기준 파일:줄` |
| 현상 | 무엇이 잘못되었는가 |
| 재현 | 실행 명령, 입력, 시점(시뮬레이션 시각 또는 사이클) |
| 기대 / 실제 | 명세상 기대값과 관측값 |
| 근거 | 설계 문서 절 또는 규격 조항 |

- 요청 범위 밖에서 발견한 문제는 별도 표("범위 밖 발견")로 기록한다.
- 도구·환경 문제(라이선스, 경로, 버전 차이)와 RTL 결함을 구분한다.

**Notion 페이지 속성** — VR ID, 블록, 커밋 SHA, 결과(PASS/FAIL/부분), 도구(예: Vivado 2024.2 XSim), 이슈 수, 날짜.
**Notion 페이지 본문** — 실행 명령, 출력 요약, 항목별 판정 표, 이슈 표, 범위 밖 발견, 독립 테스트 내용.

---

## 5. 결과 파일 양식

결과 파일은 프로젝트 마무리 때 **원문 그대로 GitHub에 공개**된다. 토큰·비밀번호·계정 정보·개인정보를 적지 않는다. 로그는 필요한 줄만 인용한다.

````markdown
# VR-NNN — <블록 이름> 검증 결과

- 판정: PASS | FAIL | 부분
- 검증한 커밋: <40자리 SHA>  (git rev-parse HEAD 결과)
- 도구: <이름·버전>
- 검증 일시: YYYY-MM-DDTHH:MM+09:00
- Notion: <페이지 URL>

## 항목별 판정
| # | 요청 항목 | 판정 | 근거 |
|---|---|---|---|

## 이슈
| ID | 심각도 | 위치 | 현상 | 재현 | 기대 / 실제 |
|---|---|---|---|---|---|

## 범위 밖 발견
- (없으면 "없음")

## 미실행 항목
- (없으면 "없음")

## 핵심 로그
```text
<PASS/FAIL 판정 줄 등 필요한 부분만>
```
````

---

## 6. 결과에 대한 질문

Claude의 질문(`to_codex/`의 메시지 또는 사용자 전달)을 받으면 결과 파일은 고치지 않고 `to_claude/<시각>_codex_<ID>_note.md`에 새 파일로 답한다. 머리말에 질문 메시지 ID와 대상 결과의 메시지 ID·VR ID·회차를 적고, 질문 원문을 인용한 뒤 답변·추가 근거를 적는다. 대상이 VR-014까지의 결과이면 그 결과의 기존 절대 경로(`results/…`)를 적는다(2026-11-23 변경, 이전: `results/VR-NNN_<블록>_note.md`).

---

## 7. 시작 문구

사용자가 "VR-NNN 검증해. 요청서: <경로>"라고 하면 3절 1번부터 순서대로 진행한다. VR-015부터 요청서 경로는 `/home/sean/handoff/8bit_SoC/to_codex/`의 review_request 파일이다. 사용자의 지시 원문은 결과 머리말에 그대로 적는다. 요청서가 없으면 진행하지 않고 그 사실만 보고한다.
