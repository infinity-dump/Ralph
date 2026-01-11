# Ralph quality gates helpers (sourced by ralph.sh).

ralph_quality_gates_enabled() {
  case "${RALPH_QUALITY_GATES:-}" in
    1|true|TRUE|yes|YES|strict)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_quality_gates_strict() {
  [[ "${RALPH_QUALITY_GATES:-}" == "strict" ]]
}

ralph_quality_gates_log() {
  echo "[quality] $*"
}

ralph_quality_gates_resolve_path() {
  local root="$1"
  local path="$2"

  if [[ "$path" == /* ]]; then
    echo "$path"
  else
    echo "$root/$path"
  fi
}

ralph_quality_gates_list_files() {
  local root="$1"
  local pattern="$2"

  if command -v rg >/dev/null 2>&1; then
    (cd "$root" && rg --files -g "$pattern" \
      -g '!**/.git/**' \
      -g '!**/node_modules/**' \
      -g '!**/.venv/**' \
      -g '!**/.next/**' \
      -g '!**/dist/**' \
      -g '!**/build/**' \
      -g '!**/coverage/**' \
      -g '!**/.ralph-cache/**' \
      -g '!**/vendor/**' 2>/dev/null || true)
    return 0
  fi

  (cd "$root" && find . \
    -type d \( -name .git -o -name node_modules -o -name .venv -o -name .next -o -name dist -o -name build -o -name coverage -o -name .ralph-cache -o -name vendor \) -prune -o \
    -type f -name "$pattern" -print 2>/dev/null | sed 's|^\./||')
}

ralph_quality_gates_has_files() {
  local root="$1"
  local pattern="$2"

  local first
  first="$(ralph_quality_gates_list_files "$root" "$pattern" | head -n 1)"
  [[ -n "$first" ]]
}

ralph_quality_gates_check_typescript() {
  local root="$1"

  if ! ralph_quality_gates_has_files "$root" "*.ts" && ! ralph_quality_gates_has_files "$root" "*.tsx" && [[ ! -f "$root/tsconfig.json" ]]; then
    ralph_quality_gates_log "TypeScript: skipped (no files)"
    return 0
  fi

  local tsc_cmd=""
  if [[ -x "$root/node_modules/.bin/tsc" ]]; then
    tsc_cmd="$root/node_modules/.bin/tsc"
  elif command -v tsc >/dev/null 2>&1; then
    tsc_cmd="tsc"
  fi

  if [[ -z "$tsc_cmd" ]]; then
    ralph_quality_gates_log "TypeScript: skipped (tsc not found)"
    return 0
  fi

  ralph_quality_gates_log "TypeScript: running tsc --noEmit"
  (cd "$root" && "$tsc_cmd" --noEmit)
}

ralph_quality_gates_check_python() {
  local root="$1"

  if ! ralph_quality_gates_has_files "$root" "*.py" && [[ ! -f "$root/pyproject.toml" ]] && [[ ! -f "$root/requirements.txt" ]]; then
    ralph_quality_gates_log "Python: skipped (no files)"
    return 0
  fi

  if command -v pyright >/dev/null 2>&1; then
    ralph_quality_gates_log "Python: running pyright"
    (cd "$root" && pyright)
    return $?
  fi

  if command -v ruff >/dev/null 2>&1; then
    ralph_quality_gates_log "Python: running ruff check"
    (cd "$root" && ruff check .)
    return $?
  fi

  ralph_quality_gates_log "Python: skipped (pyright/ruff not found)"
  return 0
}

ralph_quality_gates_check_go() {
  local root="$1"

  if [[ ! -f "$root/go.mod" ]] && ! ralph_quality_gates_has_files "$root" "*.go"; then
    ralph_quality_gates_log "Go: skipped (no files)"
    return 0
  fi

  if ! command -v go >/dev/null 2>&1; then
    ralph_quality_gates_log "Go: skipped (go not found)"
    return 0
  fi

  ralph_quality_gates_log "Go: running go test ./..."
  (cd "$root" && go test ./...)
}

ralph_quality_gates_check_rust() {
  local root="$1"

  if [[ ! -f "$root/Cargo.toml" ]] && ! ralph_quality_gates_has_files "$root" "*.rs"; then
    ralph_quality_gates_log "Rust: skipped (no files)"
    return 0
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    ralph_quality_gates_log "Rust: skipped (cargo not found)"
    return 0
  fi

  ralph_quality_gates_log "Rust: running cargo check"
  (cd "$root" && cargo check)
}

ralph_quality_gates_check_json() {
  local root="$1"

  local json_files
  json_files="$(ralph_quality_gates_list_files "$root" "*.json")"
  if [[ -z "$json_files" ]]; then
    ralph_quality_gates_log "JSON: skipped (no files)"
    return 0
  fi

  local tool=""
  if command -v jq >/dev/null 2>&1; then
    tool="jq"
  elif command -v python3 >/dev/null 2>&1; then
    tool="python3"
  elif command -v python >/dev/null 2>&1; then
    tool="python"
  fi

  if [[ -z "$tool" ]]; then
    ralph_quality_gates_log "JSON: skipped (jq/python not found)"
    return 0
  fi

  local failed=0
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local path
    path="$(ralph_quality_gates_resolve_path "$root" "$file")"
    if [[ "$tool" == "jq" ]]; then
      jq empty "$path" >/dev/null 2>&1 || {
        ralph_quality_gates_log "JSON: invalid $file"
        failed=1
      }
    else
      "$tool" -m json.tool "$path" >/dev/null 2>&1 || {
        ralph_quality_gates_log "JSON: invalid $file"
        failed=1
      }
    fi
  done <<<"$json_files"

  if (( failed == 0 )); then
    ralph_quality_gates_log "JSON: valid"
  fi

  return $failed
}

ralph_quality_gates_yaml_has_parser() {
  if command -v yq >/dev/null 2>&1; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' >/dev/null 2>&1
import importlib.util
import sys
sys.exit(0 if importlib.util.find_spec("yaml") else 1)
PY
    return $?
  fi

  if command -v python >/dev/null 2>&1; then
    python - <<'PY' >/dev/null 2>&1
import importlib.util
import sys
sys.exit(0 if importlib.util.find_spec("yaml") else 1)
PY
    return $?
  fi

  return 1
}

ralph_quality_gates_check_yaml() {
  local root="$1"

  local yaml_files
  yaml_files="$(ralph_quality_gates_list_files "$root" "*.yml")"
  yaml_files+=$'\n'"$(ralph_quality_gates_list_files "$root" "*.yaml")"
  yaml_files="$(echo "$yaml_files" | sed '/^$/d')"

  if [[ -z "$yaml_files" ]]; then
    ralph_quality_gates_log "YAML: skipped (no files)"
    return 0
  fi

  if ! ralph_quality_gates_yaml_has_parser; then
    ralph_quality_gates_log "YAML: skipped (no yaml parser found)"
    return 0
  fi

  local failed=0
  if command -v yq >/dev/null 2>&1; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      local path
      path="$(ralph_quality_gates_resolve_path "$root" "$file")"
      yq eval '.' "$path" >/dev/null 2>&1 || {
        ralph_quality_gates_log "YAML: invalid $file"
        failed=1
      }
    done <<<"$yaml_files"
  else
    local py_cmd
    if command -v python3 >/dev/null 2>&1; then
      py_cmd="python3"
    else
      py_cmd="python"
    fi

    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      local path
      path="$(ralph_quality_gates_resolve_path "$root" "$file")"
      "$py_cmd" - <<PY >/dev/null 2>&1
import sys, yaml
with open("$path", "r", encoding="utf-8") as f:
    yaml.safe_load(f)
PY
      if [[ $? -ne 0 ]]; then
        ralph_quality_gates_log "YAML: invalid $file"
        failed=1
      fi
    done <<<"$yaml_files"
  fi

  if (( failed == 0 )); then
    ralph_quality_gates_log "YAML: valid"
  fi

  return $failed
}

ralph_quality_gates_detect_test_command() {
  local root="$1"

  if [[ -f "$root/package.json" ]]; then
    local test_script=""
    if command -v jq >/dev/null 2>&1; then
      test_script="$(jq -r '.scripts.test // empty' "$root/package.json" 2>/dev/null || true)"
    elif command -v node >/dev/null 2>&1; then
      test_script="$(node -e 'try {const p=require("./package.json"); console.log((p.scripts && p.scripts.test) || "");} catch (e) {}' 2>/dev/null)"
    else
      test_script="$(grep -E '"test" *:' "$root/package.json" | head -n 1 | sed -E 's/.*"test" *: *"([^"]+)".*/\1/')"
    fi

    if [[ -n "$test_script" ]] && [[ "$test_script" != *"no test specified"* ]]; then
      if command -v npm >/dev/null 2>&1; then
        echo "npm test"
        return 0
      else
        ralph_quality_gates_log "Tests: skipped (npm not found)"
        return 1
      fi
    fi
  fi

  if [[ -f "$root/pyproject.toml" ]]; then
    local py_cmd=""
    if command -v python3 >/dev/null 2>&1; then
      py_cmd="python3"
    elif command -v python >/dev/null 2>&1; then
      py_cmd="python"
    fi

    if [[ -n "$py_cmd" ]]; then
      local detected=""
      detected="$($py_cmd - <<'PY' 2>/dev/null
import sys
try:
    import tomllib
except Exception:
    sys.exit(0)
from pathlib import Path
path = Path("pyproject.toml")
if not path.exists():
    sys.exit(0)
try:
    data = tomllib.loads(path.read_bytes())
except Exception:
    sys.exit(0)

tool = data.get("tool", {})
if "pytest" in tool or "pytest.ini_options" in tool:
    print("python -m pytest")
    sys.exit(0)

poetry = tool.get("poetry", {})
if "pytest" in poetry.get("dependencies", {}):
    print("python -m pytest")
    sys.exit(0)

group = poetry.get("group", {})
if isinstance(group, dict):
    dev = group.get("dev", {})
    if "pytest" in dev.get("dependencies", {}):
        print("python -m pytest")
        sys.exit(0)

sys.exit(0)
PY
)"
      if [[ -n "$detected" ]]; then
        echo "$detected"
        return 0
      fi
    fi

    if rg -n "^\[tool\.pytest" "$root/pyproject.toml" >/dev/null 2>&1; then
      echo "python -m pytest"
      return 0
    fi
  fi

  return 1
}

ralph_quality_gates_run_tests() {
  local root="$1"
  local test_cmd

  if ! test_cmd="$(ralph_quality_gates_detect_test_command "$root")"; then
    ralph_quality_gates_log "Tests: skipped (no test command detected)"
    return 0
  fi

  ralph_quality_gates_log "Tests: running $test_cmd"
  (cd "$root" && eval "$test_cmd")
}

ralph_quality_gates_check_prd() {
  local root="$1"
  local prd_file="$2"
  local story_id="$3"

  if [[ -z "$prd_file" ]]; then
    ralph_quality_gates_log "PRD: skipped (no prd file provided)"
    return 0
  fi

  if [[ ! -f "$prd_file" ]]; then
    ralph_quality_gates_log "PRD: skipped (file not found)"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    ralph_quality_gates_log "PRD: skipped (jq not found)"
    return 0
  fi

  if ! jq -e . "$prd_file" >/dev/null 2>&1; then
    ralph_quality_gates_log "PRD: invalid JSON"
    return 1
  fi

  local criteria_check
  criteria_check='[
    .userStories[]
    | select(.acceptanceCriteria == null or (.acceptanceCriteria | type != "array") or (.acceptanceCriteria | length == 0)
      or (all(.acceptanceCriteria[]; type == "string" and length > 0) | not))
  ] | length == 0'

  if ! jq -e "$criteria_check" "$prd_file" >/dev/null 2>&1; then
    ralph_quality_gates_log "PRD: acceptance criteria missing or invalid"
    return 1
  fi

  if [[ -n "$story_id" ]]; then
    if ! jq -e --arg id "$story_id" '.userStories[] | select(.id == $id)' "$prd_file" >/dev/null 2>&1; then
      ralph_quality_gates_log "PRD: story $story_id not found"
      return 1
    fi
  fi

  ralph_quality_gates_log "PRD: acceptance criteria present"
  return 0
}

ralph_quality_gates_run() {
  local prd_file="$1"
  local story_id="$2"

  if ! ralph_quality_gates_enabled; then
    return 0
  fi

  local strict=0
  if ralph_quality_gates_strict; then
    strict=1
  fi

  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

  ralph_quality_gates_log "Quality gates enabled (mode: ${RALPH_QUALITY_GATES})"

  local failures=0

  if ! ralph_quality_gates_check_typescript "$root"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_check_python "$root"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_check_go "$root"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_check_rust "$root"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_check_json "$root"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_check_yaml "$root"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_check_prd "$root" "$prd_file" "$story_id"; then
    failures=$((failures + 1))
  fi

  if ! ralph_quality_gates_run_tests "$root"; then
    failures=$((failures + 1))
  fi

  if (( failures > 0 )); then
    if (( strict == 1 )); then
      ralph_quality_gates_log "Quality gates failed (strict mode)."
      return 1
    fi

    ralph_quality_gates_log "Quality gates reported failures (non-blocking)."
  else
    ralph_quality_gates_log "Quality gates passed."
  fi

  return 0
}
