<p align="center">
  <h1 align="center">Ralph-X</h1>
  <p align="center">
    <strong>Claude Code용 AI 개발 루프 생성기</strong>
  </p>
  <p align="center">
    대화로 멀티 스테이지 <code>claude -p</code> 루프를 만들고 실행합니다. 스킬, MCP 사용 가능.
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

Ralph-X는 대화를 통해 멀티 스테이지 `claude -p` 루프 스크립트를 생성합니다. 작업 내용, 파이프라인, 완료 조건을 말하면 스크립트를 만들고 실행해줍니다.

각 스테이지는 별도의 `claude -p` 호출로 실행되어 **스킬과 MCP 서버**를 자유롭게 쓸 수 있고, 로그 파일로 스테이지 간 컨텍스트를 전달합니다.

## 빠른 시작

```bash
# 설치
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x

# 실행
/ralph-x
```

## 사용법

```
/ralph-x

어떤 작업?           → "Kaggle 점수 개선"
파이프라인?          → Custom: 분석 → 개발 → 검증
최대 반복?           → 20회
완료 조건?           → "LB 점수 개선", "trial 정리 완료"
스킬?               → /browse (분석), /kaggle-trial (검증)

→ .claude/ralph-x-run.sh 생성
→ 실행
```

## 핵심 기능

- **대화형 셋업** — 대화로 루프를 구성
- **멀티 스테이지** — 스테이지별 독립 `claude -p` 호출 (컨텍스트 비대화 방지)
- **스킬 & MCP** — `/browse`, `/review`, `/test` 등 스킬을 스테이지에 바인딩
- **체크리스트 완료** — 모든 조건 충족 시 자동 종료
- **로그 파일** — `.claude/ralph-x-log.md`로 스테이지 간 컨텍스트 전달
- **프리셋** — 파이프라인 설정 저장 및 재사용

## 왜 하나의 `claude -p`가 아닌가?

하나의 긴 `claude -p`는 컨텍스트가 커지면 초반 지시를 까먹습니다. Ralph-X는 작업을 집중적인 스테이지로 나누고, 로그 파일로만 컨텍스트를 이어갑니다.

## 아키텍처

```
/ralph-x (스킬)
  ↓ 대화
수집: 작업, 파이프라인, 반복 횟수, 체크리스트, 스킬
  ↓ 생성
.claude/ralph-x-run.sh       (스테이지별 claude -p 루프)
.claude/ralph-x-log.md       (스테이지 간 컨텍스트)
.claude/ralph-x-checklist.md (완료 추적)
  ↓ 실행
bash .claude/ralph-x-run.sh
```

hook 없음. state 파일 없음. 스크립트를 만들어서 돌리는 스킬 하나.

## 취소

```bash
Ctrl+C

# 정리
rm -f .claude/ralph-x-run.sh .claude/ralph-x-log.md .claude/ralph-x-checklist.md
```

## 라이선스

MIT
