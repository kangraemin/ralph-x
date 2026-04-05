#!/bin/bash
# ralph-x 자동 업데이트 체커
# Usage: update-check.sh [--force] [--check-only]
#   --force      : 24h throttle 무시하고 즉시 체크
#   --check-only : 버전 확인만 (업데이트 안 함)

set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)

REPO="${RALPH_X_REPO:-kangraemin/ralph-x}"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"
API_URL="https://api.github.com/repos/$REPO/commits/main"

PLUGINS_JSON="${RALPH_X_PLUGINS_JSON:-$HOME/.claude/plugins/installed_plugins.json}"
PLUGIN_KEY="ralph-x@ralph-x"

# ── 옵션 파싱 ──────────────────────────────────────────────────────────────────
FORCE=false
CHECK_ONLY=false
for arg in "$@"; do
  case $arg in
    --force)      FORCE=true ;;
    --check-only) CHECK_ONLY=true ;;
  esac
done

# ── 설치 경로 감지 ────────────────────────────────────────────────────────────
CACHE_DIR=$($PYTHON -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    entries = data.get('plugins', {}).get(sys.argv[2], [])
    if entries:
        print(entries[0].get('installPath', ''))
    else:
        print('')
except:
    print('')
" "$PLUGINS_JSON" "$PLUGIN_KEY" 2>/dev/null) || ""

if [ -z "$CACHE_DIR" ] || [ ! -d "$CACHE_DIR" ]; then
  echo "ralph-x: 설치 정보를 찾을 수 없습니다" >&2
  exit 1
fi

CHECKED_FILE="$CACHE_DIR/.version-checked"

# ── 24시간 throttle ───────────────────────────────────────────────────────────
if [ "$FORCE" = false ] && [ "$CHECK_ONLY" = false ] && [ -f "$CHECKED_FILE" ]; then
  LAST=$(cat "$CHECKED_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  DIFF=$(( NOW - LAST ))
  if [ "$DIFF" -lt 86400 ]; then
    exit 0
  fi
fi

# ── 최신 SHA 조회 ────────────────────────────────────────────────────────────
LATEST_SHA=$(curl -sf --max-time 5 "$API_URL" 2>/dev/null | $PYTHON -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['sha'][:7])
except:
    sys.exit(1)
" 2>/dev/null) || {
  echo "ralph-x: 네트워크 오류, 업데이트 체크 건너뜀" >&2
  exit 0
}

LATEST_SHA_FULL=$(curl -sf --max-time 5 "$API_URL" 2>/dev/null | $PYTHON -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['sha'])
except:
    sys.exit(1)
" 2>/dev/null) || ""

# 체크 타임스탬프 갱신
date +%s > "$CHECKED_FILE"

# ── 설치된 버전 확인 ─────────────────────────────────────────────────────────
INSTALLED_SHA=$($PYTHON -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    entries = data.get('plugins', {}).get(sys.argv[2], [])
    if entries:
        print(entries[0].get('gitCommitSha', 'unknown')[:7])
    else:
        print('unknown')
except:
    print('unknown')
" "$PLUGINS_JSON" "$PLUGIN_KEY" 2>/dev/null) || echo "unknown"

if [ "$CHECK_ONLY" = true ]; then
  echo "installed: $INSTALLED_SHA"
  echo "latest:    $LATEST_SHA"
  if [ "$LATEST_SHA" = "$INSTALLED_SHA" ]; then
    echo "status: up-to-date"
  else
    echo "status: update-available"
  fi
  exit 0
fi

# ── 업데이트 필요 없으면 종료 ────────────────────────────────────────────────
if [ "$LATEST_SHA" = "$INSTALLED_SHA" ]; then
  exit 0
fi

# ── bootstrap: 자기 자신을 먼저 업데이트 후 재실행 ────────────────────────────
SELF_SCRIPT="$CACHE_DIR/scripts/update-check.sh"
if [ "${_UPDATE_BOOTSTRAPPED:-}" != "1" ]; then
  SELF_TMP=$(mktemp) || { echo "ralph-x: mktemp failed" >&2; exit 0; }
  trap 'rm -f "$SELF_TMP"' EXIT
  if curl -sf --max-time 10 "$RAW_BASE/scripts/update-check.sh" -o "$SELF_TMP" 2>/dev/null; then
    if [ -s "$SELF_TMP" ] && bash -n "$SELF_TMP" 2>/dev/null; then
      if ! cmp -s "$SELF_TMP" "$SELF_SCRIPT"; then
        mkdir -p "$(dirname "$SELF_SCRIPT")"
        mv "$SELF_TMP" "$SELF_SCRIPT"
        chmod +x "$SELF_SCRIPT"
        trap - EXIT
        export _UPDATE_BOOTSTRAPPED=1
        exec bash "$SELF_SCRIPT" --force
      fi
    else
      echo "ralph-x: 다운로드 파일 검증 실패, 업데이트 건너뜀" >&2
    fi
  fi
  rm -f "$SELF_TMP"
  trap - EXIT
fi

# ── git clone → 캐시 덮어쓰기 ────────────────────────────────────────────────
CLONE_DIR=$(mktemp -d) || { echo "ralph-x: mktemp -d failed" >&2; exit 0; }
trap 'rm -rf "$CLONE_DIR"' EXIT

if ! git clone --depth 1 "https://github.com/$REPO.git" "$CLONE_DIR/ralph-x" -q 2>/dev/null; then
  echo "ralph-x: git clone 실패, 업데이트 건너뜀" >&2
  exit 0
fi

# 캐시에 복사 (기존 파일 덮어쓰기)
for item in skills scripts .claude-plugin README.md README.ko.md LICENSE; do
  src="$CLONE_DIR/ralph-x/$item"
  if [ -e "$src" ]; then
    if [ -d "$src" ]; then
      cp -R "$src" "$CACHE_DIR/"
    else
      cp "$src" "$CACHE_DIR/"
    fi
  fi
done

# ── installed_plugins.json 업데이트 ──────────────────────────────────────────
if [ -n "$LATEST_SHA_FULL" ]; then
  $PYTHON -c "
import json, sys
from datetime import datetime, timezone

plugins_path = sys.argv[1]
plugin_key = sys.argv[2]
new_sha = sys.argv[3]

with open(plugins_path) as f:
    data = json.load(f)

entries = data.get('plugins', {}).get(plugin_key, [])
if entries:
    entries[0]['gitCommitSha'] = new_sha
    entries[0]['lastUpdated'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z')

with open(plugins_path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
" "$PLUGINS_JSON" "$PLUGIN_KEY" "$LATEST_SHA_FULL"
fi

echo "ralph-x $INSTALLED_SHA → $LATEST_SHA 업데이트 완료"
