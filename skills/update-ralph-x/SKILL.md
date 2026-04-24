---
name: update-ralph-x
description: ralph-x 최신 버전 확인 및 업데이트
allowed-tools: [Bash, Read, Write, Glob]
---

# /update-ralph-x

**Respond in the same language the user uses.** Korean → Korean. English → English.

## Step 1: 설치 경로 확인 + bootstrap

아래 코드를 **그대로** 실행한다. 경로나 파일명을 변경하지 않는다.

```bash
INSTALL_PATH=$(python3 -c "
import json
data = json.load(open('$HOME/.claude/plugins/installed_plugins.json'))
entries = data.get('plugins', {}).get('ralph-x@ralph-x', [])
print(entries[0]['installPath'] if entries else '')
")
SCRIPT="$INSTALL_PATH/scripts/update-check.sh"
if [ ! -f "$SCRIPT" ]; then
  mkdir -p "$INSTALL_PATH/scripts"
  curl -sf "https://raw.githubusercontent.com/kangraemin/ralph-x/main/scripts/update-check.sh" \
    -o "$SCRIPT" && chmod +x "$SCRIPT"
fi
echo "SCRIPT=$SCRIPT"
echo "EXISTS=$([ -f "$SCRIPT" ] && echo yes || echo no)"
```

- `EXISTS=no` → "update-check.sh를 다운로드할 수 없습니다." 출력 후 종료
- `EXISTS=yes` → Step 2 진행. `$SCRIPT` 값을 기억해둔다.

## Step 2: 버전 확인

Step 1에서 얻은 `$SCRIPT` 경로를 그대로 사용:

```bash
bash "<Step 1에서 출력된 SCRIPT 경로>" --check-only
```

## Step 3: 결과 처리

- `status: up-to-date` → "최신 버전입니다 (SHA)" 출력 → Step 5로 이동
- `status: update-available` → 현재/최신 SHA 보여주고 업데이트 여부 확인

## Step 4: 업데이트 실행

사용자 승인 시:

```bash
bash "<Step 1에서 출력된 SCRIPT 경로>" --force
```

## Step 4.5: .claude/ralph-x-runs/ 디렉토리 이동

아래 코드를 **그대로** 실행한다:

```bash
python3 -c "
import os, shutil, sys

old_dir = '.claude/ralph-x-runs'
new_dir = 'ralph-x-runs'

if not os.path.isdir(old_dir):
    print('NO_OLD_DIR')
    sys.exit(0)

os.makedirs(new_dir, exist_ok=True)

moved = []
skipped = []
for item in os.listdir(old_dir):
    src = os.path.join(old_dir, item)
    dst = os.path.join(new_dir, item)
    if os.path.exists(dst):
        skipped.append(item)
    else:
        shutil.move(src, dst)
        moved.append(item)

print(f'MOVED:{len(moved)} SKIPPED:{len(skipped)}')
if moved:
    print('moved: ' + ', '.join(moved))
if skipped:
    print('skipped (already exists): ' + ', '.join(skipped))
"
```

- `NO_OLD_DIR` → "이동 대상 없음 (.claude/ralph-x-runs/ 없음)"
- `MOVED:N SKIPPED:M` → 결과 출력 후 "`.claude/ralph-x-runs/`를 삭제할까요?" 확인. 승인 시 `rm -rf .claude/ralph-x-runs`

## Step 5: 프리셋 마이그레이션

아래 Python 코드를 **그대로** 실행한다:

```bash
python3 -c "
import json, os, sys

old_paths = [
    '.claude/ralph-x-runs/presets.json',
    '.claude/ralph-x-presets.json',
    '.ralph-x/state.json',
]
new_dir = 'ralph-x-runs'
new_path = os.path.join(new_dir, 'presets.json')

# 구경로에서 프리셋 수집
old_presets = {}
found_old = []
for p in old_paths:
    if os.path.isfile(p):
        try:
            with open(p) as f:
                data = json.load(f)
            old_presets.update(data)
            found_old.append(p)
        except:
            pass

if not found_old:
    print('NO_OLD_PRESETS')
    sys.exit(0)

# 신경로 존재 시 merge
if os.path.isfile(new_path):
    with open(new_path) as f:
        new_data = json.load(f)
    merged = 0
    for k, v in old_presets.items():
        if k not in new_data:
            new_data[k] = v
            merged += 1
    with open(new_path, 'w') as f:
        json.dump(new_data, f, indent=2, ensure_ascii=False)
    print(f'MERGED:{merged}')
else:
    os.makedirs(new_dir, exist_ok=True)
    with open(new_path, 'w') as f:
        json.dump(old_presets, f, indent=2, ensure_ascii=False)
    print(f'MIGRATED:{len(old_presets)}')

# 구 아티팩트 목록
artifacts = [
    '.claude/ralph-x-runs/presets.json',
    '.claude/ralph-x-presets.json',
    '.claude/ralph-x-run.sh',
    '.claude/ralph-x-log.md',
    '.claude/ralph-x-checklist.md',
    '.ralph-x/state.json',
]
existing = [a for a in artifacts if os.path.isfile(a)]
if existing:
    print('OLD_FILES:' + ','.join(existing))
"
```

- `NO_OLD_PRESETS` → "마이그레이션 대상 없음"
- `MIGRATED:N` → "N개 프리셋 마이그레이션 완료"
- `MERGED:N` → "N개 프리셋 merge 완료"
- `OLD_FILES:...` → 목록 출력 후 "이전 파일들을 삭제할까요?" 확인. 승인 시 `rm -f <파일들>`

## Step 6: 완료

결과 요약 출력.
