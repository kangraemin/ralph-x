<div align="center">

# Ralph-X

**대화 한 번으로 `claude -p` 루프를 만들고 자동 실행.**

[![License](https://img.shields.io/github/license/kangraemin/ralph-x?style=for-the-badge)](https://github.com/kangraemin/ralph-x/blob/main/LICENSE)
[![Version](https://img.shields.io/github/v/release/kangraemin/ralph-x?style=for-the-badge&label=version)](https://github.com/kangraemin/ralph-x/releases)
[![Stars](https://img.shields.io/github/stars/kangraemin/ralph-x?style=for-the-badge)](https://github.com/kangraemin/ralph-x/stargazers)

[시작하기](#설치) · [English](README.md) · [이슈](https://github.com/kangraemin/ralph-x/issues)

</div>

---

하나의 `claude -p`에 긴 프롬프트를 넣으면 컨텍스트가 커지면서 집중력이 떨어짐. 웹 크롤링 같은 무거운 스텝 하나가 턴을 독식하면 나머지는 실행도 못 함.

Ralph-X는 **각 스텝을 독립 `claude -p` 프로세스로 분리**. 모든 스텝이 끝나야 1 iteration.

```
/ralph-x → 스텝 정의 → 반복 횟수 설정 → 자동 백그라운드 실행
```

## 설치

```bash
claude plugin marketplace add kangraemin/ralph-x
claude plugin install ralph-x@ralph-x
```

## 사용법

```
/ralph-x

작업?        →  "Kaggle 점수 개선"
스텝?        →  분석 (/browse) → 개발 → 검증
반복 횟수?   →  15

✅ 생성 + 백그라운드 실행 시작
```

## 생성되는 스크립트

각 프롬프트를 temp 파일에 쓰고, 스텝마다 `claude -p`를 호출:

```bash
cat > "$PROMPT_DIR/step1.txt" << 'S1EOF'
Current step: 분석 — /browse로 discussion 확인.
Read ralph-x-runs/<RUN_ID>/log.md for previous work.
S1EOF

cat > "$PROMPT_DIR/step2.txt" << 'S2EOF'
Current step: 개발 — 최적 전략 구현.
Read ralph-x-runs/<RUN_ID>/log.md for previous work.
S2EOF

for i in $(seq 1 15); do
  claude -p "$(cat "$PROMPT_DIR/step1.txt")"
  claude -p "$(cat "$PROMPT_DIR/step2.txt")"
done
```

- **스텝 하나 = 프로세스 하나** — 턴 독식 불가
- **고유 heredoc 구분자** — 파서 충돌 없음
- **공유 로그 파일** — 스텝 간 컨텍스트 전달
- **`--max-turns` 없음** — 각 스텝이 알아서 끝날 때까지 실행

## 왜 스텝 분리?

| 단일 `claude -p` | Ralph-X |
|---|---|
| 한 스텝이 나머지를 차단 | 각 스텝 독립 실행 |
| 긴 프롬프트, 집중력 저하 | 스텝별 짧은 프롬프트 |
| 스킬 일괄 적용 | 스텝별 다른 스킬 |

## 파일

| 파일 | 용도 |
|---|---|
| `ralph-x-runs/<RUN_ID>/run.sh` | 생성된 루프 스크립트 |
| `ralph-x-runs/<RUN_ID>/log.md` | 스텝 간 컨텍스트 브릿지 |
| `ralph-x-runs/<RUN_ID>/checklist.md` | 완료 조건 추적 |
| `ralph-x-runs/presets.json` | 자동 저장된 프리셋 |

## 라이선스

MIT
