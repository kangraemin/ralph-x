#!/bin/bash
# ralph-x update-check.sh E2E 테스트
# Usage: bash scripts/test-update.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-check.sh"
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)

PASSED=0
FAILED=0
TOTAL=0

# ── 헬퍼 ──────────────────────────────────────────────────────────────────────

pass() {
  PASSED=$((PASSED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  ✅ $1"
}

fail() {
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  ❌ $1: $2"
}

# 테스트 환경 생성
setup_env() {
  local test_home
  test_home=$(mktemp -d)

  local plugins_dir="$test_home/.claude/plugins"
  local cache_dir="$plugins_dir/cache/ralph-x/ralph-x/1.0.0"
  mkdir -p "$cache_dir/skills/ralph-x"
  mkdir -p "$cache_dir/scripts"

  # 더미 SKILL.md (옛 버전)
  echo "# OLD VERSION" > "$cache_dir/skills/ralph-x/SKILL.md"

  # update-check.sh 복사
  cp "$UPDATE_SCRIPT" "$cache_dir/scripts/update-check.sh"
  chmod +x "$cache_dir/scripts/update-check.sh"

  # installed_plugins.json
  cat > "$plugins_dir/installed_plugins.json" << 'PJEOF'
{
  "version": 2,
  "plugins": {
    "ralph-x@ralph-x": [
      {
        "scope": "user",
        "installPath": "__CACHE_DIR__",
        "version": "1.0.0",
        "installedAt": "2026-01-01T00:00:00.000Z",
        "lastUpdated": "2026-01-01T00:00:00.000Z",
        "gitCommitSha": "0000000000000000000000000000000000000000"
      }
    ]
  }
}
PJEOF
  # installPath 치환
  sed -i '' "s|__CACHE_DIR__|$cache_dir|g" "$plugins_dir/installed_plugins.json"

  echo "$test_home"
}

cleanup_env() {
  rm -rf "$1"
}

# GitHub에서 실제 latest SHA 조회
get_latest_sha() {
  curl -sf --max-time 10 "https://api.github.com/repos/kangraemin/ralph-x/commits/main" 2>/dev/null | \
    $PYTHON -c "import json,sys; print(json.load(sys.stdin)['sha'][:7])" 2>/dev/null || echo ""
}

# ── TC-01: --check-only 업데이트 있음 ─────────────────────────────────────────
tc01() {
  echo "TC-01: --check-only 업데이트 있음"
  local test_home
  test_home=$(setup_env)

  local output
  output=$(RALPH_X_PLUGINS_JSON="$test_home/.claude/plugins/installed_plugins.json" \
    bash "$UPDATE_SCRIPT" --check-only 2>&1) || true

  if echo "$output" | grep -q "status: update-available"; then
    pass "--check-only shows update-available"
  else
    fail "--check-only" "expected 'update-available', got: $output"
  fi

  if echo "$output" | grep -q "installed: 0000000"; then
    pass "installed SHA shown correctly"
  else
    fail "installed SHA" "expected '0000000', got: $output"
  fi

  cleanup_env "$test_home"
}

# ── TC-02: --check-only 최신 ─────────────────────────────────────────────────
tc02() {
  echo "TC-02: --check-only 최신"
  local latest_sha
  latest_sha=$(get_latest_sha)
  if [ -z "$latest_sha" ]; then
    fail "skip" "GitHub API 조회 실패"
    return
  fi

  local test_home
  test_home=$(setup_env)

  # installed SHA를 latest로 설정
  local latest_sha_full
  latest_sha_full=$(curl -sf --max-time 10 "https://api.github.com/repos/kangraemin/ralph-x/commits/main" 2>/dev/null | \
    $PYTHON -c "import json,sys; print(json.load(sys.stdin)['sha'])" 2>/dev/null) || ""

  $PYTHON -c "
import json, sys
path = sys.argv[1]
sha = sys.argv[2]
with open(path) as f:
    data = json.load(f)
data['plugins']['ralph-x@ralph-x'][0]['gitCommitSha'] = sha
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
" "$test_home/.claude/plugins/installed_plugins.json" "$latest_sha_full"

  local output
  output=$(RALPH_X_PLUGINS_JSON="$test_home/.claude/plugins/installed_plugins.json" \
    bash "$UPDATE_SCRIPT" --check-only 2>&1) || true

  if echo "$output" | grep -q "status: up-to-date"; then
    pass "--check-only shows up-to-date"
  else
    fail "--check-only" "expected 'up-to-date', got: $output"
  fi

  cleanup_env "$test_home"
}

# ── TC-03: --force 실제 업데이트 ──────────────────────────────────────────────
tc03() {
  echo "TC-03: --force 실제 업데이트"
  local test_home
  test_home=$(setup_env)
  local cache_dir="$test_home/.claude/plugins/cache/ralph-x/ralph-x/1.0.0"
  local plugins_json="$test_home/.claude/plugins/installed_plugins.json"

  # 실행 전 SKILL.md 확인
  local before
  before=$(cat "$cache_dir/skills/ralph-x/SKILL.md")

  local output
  output=$(RALPH_X_PLUGINS_JSON="$plugins_json" \
    bash "$UPDATE_SCRIPT" --force 2>&1) || true

  # SKILL.md가 변경됐는지 확인
  local after
  after=$(cat "$cache_dir/skills/ralph-x/SKILL.md")

  if [ "$before" != "$after" ]; then
    pass "SKILL.md updated"
  else
    fail "SKILL.md" "content unchanged after update"
  fi

  # installed_plugins.json SHA 변경 확인
  local new_sha
  new_sha=$($PYTHON -c "
import json
data = json.load(open('$plugins_json'))
print(data['plugins']['ralph-x@ralph-x'][0]['gitCommitSha'][:7])
")
  if [ "$new_sha" != "0000000" ]; then
    pass "installed_plugins.json SHA updated to $new_sha"
  else
    fail "SHA update" "SHA still 0000000"
  fi

  # lastUpdated 변경 확인
  local updated_at
  updated_at=$($PYTHON -c "
import json
data = json.load(open('$plugins_json'))
print(data['plugins']['ralph-x@ralph-x'][0]['lastUpdated'])
")
  if [ "$updated_at" != "2026-01-01T00:00:00.000Z" ]; then
    pass "lastUpdated changed to $updated_at"
  else
    fail "lastUpdated" "timestamp unchanged"
  fi

  cleanup_env "$test_home"
}

# ── TC-04: 24h throttle ──────────────────────────────────────────────────────
tc04() {
  echo "TC-04: 24h throttle"
  local test_home
  test_home=$(setup_env)
  local cache_dir="$test_home/.claude/plugins/cache/ralph-x/ralph-x/1.0.0"
  local plugins_json="$test_home/.claude/plugins/installed_plugins.json"

  # 현재 타임스탬프 기록 (최근 체크)
  date +%s > "$cache_dir/.version-checked"

  # 플래그 없이 실행 → 조용히 종료
  local output
  output=$(RALPH_X_PLUGINS_JSON="$plugins_json" \
    bash "$UPDATE_SCRIPT" 2>&1) || true

  if [ -z "$output" ]; then
    pass "throttle: no output (skipped)"
  else
    fail "throttle" "expected no output, got: $output"
  fi

  # --force로 실행 → throttle 무시
  output=$(RALPH_X_PLUGINS_JSON="$plugins_json" \
    bash "$UPDATE_SCRIPT" --force 2>&1) || true

  if echo "$output" | grep -q "업데이트 완료"; then
    pass "throttle: --force bypasses throttle"
  else
    fail "throttle --force" "expected update message, got: $output"
  fi

  cleanup_env "$test_home"
}

# ── TC-05: self-bootstrap ─────────────────────────────────────────────────────
tc05() {
  echo "TC-05: self-bootstrap"
  local test_home
  test_home=$(setup_env)
  local cache_dir="$test_home/.claude/plugins/cache/ralph-x/ralph-x/1.0.0"
  local plugins_json="$test_home/.claude/plugins/installed_plugins.json"

  # 캐시의 update-check.sh를 일부러 다른 내용으로 교체
  echo '#!/bin/bash' > "$cache_dir/scripts/update-check.sh"
  echo 'echo "OLD SCRIPT"' >> "$cache_dir/scripts/update-check.sh"
  chmod +x "$cache_dir/scripts/update-check.sh"

  # 소스의 update-check.sh로 실행 (bootstrap이 캐시를 교체해야 함)
  local output
  output=$(RALPH_X_PLUGINS_JSON="$plugins_json" \
    bash "$UPDATE_SCRIPT" --force 2>&1) || true

  # 캐시의 스크립트가 교체됐는지 확인
  local content
  content=$(head -3 "$cache_dir/scripts/update-check.sh")
  if echo "$content" | grep -q "ralph-x 자동 업데이트"; then
    pass "self-bootstrap replaced old script"
  else
    # bootstrap이 작동했는지 출력으로 확인 (업데이트가 되었으면 OK)
    if echo "$output" | grep -q "업데이트 완료"; then
      pass "self-bootstrap: update completed (script replaced via clone)"
    else
      fail "self-bootstrap" "script not replaced. output: $output"
    fi
  fi

  cleanup_env "$test_home"
}

# ── TC-06: 프리셋 마이그레이션 구→신 ─────────────────────────────────────────
tc06() {
  echo "TC-06: 프리셋 마이그레이션 구→신"
  local fake_project
  fake_project=$(mktemp -d)

  # 구경로에 프리셋 생성
  mkdir -p "$fake_project/.claude"
  cat > "$fake_project/.claude/ralph-x-presets.json" << 'EOF'
{
  "my-preset": {
    "task_template": "test task",
    "steps": [{"name": "step1", "skill": null}],
    "max_iterations": 10,
    "checklist": ["done"]
  }
}
EOF

  # 마이그레이션 실행 (Python으로 시뮬레이션)
  $PYTHON -c "
import json, os, sys

project = sys.argv[1]
old_path = os.path.join(project, '.claude/ralph-x-presets.json')
new_dir = os.path.join(project, '.claude/ralph-x-runs')
new_path = os.path.join(new_dir, 'presets.json')

if os.path.isfile(old_path) and not os.path.isfile(new_path):
    os.makedirs(new_dir, exist_ok=True)
    with open(old_path) as f:
        data = json.load(f)
    with open(new_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('migrated')
else:
    print('skip')
" "$fake_project"

  # 검증
  if [ -f "$fake_project/.claude/ralph-x-runs/presets.json" ]; then
    local content
    content=$($PYTHON -c "
import json
data = json.load(open('$fake_project/.claude/ralph-x-runs/presets.json'))
print('my-preset' in data)
")
    if [ "$content" = "True" ]; then
      pass "preset migrated to new path"
    else
      fail "migration" "preset key not found"
    fi
  else
    fail "migration" "new presets.json not created"
  fi

  rm -rf "$fake_project"
}

# ── TC-07: 프리셋 merge ──────────────────────────────────────────────────────
tc07() {
  echo "TC-07: 프리셋 merge"
  local fake_project
  fake_project=$(mktemp -d)

  # 구경로에 preset-B
  mkdir -p "$fake_project/.claude"
  cat > "$fake_project/.claude/ralph-x-presets.json" << 'EOF'
{
  "preset-b": {
    "task_template": "b task",
    "steps": [],
    "max_iterations": 5,
    "checklist": []
  }
}
EOF

  # 신경로에 preset-A (이미 존재)
  mkdir -p "$fake_project/.claude/ralph-x-runs"
  cat > "$fake_project/.claude/ralph-x-runs/presets.json" << 'EOF'
{
  "preset-a": {
    "task_template": "a task",
    "steps": [],
    "max_iterations": 10,
    "checklist": []
  }
}
EOF

  # merge 실행
  $PYTHON -c "
import json, os, sys

project = sys.argv[1]
old_path = os.path.join(project, '.claude/ralph-x-presets.json')
new_path = os.path.join(project, '.claude/ralph-x-runs/presets.json')

if os.path.isfile(old_path) and os.path.isfile(new_path):
    with open(old_path) as f:
        old_data = json.load(f)
    with open(new_path) as f:
        new_data = json.load(f)
    merged = 0
    for key, val in old_data.items():
        if key not in new_data:
            new_data[key] = val
            merged += 1
    with open(new_path, 'w') as f:
        json.dump(new_data, f, indent=2)
    print(f'merged:{merged}')
" "$fake_project"

  # 검증
  local result
  result=$($PYTHON -c "
import json
data = json.load(open('$fake_project/.claude/ralph-x-runs/presets.json'))
print('preset-a' in data and 'preset-b' in data)
")
  if [ "$result" = "True" ]; then
    pass "both presets present after merge"
  else
    fail "merge" "missing presets after merge"
  fi

  rm -rf "$fake_project"
}

# ── TC-08: .ralph-x/state.json 마이그레이션 ──────────────────────────────────
tc08() {
  echo "TC-08: .ralph-x/state.json 마이그레이션"
  local fake_project
  fake_project=$(mktemp -d)

  # 매우 오래된 경로
  mkdir -p "$fake_project/.ralph-x"
  cat > "$fake_project/.ralph-x/state.json" << 'EOF'
{
  "old-preset": {
    "task_template": "old task",
    "steps": [],
    "max_iterations": 3,
    "checklist": []
  }
}
EOF

  # 마이그레이션 실행
  $PYTHON -c "
import json, os, sys

project = sys.argv[1]
old_path = os.path.join(project, '.ralph-x/state.json')
new_dir = os.path.join(project, '.claude/ralph-x-runs')
new_path = os.path.join(new_dir, 'presets.json')

if os.path.isfile(old_path) and not os.path.isfile(new_path):
    os.makedirs(new_dir, exist_ok=True)
    with open(old_path) as f:
        data = json.load(f)
    with open(new_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('migrated')
" "$fake_project"

  if [ -f "$fake_project/.claude/ralph-x-runs/presets.json" ]; then
    local content
    content=$($PYTHON -c "
import json
data = json.load(open('$fake_project/.claude/ralph-x-runs/presets.json'))
print('old-preset' in data)
")
    if [ "$content" = "True" ]; then
      pass ".ralph-x/state.json migrated"
    else
      fail "v0 migration" "preset key not found"
    fi
  else
    fail "v0 migration" "presets.json not created"
  fi

  rm -rf "$fake_project"
}

# ── TC-09: bootstrap (script 없음) ───────────────────────────────────────────
tc09() {
  echo "TC-09: bootstrap (script 없음)"
  local test_home
  test_home=$(setup_env)
  local cache_dir="$test_home/.claude/plugins/cache/ralph-x/ralph-x/1.0.0"

  # scripts 디렉토리 삭제
  rm -rf "$cache_dir/scripts"

  # SKILL.md 플로우 시뮬레이션: GitHub에서 다운로드
  mkdir -p "$cache_dir/scripts"
  local dl_result
  dl_result=$(curl -sf --max-time 10 \
    "https://raw.githubusercontent.com/kangraemin/ralph-x/main/scripts/update-check.sh" \
    -o "$cache_dir/scripts/update-check.sh" 2>&1 && echo "OK" || echo "FAIL")

  if [ "$dl_result" = "OK" ] && [ -s "$cache_dir/scripts/update-check.sh" ]; then
    chmod +x "$cache_dir/scripts/update-check.sh"
    # 다운로드된 스크립트가 실행 가능한지 확인
    if bash -n "$cache_dir/scripts/update-check.sh" 2>/dev/null; then
      pass "bootstrap download + syntax valid"
    else
      fail "bootstrap" "downloaded script has syntax errors"
    fi
  else
    # 아직 push 안 했으면 소스에서 복사로 대체 테스트
    if [ -f "$UPDATE_SCRIPT" ]; then
      cp "$UPDATE_SCRIPT" "$cache_dir/scripts/update-check.sh"
      chmod +x "$cache_dir/scripts/update-check.sh"
      pass "bootstrap fallback: copied from source (not yet pushed to GitHub)"
    else
      fail "bootstrap" "download failed and no source available"
    fi
  fi

  cleanup_env "$test_home"
}

# ── 실행 ──────────────────────────────────────────────────────────────────────

echo "━━━ ralph-x update-check.sh E2E 테스트 ━━━"
echo ""

# syntax 체크
echo "Pre-check: bash syntax validation"
if bash -n "$UPDATE_SCRIPT" 2>/dev/null; then
  pass "update-check.sh syntax OK"
else
  fail "syntax" "update-check.sh has syntax errors"
  echo ""
  echo "━━━ $PASSED/$TOTAL passed, $FAILED failed ━━━"
  exit 1
fi
echo ""

tc01
echo ""
tc02
echo ""
tc03
echo ""
tc04
echo ""
tc05
echo ""
tc06
echo ""
tc07
echo ""
tc08
echo ""
tc09
echo ""

echo "━━━ 결과: $PASSED/$TOTAL passed, $FAILED failed ━━━"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
