---
name: update-ralph-x
description: ralph-x 최신 버전 확인 및 업데이트
allowed-tools: [Bash, Read, Write, Glob]
---

# /update-ralph-x

**Respond in the same language the user uses.** Korean → Korean. English → English.

## Flow

### Step 1: update-check.sh 탐색

installed_plugins.json에서 ralph-x 설치 경로를 읽는다:

```bash
INSTALL_PATH=$(python3 -c "
import json
data = json.load(open('$HOME/.claude/plugins/installed_plugins.json'))
entries = data.get('plugins', {}).get('ralph-x@ralph-x', [])
print(entries[0]['installPath'] if entries else '')
")
SCRIPT="$INSTALL_PATH/scripts/update-check.sh"
```

스크립트가 없으면 GitHub raw에서 bootstrap:
```bash
mkdir -p "$INSTALL_PATH/scripts"
curl -sf "https://raw.githubusercontent.com/kangraemin/ralph-x/main/scripts/update-check.sh" \
  -o "$SCRIPT" && chmod +x "$SCRIPT"
```

bootstrap 실패 시 "update-check.sh를 다운로드할 수 없습니다." 출력 후 종료.

### Step 2: 버전 확인

```bash
bash "$SCRIPT" --check-only
```

### Step 3: 결과 분기

- `up-to-date` → "최신 버전입니다 (SHA)" 출력 → Step 5로 이동
- `update-available` → 현재/최신 SHA 보여주고 업데이트 여부 확인

### Step 4: 업데이트 실행

```bash
bash "$SCRIPT" --force
```

완료 메시지 출력.

### Step 5: 프리셋 마이그레이션 (현재 프로젝트)

현재 프로젝트 디렉토리에서 구경로 프리셋 파일을 탐색한다:

| 우선순위 | 구경로 | 설명 |
|---------|-------|------|
| 1 | `.claude/ralph-x-presets.json` | v1 경로 |
| 2 | `.ralph-x/state.json` | v0 경로 (매우 오래됨) |

신경로: `.claude/ralph-x-runs/presets.json`

**마이그레이션 로직:**

1. 구경로 파일이 하나도 없으면 → "마이그레이션 대상 없음" 출력, 종료
2. 신경로가 없으면 → 구경로 내용을 그대로 신경로에 복사
3. 신경로가 있으면 → 구경로의 프리셋 중 신경로에 없는 것만 merge
4. 마이그레이션 결과 보고 (이전된 프리셋 수)

**구 아티팩트 정리:**

마이그레이션 완료 후, 아래 파일들이 존재하면 목록 출력:
- `.claude/ralph-x-presets.json`
- `.claude/ralph-x-run.sh`
- `.claude/ralph-x-log.md`
- `.claude/ralph-x-checklist.md`
- `.ralph-x/state.json`

사용자에게 "이전 파일들을 삭제할까요?" 확인 후 삭제.

### Step 6: 완료

결과 요약 출력.
