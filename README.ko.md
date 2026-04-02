<p align="center">
  <h1 align="center">Ralph-X</h1>
  <p align="center">
    <strong>Claude Code용 AI 개발 루프 생성기</strong>
  </p>
  <p align="center">
    대화로 멀티 스테이지 <code>claude -p</code> 루프를 만들고 실행합니다.
  </p>
  <p align="center">
    <a href="#빠른-시작">시작하기</a> · <a href="README.md">English</a> · <a href="https://github.com/kangraemin/ralph-x/issues">이슈</a>
  </p>
  <p align="center">
    <a href="https://github.com/kangraemin/ralph-x/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kangraemin/ralph-x?style=for-the-badge" alt="License"></a>
    <a href="https://github.com/kangraemin/ralph-x/releases"><img src="https://img.shields.io/github/v/release/kangraemin/ralph-x?style=for-the-badge&label=version" alt="Version"></a>
    <a href="https://github.com/kangraemin/ralph-x/stargazers"><img src="https://img.shields.io/github/stars/kangraemin/ralph-x?style=for-the-badge" alt="Stars"></a>
  </p>
</p>

---

대부분의 Ralph 도구는 하나의 `claude -p`에 긴 프롬프트를 넣고 돌립니다. 컨텍스트가 커지면 앞부분 지시를 까먹고 집중력이 떨어지죠.

Ralph-X는 작업을 **집중적인 스테이지로 분할**합니다. 각 스테이지가 독립적인 `claude -p` 호출로 실행되고, 로그 파일로 컨텍스트를 이어갑니다.

대화로 루프를 구성하세요: 파이프라인 선택, 반복 횟수 설정, 완료 조건 추가, 스킬 바인딩 — Ralph-X가 bash 스크립트를 만들어 실행합니다.

## 빠른 시작

```bash
# 설치
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x

# 실행
/ralph-x
```

## 예시

```
/ralph-x

어떤 작업?       →  "Kaggle churn 점수 개선"
파이프라인?      →  Custom: 분석 → 개발 → 검증
스킬?           →  /browse (분석), /kaggle-trial (검증)
최대 반복?       →  20회
완료 조건?
  1. LB 점수 개선
  2. Trial 정리 완료
  → 끝

✅ 스크립트 생성 → .claude/ralph-x-run.sh
실행할까요? → 네
```

## 생성되는 스크립트

```bash
#!/bin/bash
for i in $(seq 1 20); do
  # 모든 조건 충족 시 종료
  if ! grep -q '^\- \[ \]' .claude/ralph-x-checklist.md; then
    echo "✅ 완료!"; break
  fi

  # Stage 1: 분석 (/browse 사용)
  claude -p "로그 읽고 현재 상태 분석. /browse로 discussion 확인.
  .claude/ralph-x-log.md에 요약 추가." --max-turns 50

  # Stage 2: 개발
  claude -p "로그 읽고 분석 결과 기반으로 최적 전략 구현.
  .claude/ralph-x-log.md에 요약 추가." --max-turns 50

  # Stage 3: 검증 (/kaggle-trial 사용)
  claude -p "로그 읽고 결과 검증. /kaggle-trial로 trial 정리.
  .claude/ralph-x-log.md에 요약 추가.
  조건 충족 시 체크리스트 업데이트." --max-turns 50
done
```

각 `claude -p` 호출은:
- **짧고 집중적인 프롬프트** (컨텍스트 비대화 방지)
- **스킬과 MCP 서버** 사용 가능
- **공유 로그 파일**로 스테이지 간 연속성 유지
- **체크리스트**로 완료 조건 추적

## 기능

| 기능 | 설명 |
|------|------|
| **멀티 스테이지** | 스테이지별 독립 `claude -p`, 깨끗한 컨텍스트 |
| **스킬 & MCP** | `/browse`, `/review`, `/test` 등 스테이지별 바인딩 |
| **체크리스트** | 모든 조건 충족 시 자동 종료 |
| **로그 브릿지** | `.claude/ralph-x-log.md`로 컨텍스트 전달 |
| **프리셋** | 파이프라인 설정 저장 및 재사용 |
| **대화형** | 플래그가 아닌 대화로 루프 구성 |

## 왜 스테이지를 분할하나?

| 단일 `claude -p` | 멀티 스테이지 (Ralph-X) |
|------------------|------------------------|
| 하나의 긴 프롬프트 | 스테이지별 짧은 프롬프트 |
| 앞부분 지시를 까먹음 | 매 스테이지 새 컨텍스트 |
| 하나의 컨텍스트에 전부 | 로그 파일로 연결 |
| 스킬 일괄 적용 | 스테이지별 다른 스킬 |

## 파일

| 파일 | 용도 |
|------|------|
| `.claude/ralph-x-run.sh` | 생성된 루프 스크립트 |
| `.claude/ralph-x-log.md` | 작업 로그 (컨텍스트 브릿지) |
| `.claude/ralph-x-checklist.md` | 완료 조건 추적 |
| `.claude/ralph-x-presets.json` | 저장된 프리셋 |

## 취소

```bash
Ctrl+C

# 정리
rm -f .claude/ralph-x-run.sh .claude/ralph-x-log.md .claude/ralph-x-checklist.md
```

## 라이선스

MIT
