<p align="center">
  <h1 align="center">Ralph-X</h1>
  <p align="center">
    <strong>모드를 고르는 AI 개발 루프</strong>
  </p>
  <p align="center">
    작업 시작 전에 파이프라인을 선택하세요. 스킬을 스테이지에 바인딩하세요. 저장하고 재사용하세요.
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

대부분의 Ralph 도구는 하나의 고정된 파이프라인을 강제합니다. Ralph-X는 매번 **"어떻게 진행할까요?"** 라고 물어봅니다 — 작업에 맞는 방식을 고르고, 스킬을 바인딩하고, 프리셋으로 저장하세요.

**Claude Code 플러그인**(스킬 + stop hook)으로 구현되어, `claude -p` bash 루프가 아닙니다. 루프 안에서 스킬, MCP 서버, 대화를 자유롭게 쓸 수 있습니다.

## 빠른 시작

```bash
# 마켓플레이스 등록 & 설치
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x

# 실행
/ralph-x TODO API 만들어줘
```

실행하면:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 어떻게 진행할까요?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. 🚀 Quick — 바로 코딩 시작.
 2. 📋 Standard — 사전처리 → 개발 → 후처리.
 3. 🔬 Thorough — 인터뷰 → 설계 → 개발 → 리뷰 → 테스트.
 4. 🎯 Custom — 직접 파이프라인 조합.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 핵심 기능

- **인터랙티브 모드 선택** — 워크플로우를 직접 고릅니다
- **스킬 바인딩** — `/review`, `/test` 등 스킬을 파이프라인 스테이지에 연결
- **커스텀 파이프라인 빌더** — 대화로 스테이지를 하나씩 조합
- **프리셋** — 만든 파이프라인을 저장하고 다음에 재사용
- **라이브 세션** — 루프 중에 스킬, MCP 서버, 유저 대화 모두 가능

## `claude -p` 루프와 뭐가 다른가요?

| | `claude -p` 루프 | Ralph-X |
|---|---|---|
| **구현** | Bash `while true` | Claude Code 플러그인 (스킬 + hook) |
| **세션** | 비대화형, 매번 새 컨텍스트 | 대화형, 세션 유지 |
| **스킬** | 사용 불가 | 스테이지에 바인딩 |
| **MCP 서버** | 사용 불가 | 전부 사용 가능 |
| **유저 개입** | 불가 | 루프 중 대화 가능 |
| **파이프라인** | 단일 고정 프롬프트 | 선택 또는 직접 조합 |

## 커스텀 파이프라인 빌더

**Custom**을 선택하면 대화로 파이프라인을 만듭니다:

```
Step 1: 첫 번째로 뭘 할까요?
> 기존 코드 분석

사용할 스킬이 있나요? (예: /review, 또는 skip)
> /review

Step 2: 그다음은?
> 테스트 작성

스킬은?
> /test

Step 3: 그다음은?
> 구현

Step 4: 그다음은?
> 끝

파이프라인: 기존 코드 분석 (/review) → 테스트 작성 (/test) → 구현

프리셋으로 저장할까요? (이름):
> tdd-style
```

저장한 프리셋은 다음에 Custom을 선택하면 나옵니다.

## 아키텍처

```
/ralph-x (스킬)           →  setup.sh가 state 파일 생성 + 메뉴 표시
     ↓
stop-hook.sh (Stop Hook)  →  세션 종료를 가로채서 트랜스크립트 읽고,
                              모드/스테이지 감지, 프롬프트 재전달
     ↓
State Files               →  ralph-x.local.md  (이터레이션 + 설정)
                              ralph-x-stages.json (파이프라인 스테이지)
                              ralph-x-presets.json (저장된 파이프라인)
```

## 옵션

| 플래그 | 설명 |
|--------|------|
| `--max-iterations <n>` | N회 반복 후 자동 중지 |
| `--completion-promise <text>` | 완료 조건이 참일 때 중지 |

## 취소

```bash
/cancel-ralph-x
```

## 라이선스

MIT
