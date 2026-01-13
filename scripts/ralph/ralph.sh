#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_FILE="${PROMPT_FILE:-$SCRIPT_DIR/prompt.md}"
PRD_FILE="${PRD_FILE:-$SCRIPT_DIR/prd.json}"
PROGRESS_FILE="${PROGRESS_FILE:-$SCRIPT_DIR/progress.txt}"
MODULE_DIR="$SCRIPT_DIR/modules"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

# ═══════════════════════════════════════════════════════════════════════════════
# TUI Colors and Styling
# ═══════════════════════════════════════════════════════════════════════════════
RALPH_NO_COLOR="${RALPH_NO_COLOR:-0}"

ralph_colors_enabled() {
  [[ "$RALPH_NO_COLOR" != "1" ]] && [[ -t 1 ]]
}

if ralph_colors_enabled; then
  C_RESET='\033[0m'
  C_BOLD='\033[1m'
  C_DIM='\033[2m'
  C_ITALIC='\033[3m'
  C_UNDERLINE='\033[4m'
  # Colors
  C_RED='\033[0;31m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_BLUE='\033[0;34m'
  C_MAGENTA='\033[0;35m'
  C_CYAN='\033[0;36m'
  C_WHITE='\033[0;37m'
  # Bright colors
  C_BRED='\033[1;31m'
  C_BGREEN='\033[1;32m'
  C_BYELLOW='\033[1;33m'
  C_BBLUE='\033[1;34m'
  C_BMAGENTA='\033[1;35m'
  C_BCYAN='\033[1;36m'
  C_BWHITE='\033[1;37m'
  # Background
  C_BG_RED='\033[41m'
  C_BG_GREEN='\033[42m'
  C_BG_YELLOW='\033[43m'
  C_BG_BLUE='\033[44m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_ITALIC='' C_UNDERLINE=''
  C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN='' C_WHITE=''
  C_BRED='' C_BGREEN='' C_BYELLOW='' C_BBLUE='' C_BMAGENTA='' C_BCYAN='' C_BWHITE=''
  C_BG_RED='' C_BG_GREEN='' C_BG_YELLOW='' C_BG_BLUE=''
fi

ralph_print_banner() {
  if [[ "${RALPH_NO_BANNER:-}" == "1" ]]; then
    return 0
  fi
  echo -e "${C_BYELLOW}"
  cat << 'BANNER'
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                                                                       ║
    ║      ██████╗  █████╗ ██╗     ██████╗ ██╗  ██╗                         ║
    ║      ██╔══██╗██╔══██╗██║     ██╔══██╗██║  ██║                         ║
    ║      ██████╔╝███████║██║     ██████╔╝███████║                         ║
    ║      ██╔══██╗██╔══██║██║     ██╔═══╝ ██╔══██║                         ║
    ║      ██║  ██║██║  ██║███████╗██║     ██║  ██║                         ║
    ║      ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝                         ║
    ║                                                                       ║
BANNER
  echo -e "${C_CYAN}"
  cat << 'BANNER'
    ║                    ░░░░░░░░░░░░░░░░░░░░░                              ║
    ║                 ░░░░░░░░░░░░░░░░░░░░░░░░░░░                           ║
    ║               ░░░░░░░░░░░▓▓▓▓▓▓▓░░░░░░░░░░░░                          ║
    ║              ░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░                          ║
    ║             ░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░                         ║
    ║            ░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░                         ║
    ║            ░░░░░▓▓▓▓▓▓●▓▓▓▓▓▓▓▓●▓▓▓▓▓▓▓░░░░░░                         ║
    ║            ░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░                         ║
    ║            ░░░░░▓▓▓▓▓▓▓▓▓███▓▓▓▓▓▓▓▓▓▓▓░░░░░░                         ║
    ║             ░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░                         ║
    ║              ░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░                          ║
    ║               ░░░░░░░░▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░                            ║
    ║                 ░░░░░░░░░░░░░░░░░░░░░░░░░                              ║
BANNER
  echo -e "${C_BMAGENTA}"
  cat << 'BANNER'
    ║                                                                       ║
    ║           "Me fail English? That's unpossible!"                       ║
    ║                                        - Ralph Wiggum                 ║
    ║                                                                       ║
    ╠═══════════════════════════════════════════════════════════════════════╣
BANNER
  echo -e "${C_BWHITE}"
  cat << 'BANNER'
    ║        🤖 Autonomous Agent Loop for Code Generation 🤖               ║
    ╚═══════════════════════════════════════════════════════════════════════╝
BANNER
  echo -e "${C_RESET}"
}

ralph_print_separator() {
  local char="${1:-─}"
  local width="${2:-75}"
  local color="${3:-$C_DIM}"
  echo -e "${color}$(printf '%*s' "$width" '' | tr ' ' "$char")${C_RESET}"
}

ralph_print_box_line() {
  local text="$1"
  local color="${2:-$C_CYAN}"
  echo -e "${color}│${C_RESET} $text"
}

# Colorize agent output (Codex/Claude style)
ralph_colorize_output() {
  if ! ralph_colors_enabled; then
    cat
    return 0
  fi

  # Use awk for line-by-line colorization
  awk -v reset="$C_RESET" \
      -v dim="$C_DIM" \
      -v cyan="$C_CYAN" \
      -v bcyan="$C_BCYAN" \
      -v yellow="$C_YELLOW" \
      -v byellow="$C_BYELLOW" \
      -v green="$C_GREEN" \
      -v bgreen="$C_BGREEN" \
      -v red="$C_RED" \
      -v bred="$C_BRED" \
      -v blue="$C_BLUE" \
      -v bblue="$C_BBLUE" \
      -v magenta="$C_MAGENTA" \
      -v bmagenta="$C_BMAGENTA" \
      -v white="$C_WHITE" \
      -v bwhite="$C_BWHITE" \
      -v bold="$C_BOLD" \
  '
  BEGIN {
    in_code_block = 0
  }

  # Code blocks
  /^```/ {
    if (in_code_block) {
      print dim $0 reset
      in_code_block = 0
    } else {
      print dim $0 reset
      in_code_block = 1
    }
    next
  }

  in_code_block {
    print dim $0 reset
    next
  }

  # Thinking tags
  /^thinking$/ || /^<thinking>/ || /^<\/thinking>/ {
    print magenta "💭 " $0 reset
    next
  }

  # Exec commands
  /^exec$/ {
    print bblue "⚡ " $0 reset
    next
  }

  # Command execution lines
  /^\/bin\// || /^\/usr\// {
    print blue "  → " $0 reset
    next
  }

  # Success messages
  /succeeded/ {
    print bgreen "✓ " $0 reset
    next
  }

  # Failed messages
  /failed/ || /error/i || /Error/ {
    print bred "✗ " $0 reset
    next
  }

  # Headers (markdown style)
  /^### / {
    sub(/^### /, "")
    print byellow "   ▸ " bold $0 reset
    next
  }

  /^## / {
    sub(/^## /, "")
    print byellow "  ▸▸ " bold $0 reset
    next
  }

  /^# / {
    sub(/^# /, "")
    print byellow " ▸▸▸ " bold $0 reset
    next
  }

  # Bold text **text**
  /\*\*[^*]+\*\*/ {
    gsub(/\*\*([^*]+)\*\*/, bwhite "&" reset)
    gsub(/\*\*/, "")
    print $0
    next
  }

  # Italic text *text* (single asterisk)
  /\*[^*]+\*/ {
    # Only process if not part of ** pattern
    if (!match($0, /\*\*/)) {
      gsub(/\*([^*]+)\*/, dim "&" reset)
      gsub(/\*/, "")
    }
    print $0
    next
  }

  # File paths
  /^\// || /\.swift/ || /\.ts/ || /\.js/ || /\.py/ || /\.go/ || /\.rs/ {
    print cyan $0 reset
    next
  }

  # Line numbers with content (grep-style output)
  /^[0-9]+:/ {
    match($0, /^[0-9]+:/)
    line_num = substr($0, 1, RLENGTH)
    rest = substr($0, RLENGTH + 1)
    print dim line_num reset rest
    next
  }

  # Default
  { print $0 }
  '
}

RALPH_LOG_ACTIVE=0
RALPH_RUN_STARTED=0
RALPH_RUN_START_TS=""
RALPH_RUN_STATUS=""
RALPH_STOP_REASON=""
ITERATIONS_RUN=0
INITIAL_COMPLETED=""
TOTAL_STORIES=""
RALPH_TEST_CMD_OVERRIDE="${RALPH_TEST_CMD:-}"
RALPH_TEST_FRAMEWORK_OVERRIDE="${RALPH_TEST_FRAMEWORK:-}"
RALPH_TEST_CMD=""
RALPH_TEST_FRAMEWORK=""
RALPH_TEST_CMD_SOURCE=""

ralph_is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

ralph_is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_external_enabled() {
  ralph_is_truthy "${RALPH_ALLOW_EXTERNAL:-}"
}

ralph_verbose_enabled() {
  ralph_is_truthy "${RALPH_VERBOSE:-}"
}

ralph_log() {
  echo -e "${C_BWHITE}$*${C_RESET}"
}

ralph_log_error() {
  echo -e "${C_BRED}✗ $*${C_RESET}" >&2
}

ralph_log_verbose() {
  if ralph_verbose_enabled; then
    echo -e "${C_DIM}$*${C_RESET}"
  fi
}

ralph_log_success() {
  echo -e "${C_BGREEN}✓ $*${C_RESET}"
}

ralph_log_warn() {
  echo -e "${C_BYELLOW}⚠ $*${C_RESET}"
}

ralph_log_info() {
  echo -e "${C_BCYAN}ℹ $*${C_RESET}"
}

ralph_log_step() {
  echo -e "${C_BBLUE}▸ $*${C_RESET}"
}

ralph_external_context() {
  if ! ralph_external_enabled; then
    return 0
  fi

  local mcp_config="${RALPH_MCP_CONFIG:-${MCP_CONFIG:-}}"
  local mcp_servers="${RALPH_MCP_SERVERS:-${MCP_SERVERS:-}}"

  cat <<EOF
# External Tool Access
External access: enabled (RALPH_ALLOW_EXTERNAL=1)
MCP config: ${mcp_config:-not set}
MCP servers: ${mcp_servers:-not set}
Notes: MCP-style tools may be available when configured. Use pre/post hooks to start or stop external services.
EOF
}

ralph_hook_export_env() {
  local stage="$1"
  local iteration="$2"
  local max_iterations="$3"
  local timestamp="$4"
  local status="${5:-}"
  local reason="${6:-}"

  export RALPH_HOOK_STAGE="$stage"
  export RALPH_HOOK_ITERATION="$iteration"
  export RALPH_HOOK_MAX_ITERATIONS="$max_iterations"
  export RALPH_HOOK_TIMESTAMP="$timestamp"
  export RALPH_HOOK_MODE="${RALPH_MODE:-stories}"
  export RALPH_HOOK_PHASE="${RALPH_PHASE_CURRENT:-}"
  export RALPH_HOOK_TESTS_MODE="${TESTS_MODE:-0}"
  export RALPH_HOOK_STORY_ID="${STORY_ID:-}"
  export RALPH_HOOK_STORY_TITLE="${STORY_TITLE:-}"
  export RALPH_HOOK_STORY_STATUS="${STORY_STATUS:-}"
  export RALPH_HOOK_STORY_PRIORITY="${STORY_PRIORITY:-}"
  export RALPH_HOOK_STORY_DEPENDENCIES="${STORY_DEPS:-}"
  export RALPH_HOOK_AGENT_EXIT="${AGENT_EXIT:-}"
  export RALPH_HOOK_ITERATION_STATUS="$status"
  export RALPH_HOOK_FAILURE_REASON="$reason"
  export RALPH_HOOK_TEST_CMD="${RALPH_TEST_CMD:-}"
  export RALPH_HOOK_TEST_FRAMEWORK="${RALPH_TEST_FRAMEWORK:-}"
  export RALPH_HOOK_TESTS_EXIT="${TESTS_EXIT:-}"
  export RALPH_HOOK_TESTS_PROGRESS="${TESTS_PROGRESS:-}"
  export RALPH_HOOK_QUALITY_STATUS="${QUALITY_STATUS:-}"
  export RALPH_HOOK_REVIEW_FAILED="${REVIEW_FAILED:-}"
}

ralph_hook_run() {
  local hook="$1"
  local stage="$2"
  local cwd="${3:-}"

  if [[ -z "$hook" ]]; then
    return 0
  fi

  ralph_log "Hook (${stage}): ${hook}"

  local status=0
  set +e
  if [[ -n "$cwd" ]]; then
    (cd "$cwd" && bash -c "$hook")
  else
    bash -c "$hook"
  fi
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    ralph_log_error "Hook (${stage}) failed (exit ${status})."
  fi

  return "$status"
}

ralph_mode_tests_enabled() {
  case "${RALPH_MODE:-stories}" in
    tests|test)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*[mK]//g'
}

ralph_tests_set_var() {
  local name="$1"
  local value="${2-}"
  printf -v "$name" "%s" "$value"
}

ralph_tests_detect_js_framework() {
  local root="$1"
  local test_script="${2:-}"
  local frameworks=("vitest" "jest" "mocha" "ava" "tap" "playwright" "cypress")

  local fw
  for fw in "${frameworks[@]}"; do
    if [[ -n "$test_script" && "$test_script" == *"$fw"* ]]; then
      echo "$fw"
      return 0
    fi
  done

  if [[ -f "$root/vitest.config.js" || -f "$root/vitest.config.ts" ]]; then
    echo "vitest"
    return 0
  fi
  if [[ -f "$root/jest.config.js" || -f "$root/jest.config.ts" || -f "$root/jest.config.cjs" ]]; then
    echo "jest"
    return 0
  fi
  if [[ -f "$root/mocha.opts" || -f "$root/.mocharc.js" || -f "$root/.mocharc.json" ]]; then
    echo "mocha"
    return 0
  fi
  if [[ -f "$root/playwright.config.js" || -f "$root/playwright.config.ts" ]]; then
    echo "playwright"
    return 0
  fi
  if [[ -f "$root/cypress.config.js" || -f "$root/cypress.config.ts" ]]; then
    echo "cypress"
    return 0
  fi

  if [[ -f "$root/package.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      for fw in "${frameworks[@]}"; do
        if jq -e --arg fw "$fw" \
          '.devDependencies[$fw] or .dependencies[$fw] or (.scripts.test // "" | test($fw))' \
          "$root/package.json" >/dev/null 2>&1; then
          echo "$fw"
          return 0
        fi
      done
    else
      for fw in "${frameworks[@]}"; do
        if grep -q "\"$fw\"" "$root/package.json" 2>/dev/null; then
          echo "$fw"
          return 0
        fi
      done
    fi
  fi

  return 1
}

ralph_tests_detect_runner() {
  local root="$1"

  local override="${RALPH_TEST_CMD_OVERRIDE:-}"
  RALPH_TEST_CMD=""
  RALPH_TEST_FRAMEWORK=""
  RALPH_TEST_CMD_SOURCE=""

  if [[ -n "$override" ]]; then
    RALPH_TEST_CMD="$override"
    if [[ -n "${RALPH_TEST_FRAMEWORK_OVERRIDE:-}" ]]; then
      RALPH_TEST_FRAMEWORK="$RALPH_TEST_FRAMEWORK_OVERRIDE"
    else
      RALPH_TEST_FRAMEWORK="custom"
    fi
    RALPH_TEST_CMD_SOURCE="env"
    return 0
  fi

  if [[ -f "$root/package.json" ]]; then
    local test_script=""
    if command -v jq >/dev/null 2>&1; then
      test_script="$(jq -r '.scripts.test // empty' "$root/package.json" 2>/dev/null || true)"
    elif command -v node >/dev/null 2>&1; then
      test_script="$(node -e 'try {const p=require("./package.json"); console.log((p.scripts && p.scripts.test) || "");} catch (e) {}' 2>/dev/null)"
    else
      test_script="$(grep -E '"test" *:' "$root/package.json" | head -n 1 | sed -E 's/.*"test" *: *"([^"]+)".*/\1/' || true)"
    fi

    if [[ -n "$test_script" ]] && [[ "$test_script" != *"no test specified"* ]]; then
      local manager=""
      if [[ -f "$root/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then
        manager="pnpm"
      elif [[ -f "$root/yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then
        manager="yarn"
      elif command -v npm >/dev/null 2>&1; then
        manager="npm"
      elif command -v pnpm >/dev/null 2>&1; then
        manager="pnpm"
      elif command -v yarn >/dev/null 2>&1; then
        manager="yarn"
      fi

      if [[ -n "$manager" ]]; then
        RALPH_TEST_CMD="${manager} test"
        RALPH_TEST_FRAMEWORK="$(ralph_tests_detect_js_framework "$root" "$test_script" || true)"
        if [[ -z "$RALPH_TEST_FRAMEWORK" ]]; then
          RALPH_TEST_FRAMEWORK="node"
        fi
        RALPH_TEST_CMD_SOURCE="package.json"
        return 0
      fi
    fi
  fi

  local py_cmd=""
  if command -v python3 >/dev/null 2>&1; then
    py_cmd="python3"
  elif command -v python >/dev/null 2>&1; then
    py_cmd="python"
  fi

  local pytest_detected=0
  if [[ -f "$root/pytest.ini" || -f "$root/tox.ini" || -f "$root/conftest.py" ]]; then
    pytest_detected=1
  fi
  if [[ -f "$root/pyproject.toml" ]] && grep -q "pytest" "$root/pyproject.toml" 2>/dev/null; then
    pytest_detected=1
  fi
  if [[ -f "$root/setup.cfg" ]] && grep -q "pytest" "$root/setup.cfg" 2>/dev/null; then
    pytest_detected=1
  fi
  if [[ -f "$root/requirements.txt" ]] && grep -q "pytest" "$root/requirements.txt" 2>/dev/null; then
    pytest_detected=1
  fi

  if [[ "$pytest_detected" -eq 1 && -n "$py_cmd" ]]; then
    RALPH_TEST_CMD="${py_cmd} -m pytest"
    RALPH_TEST_FRAMEWORK="pytest"
    RALPH_TEST_CMD_SOURCE="python"
    return 0
  fi

  if [[ -f "$root/go.mod" ]] && command -v go >/dev/null 2>&1; then
    if find "$root" -name '*_test.go' -print -quit 2>/dev/null | grep -q .; then
      RALPH_TEST_CMD="go test ./..."
      RALPH_TEST_FRAMEWORK="go"
      RALPH_TEST_CMD_SOURCE="go"
      return 0
    fi
  fi

  if [[ -f "$root/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
    RALPH_TEST_CMD="cargo test"
    RALPH_TEST_FRAMEWORK="cargo"
    RALPH_TEST_CMD_SOURCE="cargo"
    return 0
  fi

  return 1
}

ralph_tests_parse_counts() {
  local file="$1"
  local framework="${2:-}"
  local passed=""
  local failed=""
  local total=""

  local tests_line
  tests_line="$(grep -E "Tests:" "$file" 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$tests_line" ]]; then
    if [[ "$tests_line" =~ ([0-9]+)[[:space:]]+passed ]]; then
      passed="${BASH_REMATCH[1]}"
    fi
    if [[ "$tests_line" =~ ([0-9]+)[[:space:]]+failed ]]; then
      failed="${BASH_REMATCH[1]}"
    fi
    if [[ "$tests_line" =~ ([0-9]+)[[:space:]]+total ]]; then
      total="${BASH_REMATCH[1]}"
    fi
  fi

  local pytest_line
  pytest_line="$(grep -E "=+ .* (passed|failed|error)" "$file" 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$pytest_line" ]]; then
    local pytest_pass=""
    local pytest_fail=""
    local pytest_error=""
    if [[ "$pytest_line" =~ ([0-9]+)[[:space:]]+passed ]]; then
      pytest_pass="${BASH_REMATCH[1]}"
    fi
    if [[ "$pytest_line" =~ ([0-9]+)[[:space:]]+failed ]]; then
      pytest_fail="${BASH_REMATCH[1]}"
    fi
    if [[ "$pytest_line" =~ ([0-9]+)[[:space:]]+error ]]; then
      pytest_error="${BASH_REMATCH[1]}"
    fi
    if [[ -n "$pytest_pass" ]]; then
      passed="$pytest_pass"
    fi
    if [[ -n "$pytest_fail" || -n "$pytest_error" ]]; then
      local fail_total=0
      if ralph_is_int "${pytest_fail:-}"; then
        fail_total=$((fail_total + pytest_fail))
      fi
      if ralph_is_int "${pytest_error:-}"; then
        fail_total=$((fail_total + pytest_error))
      fi
      failed="$fail_total"
    fi
  fi

  local cargo_line
  cargo_line="$(grep -E "test result:" "$file" 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$cargo_line" ]]; then
    if [[ "$cargo_line" =~ ([0-9]+)[[:space:]]+passed ]]; then
      passed="${BASH_REMATCH[1]}"
    fi
    if [[ "$cargo_line" =~ ([0-9]+)[[:space:]]+failed ]]; then
      failed="${BASH_REMATCH[1]}"
    fi
  fi

  local mocha_pass
  local mocha_fail
  mocha_pass="$(grep -E "[0-9]+ passing" "$file" 2>/dev/null | tail -n 1 || true)"
  mocha_fail="$(grep -E "[0-9]+ failing" "$file" 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$mocha_pass" ]]; then
    if [[ "$mocha_pass" =~ ([0-9]+)[[:space:]]+passing ]]; then
      passed="${BASH_REMATCH[1]}"
    fi
  fi
  if [[ -n "$mocha_fail" ]]; then
    if [[ "$mocha_fail" =~ ([0-9]+)[[:space:]]+failing ]]; then
      failed="${BASH_REMATCH[1]}"
    fi
  fi

  if [[ "$framework" == "go" ]]; then
    local go_total=0
    local go_pass=0
    local go_fail=0
    go_total="$(grep -c "^=== RUN" "$file" 2>/dev/null || true)"
    go_pass="$(grep -c "^--- PASS" "$file" 2>/dev/null || true)"
    go_fail="$(grep -c "^--- FAIL" "$file" 2>/dev/null || true)"
    if ralph_is_int "$go_total" && (( go_total > 0 )); then
      total="$go_total"
      passed="$go_pass"
      failed="$go_fail"
    elif ralph_is_int "$go_pass" || ralph_is_int "$go_fail"; then
      if ralph_is_int "$go_pass"; then
        passed="$go_pass"
      fi
      if ralph_is_int "$go_fail"; then
        failed="$go_fail"
      fi
    fi
  fi

  if [[ -z "$total" ]]; then
    if ralph_is_int "$passed" && ralph_is_int "$failed"; then
      total=$((passed + failed))
    fi
  fi
  if [[ -z "$failed" ]]; then
    if ralph_is_int "$total" && ralph_is_int "$passed"; then
      if (( total >= passed )); then
        failed=$((total - passed))
      fi
    fi
  fi
  if [[ -z "$passed" ]]; then
    if ralph_is_int "$total" && ralph_is_int "$failed"; then
      if (( total >= failed )); then
        passed=$((total - failed))
      fi
    fi
  fi

  echo "${passed}|${total}|${failed}"
}

ralph_tests_format_progress() {
  local passed="${1:-}"
  local total="${2:-}"
  local failed="${3:-}"

  if ralph_is_int "$total"; then
    local passed_count=0
    local failed_count=""
    if ralph_is_int "$passed"; then
      passed_count="$passed"
    fi
    if ralph_is_int "$failed"; then
      failed_count="$failed"
    fi
    if [[ -n "$failed_count" ]]; then
      echo "${passed_count}/${total} passing (${failed_count} failing)"
    else
      echo "${passed_count}/${total} passing"
    fi
    return 0
  fi

  if ralph_is_int "$passed"; then
    echo "${passed} passing"
    return 0
  fi

  echo "counts unavailable"
}

ralph_tests_failure_snippet() {
  local file="$1"
  local max_lines="${2:-120}"

  local snippet
  snippet="$(grep -nE "FAIL|FAILED|ERROR|Error|AssertionError|Traceback" "$file" 2>/dev/null | head -n 40 || true)"
  if [[ -z "$snippet" ]]; then
    snippet="$(tail -n "$max_lines" "$file" 2>/dev/null || true)"
  fi
  printf "%s\n" "$snippet"
}

ralph_tests_run() {
  local prefix="$1"
  local root="$2"
  local cmd="$3"
  local framework="${4:-}"
  local phase="${5:-run}"

  local output_file
  output_file="$(mktemp)"
  local clean_file
  clean_file="$(mktemp)"

  ralph_log "Tests (${phase}): running ${cmd}"
  set +e
  if [[ "$RALPH_LOG_ACTIVE" -eq 1 ]]; then
    (cd "$root" && eval "$cmd") 2>&1 | tee "$output_file" | ralph_colorize_output
    local status="${PIPESTATUS[0]:-0}"
  else
    (cd "$root" && eval "$cmd") 2>&1 | tee "$output_file" | ralph_colorize_output
    local status="${PIPESTATUS[0]:-0}"
  fi
  set -e

  ralph_strip_ansi < "$output_file" > "$clean_file"

  local counts
  counts="$(ralph_tests_parse_counts "$clean_file" "$framework")"
  local passed=""
  local total=""
  local failed=""
  IFS='|' read -r passed total failed <<<"$counts"

  local progress
  progress="$(ralph_tests_format_progress "$passed" "$total" "$failed")"

  local snippet=""
  if [[ "$status" -ne 0 ]]; then
    snippet="$(ralph_tests_failure_snippet "$clean_file")"
  fi

  ralph_tests_set_var "${prefix}_TEST_EXIT" "$status"
  ralph_tests_set_var "${prefix}_TEST_PASSED" "$passed"
  ralph_tests_set_var "${prefix}_TEST_TOTAL" "$total"
  ralph_tests_set_var "${prefix}_TEST_FAILED" "$failed"
  ralph_tests_set_var "${prefix}_TEST_PROGRESS" "$progress"
  ralph_tests_set_var "${prefix}_TEST_SNIPPET" "$snippet"

  rm -f "$output_file" "$clean_file"
}

ralph_tests_context() {
  local prefix="$1"
  local exit_var="${prefix}_TEST_EXIT"
  local passed_var="${prefix}_TEST_PASSED"
  local total_var="${prefix}_TEST_TOTAL"
  local failed_var="${prefix}_TEST_FAILED"
  local progress_var="${prefix}_TEST_PROGRESS"
  local snippet_var="${prefix}_TEST_SNIPPET"

  local exit_status="${!exit_var-}"
  local passed="${!passed_var-}"
  local total="${!total_var-}"
  local failed="${!failed_var-}"
  local progress="${!progress_var-}"
  local snippet="${!snippet_var-}"
  local status_label="unknown"
  if ralph_is_int "$exit_status"; then
    if (( exit_status == 0 )); then
      status_label="passed"
    else
      status_label="failed"
    fi
  fi

  cat <<EOF
# Ralph Test Status
Mode: tests
Framework: ${RALPH_TEST_FRAMEWORK:-unknown}
Command: ${RALPH_TEST_CMD:-not detected}
Last run: ${status_label}${exit_status:+ (exit ${exit_status})}
Tests: ${progress:-counts unavailable}

Goal: fix failing tests and make the suite pass.
EOF

  if [[ "$status_label" == "failed" && -n "$snippet" ]]; then
    cat <<EOF

Failing test output (excerpt):
${snippet}
EOF
  fi
}

ralph_log_init() {
  local log="${RALPH_LOG:-}"
  if [[ -z "$log" ]]; then
    return 0
  fi

  log="${log/#\~/$HOME}"
  local dir
  dir="$(dirname "$log")"
  if [[ -n "$dir" && "$dir" != "." ]]; then
    mkdir -p "$dir"
  fi

  if ! touch "$log"; then
    ralph_log_error "Unable to write log file: $log"
    exit 1
  fi

  exec > >(tee -a "$log") 2>&1
  RALPH_LOG_ACTIVE=1
  ralph_log "Logging to $log"
}

ralph_format_duration() {
  local total="${1:-}"
  if ! ralph_is_int "$total"; then
    return 1
  fi
  local hours=$((total / 3600))
  local mins=$(((total % 3600) / 60))
  local secs=$((total % 60))
  printf "%02d:%02d:%02d" "$hours" "$mins" "$secs"
}

ralph_count_completed_stories() {
  local prd_file="$1"
  if [[ ! -f "$prd_file" ]]; then
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  jq '[.userStories[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null
}

ralph_count_total_stories() {
  local prd_file="$1"
  if [[ ! -f "$prd_file" ]]; then
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  jq '(.userStories // []) | length' "$prd_file" 2>/dev/null
}

ralph_iteration_banner() {
  local iteration="$1"
  local max_iterations="$2"
  local status="$3"
  local ts="${4:-}"

  local status_color="$C_BYELLOW"
  local status_icon="⟳"
  case "$status" in
    running)
      status_color="$C_BYELLOW"
      status_icon="⟳"
      ;;
    success)
      status_color="$C_BGREEN"
      status_icon="✓"
      ;;
    failed)
      status_color="$C_BRED"
      status_icon="✗"
      ;;
  esac

  local progress_bar=""
  local progress_pct=$((iteration * 100 / max_iterations))
  local filled=$((progress_pct / 5))
  local empty=$((20 - filled))
  progress_bar="${C_BGREEN}$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) || true)${C_DIM}$(printf '░%.0s' $(seq 1 $empty 2>/dev/null) || true)${C_RESET}"

  echo ""
  echo -e "${C_BBLUE}╔══════════════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "${C_BBLUE}║${C_RESET}  ${C_BWHITE}ITERATION${C_RESET} ${C_BCYAN}${iteration}${C_DIM}/${max_iterations}${C_RESET}  ${progress_bar}  ${status_color}${status_icon} ${status}${C_RESET}"
  if [[ -n "$ts" ]]; then
    echo -e "${C_BBLUE}║${C_RESET}  ${C_DIM}${ts}${C_RESET}"
  fi
  echo -e "${C_BBLUE}╚══════════════════════════════════════════════════════════════════════════╝${C_RESET}"
}

ralph_run_summary() {
  local exit_code="$1"
  local end_ts
  end_ts="$(date +%s)"

  local status="failed"
  if [[ -n "${RALPH_RUN_STATUS:-}" ]]; then
    status="$RALPH_RUN_STATUS"
  elif [[ "$exit_code" -eq 0 ]]; then
    status="success"
  fi

  local duration=""
  if ralph_is_int "$end_ts" && ralph_is_int "${RALPH_RUN_START_TS:-}"; then
    duration="$(ralph_format_duration $((end_ts - RALPH_RUN_START_TS)) || true)"
  fi

  local completed=""
  local total=""
  completed="$(ralph_count_completed_stories "$PRD_FILE" || true)"
  total="$(ralph_count_total_stories "$PRD_FILE" || true)"

  local status_color="$C_BRED"
  local status_icon="✗"
  case "$status" in
    success)
      status_color="$C_BGREEN"
      status_icon="✓"
      ;;
    stopped|paused)
      status_color="$C_BYELLOW"
      status_icon="⏸"
      ;;
  esac

  echo ""
  echo -e "${C_BMAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "${C_BMAGENTA}║${C_RESET}  ${C_BWHITE}📊 RALPH SUMMARY${C_RESET}"
  echo -e "${C_BMAGENTA}╠══════════════════════════════════════════════════════════════════════════╣${C_RESET}"
  echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Status:${C_RESET}            ${status_color}${status_icon} ${status}${C_RESET}"
  echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Iterations:${C_RESET}        ${C_BCYAN}${ITERATIONS_RUN:-0}${C_DIM}/${MAX_ITERATIONS:-unknown}${C_RESET}"

  if [[ -n "$completed" ]]; then
    if [[ -n "$total" ]]; then
      echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Completed stories:${C_RESET} ${C_BGREEN}${completed}${C_DIM}/${total}${C_RESET}"
    else
      echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Completed stories:${C_RESET} ${C_BGREEN}${completed}${C_RESET}"
    fi

    if ralph_is_int "${INITIAL_COMPLETED:-}" && ralph_is_int "$completed"; then
      local delta=$((completed - INITIAL_COMPLETED))
      if (( delta >= 0 )); then
        echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Completed this run:${C_RESET} ${C_BGREEN}+${delta}${C_RESET}"
      fi
    fi
  else
    echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Completed stories:${C_RESET} ${C_DIM}unavailable (jq not found)${C_RESET}"
  fi

  if [[ -n "$duration" ]]; then
    echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Elapsed time:${C_RESET}      ${C_BCYAN}${duration}${C_RESET}"
  fi

  local cost_line="${C_DIM}unavailable${C_RESET}"
  if [[ -n "${RALPH_COST_TOTAL_CENTS:-}" && -n "${RALPH_COST_ENTRIES:-}" ]]; then
    if declare -F ralph_cost_control_format_cents >/dev/null 2>&1; then
      local cost_fmt
      cost_fmt="$(ralph_cost_control_format_cents "$RALPH_COST_TOTAL_CENTS" || true)"
      if [[ -n "$cost_fmt" ]]; then
        cost_line="${C_BYELLOW}${cost_fmt}${C_RESET}"
        if ralph_is_int "${RALPH_COST_ENTRIES:-}" && ralph_is_int "${RALPH_COST_ITERATION_COUNT:-}"; then
          cost_line="${cost_line} ${C_DIM}(tracked: ${RALPH_COST_ENTRIES}/${RALPH_COST_ITERATION_COUNT})${C_RESET}"
        fi
      fi
    fi
  fi
  echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Cost estimate:${C_RESET}     ${cost_line}"

  if [[ "${RALPH_STOP_REASON:-}" == "stuck_story" ]]; then
    echo -e "${C_BMAGENTA}╠══════════════════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "${C_BMAGENTA}║${C_RESET}  ${C_BRED}⚠ FAILURE ANALYSIS${C_RESET}"
    echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Story${C_RESET} ${C_BYELLOW}${RALPH_CB_STUCK_STORY_ID:-unknown}${C_RESET} ${C_DIM}failed${C_RESET} ${C_BRED}${RALPH_CB_STUCK_FAILURES:-?}${C_RESET} ${C_DIM}times${C_RESET}"
    echo -e "${C_BMAGENTA}║${C_RESET}  ${C_DIM}Consider splitting the story or reviewing dependencies.${C_RESET}"
  fi

  if [[ "$exit_code" -ne 0 && -n "${LAST_FAILURE_REASON:-}" ]]; then
    echo -e "${C_BMAGENTA}╠══════════════════════════════════════════════════════════════════════════╣${C_RESET}"
    echo -e "${C_BMAGENTA}║${C_RESET}  ${C_BRED}Last failure:${C_RESET} ${LAST_FAILURE_REASON}"
  fi

  echo -e "${C_BMAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
}

ralph_on_exit() {
  local exit_code="$1"

  if declare -F ralph_git_guard_cleanup >/dev/null 2>&1; then
    ralph_git_guard_cleanup
  fi
  if declare -F ralph_cost_control_report >/dev/null 2>&1; then
    ralph_cost_control_report
  fi
  if [[ "${RALPH_RUN_STARTED:-0}" == "1" ]]; then
    ralph_run_summary "$exit_code"

    # Send notification on run complete
    if declare -F ralph_monitor_on_run_complete >/dev/null 2>&1; then
      ralph_monitor_on_run_complete \
        "${RALPH_RUN_STATUS:-unknown}" \
        "${RALPH_STOP_REASON:-}" \
        "${ITERATIONS_RUN:-0}" \
        "${MAX_ITERATIONS:-0}"
    fi
  fi
  if declare -F ralph_monitor_cleanup >/dev/null 2>&1; then
    ralph_monitor_cleanup
  fi
}

ralph_init_templates() {
  local force=0

  case "${1:-}" in
    --force)
      force=1
      shift
      ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") init [--force]
Copies template files from ${TEMPLATE_DIR} into ${SCRIPT_DIR}.
EOF
      return 0
      ;;
  esac

  local -a mappings=(
    "prd-template.json:prd.json"
    "prompt-template.md:prompt.md"
    "progress-template.txt:progress.txt"
  )
  local map
  local missing=0
  local copied=0

  for map in "${mappings[@]}"; do
    local src="$TEMPLATE_DIR/${map%%:*}"
    local dest="$SCRIPT_DIR/${map##*:}"

    if [[ ! -f "$src" ]]; then
      echo "Missing template: $src" >&2
      missing=1
      continue
    fi

    if [[ -f "$dest" && "$force" -ne 1 ]]; then
      echo "Exists, skipping: $dest" >&2
      continue
    fi

    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "Wrote $dest"
    copied=1
  done

  if (( missing == 1 )); then
    return 1
  fi

  if (( copied == 0 )); then
    echo "No files copied. Use --force to overwrite existing files." >&2
  fi
}

if [[ "${1:-}" == "init" ]]; then
  shift
  ralph_init_templates "$@"
  exit $?
fi

if [[ "${1:-}" == "generate-prd" ]]; then
  shift
  if [[ -f "$MODULE_DIR/prd-generator.sh" ]]; then
    # shellcheck source=./modules/prd-generator.sh
    source "$MODULE_DIR/prd-generator.sh"
  else
    echo "Missing module: $MODULE_DIR/prd-generator.sh" >&2
    exit 1
  fi

  ralph_prd_generator_main "$PRD_FILE" "$@"
  exit $?
fi

if [[ "${1:-}" == "monitor" ]]; then
  shift
  if [[ -f "$MODULE_DIR/monitor.sh" ]]; then
    # shellcheck source=./modules/monitor.sh
    source "$MODULE_DIR/monitor.sh"
  else
    echo "Missing module: $MODULE_DIR/monitor.sh" >&2
    exit 1
  fi

  ralph_monitor_cli "$@"
  exit $?
fi

ralph_log_init
if ralph_verbose_enabled; then
  ralph_log "Verbose mode enabled."
fi

RALPH_MODE="${RALPH_MODE:-stories}"
case "$RALPH_MODE" in
  stories|tests)
    ;;
  *)
    ralph_log_error "Unknown RALPH_MODE '$RALPH_MODE'; defaulting to stories."
    RALPH_MODE="stories"
    ;;
esac

TESTS_MODE=0
if ralph_mode_tests_enabled; then
  TESTS_MODE=1
  ralph_log "Mode: tests (test-driven loop)."
fi

RESUME=0
if [[ "${1:-}" == "--resume" ]]; then
  RESUME=1
  shift
fi

MAX_ITERATIONS_ARG="${1:-}"

if [[ -f "$MODULE_DIR/circuit-breaker.sh" ]]; then
  # shellcheck source=./modules/circuit-breaker.sh
  source "$MODULE_DIR/circuit-breaker.sh"
fi
if [[ -f "$MODULE_DIR/quality-gates.sh" ]]; then
  # shellcheck source=./modules/quality-gates.sh
  source "$MODULE_DIR/quality-gates.sh"
fi
if [[ -f "$MODULE_DIR/planner.sh" ]]; then
  # shellcheck source=./modules/planner.sh
  source "$MODULE_DIR/planner.sh"
fi
if [[ -f "$MODULE_DIR/reviewer.sh" ]]; then
  # shellcheck source=./modules/reviewer.sh
  source "$MODULE_DIR/reviewer.sh"
fi
if [[ -f "$MODULE_DIR/git-guard.sh" ]]; then
  # shellcheck source=./modules/git-guard.sh
  source "$MODULE_DIR/git-guard.sh"
fi
if [[ -f "$MODULE_DIR/parallel.sh" ]]; then
  # shellcheck source=./modules/parallel.sh
  source "$MODULE_DIR/parallel.sh"
fi
if [[ -f "$MODULE_DIR/checkpoint.sh" ]]; then
  # shellcheck source=./modules/checkpoint.sh
  source "$MODULE_DIR/checkpoint.sh"
fi
if [[ -f "$MODULE_DIR/cache.sh" ]]; then
  # shellcheck source=./modules/cache.sh
  source "$MODULE_DIR/cache.sh"
fi
if [[ -f "$MODULE_DIR/cost-control.sh" ]]; then
  # shellcheck source=./modules/cost-control.sh
  source "$MODULE_DIR/cost-control.sh"
fi
if [[ -f "$MODULE_DIR/monitor.sh" ]]; then
  # shellcheck source=./modules/monitor.sh
  source "$MODULE_DIR/monitor.sh"
fi

extract_progress_patterns() {
  local progress_file="$1"

  if [[ ! -f "$progress_file" ]]; then
    return 0
  fi

  awk '
    BEGIN {found=0}
    /^##[[:space:]]+Codebase Patterns/ {found=1; next}
    found && /^##[[:space:]]+/ {exit}
    found {print}
  ' "$progress_file"
}

build_iteration_context() {
  local iteration="$1"
  local max_iterations="$2"
  local timestamp="$3"
  local git_branch
  local git_sha
  local git_status
  local patterns_raw
  local patterns

  git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  git_sha="$(git rev-parse --short HEAD 2>/dev/null || true)"
  git_status="$(git -c color.status=false status -sb 2>/dev/null || true)"
  patterns_raw="$(extract_progress_patterns "$PROGRESS_FILE")"

  printf "%s\n" "# Ralph Iteration Context"
  printf "Iteration: %s / %s\n" "$iteration" "$max_iterations"
  printf "Timestamp: %s\n" "$timestamp"
  if [[ -n "${RALPH_PHASE_CURRENT:-}" ]]; then
    printf "Phase: %s\n" "$RALPH_PHASE_CURRENT"
  fi
  printf "Git Branch: %s\n" "${git_branch:-unknown}"
  printf "Git Commit: %s\n" "${git_sha:-unknown}"
  printf "\nGit Status:\n%s\n\n" "${git_status:-Unavailable}"

  if [[ "${RALPH_CONTEXT_SUMMARY:-}" == "1" ]]; then
    patterns="$(printf "%s\n" "$patterns_raw" | sed '/^[[:space:]]*$/d')"
    if [[ -n "$patterns" ]]; then
      printf "Codebase Patterns (from progress.txt):\n%s\n\n" "$patterns"
    fi
  fi
}

select_story() {
  if ! command -v jq >/dev/null 2>&1; then
    return 0
  fi

  local phase=""
  local include_unassigned="1"
  if [[ "${RALPH_PHASE_CHAINING_ACTIVE:-0}" == "1" ]]; then
    phase="${RALPH_PHASE_CURRENT:-}"
    include_unassigned="${RALPH_PHASE_INCLUDE_UNSPECIFIED:-1}"
    if [[ ! "$include_unassigned" =~ ^[0-9]+$ ]]; then
      include_unassigned="1"
    fi
  fi

  local target_story="${RALPH_STORY_ID:-${RALPH_TARGET_STORY:-}}"
  if [[ -n "$target_story" ]]; then
    jq -c --arg id "$target_story" '
      def normalized_status:
        if .passes == true then "completed"
        elif .status then .status
        else "pending"
        end;
      def normalized_priority:
        if (.priority | type) == "number" then .priority
        elif (.priority | type) == "string" then
          if .priority == "high" then 1
          elif .priority == "medium" then 5
          elif .priority == "low" then 9
          else 5 end
        else 5 end
        | if . < 1 then 1 elif . > 10 then 10 else . end;
      def dependencies_list:
        if (.dependencies | type) == "array" then .dependencies else [] end;

      . as $root
      | ($root.userStories // []) as $stories
      | $stories
      | to_entries
      | map(.value as $story
          | {
              story: $story,
              index: .key,
              status: ($story | normalized_status),
              priority: ($story | normalized_priority),
              dependencies: ($story | dependencies_list)
            })
      | map(select(.story.id == $id))
      | .[0] // empty
    ' "$PRD_FILE" 2>/dev/null || true
    return 0
  fi

  jq -c --arg phase "$phase" --argjson include_unassigned "$include_unassigned" '
    def normalized_status:
      if .passes == true then "completed"
      elif .status then .status
      else "pending"
      end;
    def normalized_priority:
      if (.priority | type) == "number" then .priority
      elif (.priority | type) == "string" then
        if .priority == "high" then 1
        elif .priority == "medium" then 5
        elif .priority == "low" then 9
        else 5 end
      else 5 end
      | if . < 1 then 1 elif . > 10 then 10 else . end;
    def dependencies_list:
      if (.dependencies | type) == "array" then .dependencies else [] end;
    def phase_list:
      if (.phase | type) == "string" then [ .phase ]
      elif (.phases | type) == "array" then .phases
      elif (.tags | type) == "array" then .tags
      else [] end;
    def in_phase($phase; $include_unassigned):
      if $phase == "" then true
      else
        (phase_list | index($phase) != null)
        or ($include_unassigned == 1 and (phase_list | length == 0))
      end;

    . as $root
    | ($root.userStories // []) as $stories
    | ($stories | map(select((. | normalized_status) == "completed") | .id)) as $completed
    | $stories
    | to_entries
    | map(.value as $story
        | {
            story: $story,
            index: .key,
            status: ($story | normalized_status),
            priority: ($story | normalized_priority),
            dependencies: ($story | dependencies_list)
          })
    | map(select(.status != "completed" and .status != "blocked"))
    | map(select(
        (.dependencies | length == 0)
        or all(.dependencies[]; $completed | index(.) != null)
      ))
    | map(select(.story | in_phase($phase; $include_unassigned)))
    | sort_by(.priority, .index)
    | .[0] // empty
  ' "$PRD_FILE" 2>/dev/null || true
}

story_passed() {
  local story_id="$1"

  if [[ -z "$story_id" ]]; then
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  jq -e --arg id "$story_id" \
    '.userStories[] | select(.id == $id) | .passes == true' \
    "$PRD_FILE" >/dev/null 2>&1
}

detect_model_name() {
  if [[ -n "${RALPH_AGENT:-}" ]]; then
    ralph_agent_normalize "$RALPH_AGENT"
    return
  fi

  if [[ -n "${AGENT_CMD[0]:-}" ]]; then
    ralph_agent_normalize "$(basename "${AGENT_CMD[0]}")"
  fi
}

ralph_agent_normalize() {
  local name="${1:-}"

  name="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
  case "$name" in
    "")
      echo ""
      ;;
    codex*)
      echo "codex"
      ;;
    claude*)
      echo "claude"
      ;;
    aider*)
      echo "aider"
      ;;
    custom)
      echo "custom"
      ;;
    *)
      echo "$name"
      ;;
  esac
}

ralph_agent_prompt_context() {
  local agent="$1"

  case "$agent" in
    codex)
      cat <<'EOF'
# Agent Preset
Agent: codex
Notes: Running via Codex CLI in non-interactive mode.
EOF
      ;;
    claude)
      cat <<'EOF'
# Agent Preset
Agent: claude
Notes: Running via Claude Code CLI in non-interactive mode.
EOF
      ;;
    aider)
      cat <<'EOF'
# Agent Preset
Agent: aider
Notes: Running via Aider in batch mode; avoid interactive prompts.
EOF
      ;;
  esac
}

ralph_agent_apply_preset() {
  local preset="$1"

  case "$preset" in
    codex)
      AGENT_CMD=(codex exec --dangerously-bypass-approvals-and-sandbox)
      AGENT_INPUT_MODE="stdin"
      AGENT_INPUT_ARG="-"
      AGENT_SKIP_GIT_ARG="--skip-git-repo-check"
      AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "codex")"
      return 0
      ;;
    claude)
      AGENT_CMD=(claude --dangerously-skip-permissions)
      AGENT_INPUT_MODE="stdin"
      AGENT_INPUT_ARG=""
      AGENT_SKIP_GIT_ARG=""
      AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "claude")"
      return 0
      ;;
    aider)
      AGENT_CMD=(aider --message-file)
      AGENT_INPUT_MODE="file"
      AGENT_INPUT_ARG=""
      AGENT_SKIP_GIT_ARG=""
      AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "aider")"
      return 0
      ;;
  esac

  return 1
}

ralph_register_exit_trap() {
  trap 'ralph_on_exit "$?"' EXIT
}

ralph_single_story_enabled() {
  case "${RALPH_SINGLE_STORY:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Default agent command; override via RALPH_AGENT or RALPH_AGENT_CMD.
# Use codex exec for non-interactive (headless) runs.
AGENT_CMD=()
AGENT_INPUT_MODE="stdin"
AGENT_INPUT_ARG="-"
AGENT_SKIP_GIT_ARG=""
AGENT_PROMPT_CONTEXT=""
RALPH_AGENT_PRESET="$(ralph_agent_normalize "${RALPH_AGENT:-}")"

if [[ -n "${RALPH_AGENT_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  AGENT_CMD=(${RALPH_AGENT_CMD})
  AGENT_INPUT_MODE="stdin"
  AGENT_INPUT_ARG="-"
  if [[ -n "$RALPH_AGENT_PRESET" ]]; then
    AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "$RALPH_AGENT_PRESET")"
  else
    INFERRED_AGENT="$(ralph_agent_normalize "$(basename "${AGENT_CMD[0]}")")"
    AGENT_PROMPT_CONTEXT="$(ralph_agent_prompt_context "$INFERRED_AGENT")"
    if [[ "$INFERRED_AGENT" == "codex" ]]; then
      AGENT_SKIP_GIT_ARG="--skip-git-repo-check"
    fi
  fi
else
  if [[ -z "$RALPH_AGENT_PRESET" ]]; then
    RALPH_AGENT_PRESET="codex"
  fi

  if [[ "$RALPH_AGENT_PRESET" == "custom" ]]; then
    echo "RALPH_AGENT=custom requires RALPH_AGENT_CMD to be set." >&2
    exit 1
  fi

  if ! ralph_agent_apply_preset "$RALPH_AGENT_PRESET"; then
    echo "Unknown RALPH_AGENT '$RALPH_AGENT'. Use codex|claude|aider|custom or set RALPH_AGENT_CMD." >&2
    exit 1
  fi
fi

REVIEW_CMD=("${AGENT_CMD[@]}")
if [[ -n "${RALPH_REVIEWER_CMD:-}" ]]; then
  # shellcheck disable=SC2206
  REVIEW_CMD=(${RALPH_REVIEWER_CMD})
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ "${RALPH_SKIP_GIT_CHECK:-}" == "1" ]]; then
    if [[ -n "$AGENT_SKIP_GIT_ARG" ]]; then
      AGENT_CMD+=("$AGENT_SKIP_GIT_ARG")
    fi
  else
    echo "Not a git repo. Initialize with: git init" >&2
    if [[ -n "$AGENT_SKIP_GIT_ARG" ]]; then
      echo "Or run with RALPH_SKIP_GIT_CHECK=1 to pass ${AGENT_SKIP_GIT_ARG}." >&2
    else
      echo "Or run with RALPH_SKIP_GIT_CHECK=1 to bypass the Git check." >&2
    fi
    exit 1
  fi
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
AGENTS_FILE=""
if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/AGENTS.md" ]]; then
  AGENTS_FILE="$REPO_ROOT/AGENTS.md"
fi
TEST_ROOT="${REPO_ROOT:-$(pwd)}"

TARGET_STORY="${RALPH_STORY_ID:-${RALPH_TARGET_STORY:-}}"
if [[ -n "$TARGET_STORY" ]] && ! command -v jq >/dev/null 2>&1; then
  echo "Targeted story selection requires jq (RALPH_STORY_ID=$TARGET_STORY)." >&2
  exit 1
fi

if declare -F ralph_cost_control_task_max_iterations >/dev/null 2>&1; then
  TASK_TYPE_MAX="$(ralph_cost_control_task_max_iterations || true)"
  if [[ -n "$TASK_TYPE_MAX" && -z "$MAX_ITERATIONS_ARG" && -z "${MAX_ITERATIONS:-}" ]]; then
    MAX_ITERATIONS_ARG="$TASK_TYPE_MAX"
  fi
fi

if declare -F ralph_git_guard_enable >/dev/null 2>&1; then
  ralph_git_guard_enable
fi

if declare -F ralph_circuit_breaker_init >/dev/null 2>&1; then
  ralph_circuit_breaker_init "$MAX_ITERATIONS_ARG"
  MODEL_NAME="$(detect_model_name)"
  ralph_circuit_breaker_apply_model_limit "$MODEL_NAME"
  MAX_ITERATIONS="$RALPH_CB_MAX_ITERATIONS"
  if [[ "$TESTS_MODE" -eq 1 && -z "${MAX_CONSECUTIVE_FAILURES+x}" ]]; then
    RALPH_CB_MAX_CONSECUTIVE_FAILURES="$MAX_ITERATIONS"
  fi
else
  MAX_ITERATIONS="${MAX_ITERATIONS_ARG:-${MAX_ITERATIONS:-10}}"
fi

if declare -F ralph_cost_control_init >/dev/null 2>&1; then
  ralph_cost_control_init
fi

ralph_register_exit_trap

SINGLE_STORY_MODE=0
if ralph_single_story_enabled; then
  SINGLE_STORY_MODE=1
fi

if declare -F ralph_parallel_enabled >/dev/null 2>&1 && ralph_parallel_enabled; then
  echo "Parallel execution enabled."
  if declare -F ralph_parallel_run >/dev/null 2>&1; then
    if ralph_parallel_run "$PRD_FILE"; then
      exit 0
    else
      exit 1
    fi
  else
    echo "Parallel module not available; disable RALPH_PARALLEL or add modules/parallel.sh." >&2
    exit 1
  fi
fi

START_ITERATION=1
LAST_COMPLETED_STORY_ID=""
LAST_COMPLETED_STORY_TITLE=""
FAILURE_TOTAL=0
FAILURE_CONSECUTIVE=0
LAST_FAILURE_REASON=""
LAST_FAILURE_EXIT=0

if [[ "$RESUME" -eq 1 ]]; then
  if ! declare -F ralph_checkpoint_load >/dev/null 2>&1; then
    echo "Checkpoint module not available; cannot resume." >&2
    exit 1
  fi

  if ! ralph_checkpoint_load; then
    exit 1
  fi

  START_ITERATION=$((RALPH_CHECKPOINT_ITERATION + 1))
  LAST_COMPLETED_STORY_ID="${RALPH_CHECKPOINT_LAST_COMPLETED_ID:-}"
  LAST_COMPLETED_STORY_TITLE="${RALPH_CHECKPOINT_LAST_COMPLETED_TITLE:-}"
  FAILURE_TOTAL="${RALPH_CHECKPOINT_FAILURES_TOTAL:-0}"
  FAILURE_CONSECUTIVE="${RALPH_CHECKPOINT_FAILURES_CONSECUTIVE:-0}"
  LAST_FAILURE_REASON="${RALPH_CHECKPOINT_FAILURES_LAST_REASON:-}"
  LAST_FAILURE_EXIT="${RALPH_CHECKPOINT_FAILURES_LAST_EXIT:-0}"

  if [[ -n "${RALPH_CB_CONSECUTIVE_FAILURES+x}" ]]; then
    RALPH_CB_CONSECUTIVE_FAILURES="$FAILURE_CONSECUTIVE"
  fi
  if [[ -n "${RALPH_CB_LAST_FAILURE_REASON+x}" ]]; then
    RALPH_CB_LAST_FAILURE_REASON="$LAST_FAILURE_REASON"
  fi
  if [[ -n "${RALPH_CB_LAST_EXIT+x}" ]]; then
    RALPH_CB_LAST_EXIT="$LAST_FAILURE_EXIT"
  fi

  if (( START_ITERATION > MAX_ITERATIONS )); then
    echo "Checkpoint iteration ${RALPH_CHECKPOINT_ITERATION} exceeds max iterations (${MAX_ITERATIONS})." >&2
    echo "Increase MAX_ITERATIONS or remove $(ralph_checkpoint_file)." >&2
    exit 1
  fi

  echo "Resuming from checkpoint $(ralph_checkpoint_file) at iteration ${RALPH_CHECKPOINT_ITERATION}."
  if [[ -n "$LAST_COMPLETED_STORY_ID" ]]; then
    echo "Last completed story: ${LAST_COMPLETED_STORY_ID} ${LAST_COMPLETED_STORY_TITLE:+- $LAST_COMPLETED_STORY_TITLE}"
  fi
fi

ralph_print_banner
RALPH_RUN_STARTED=1
RALPH_RUN_START_TS="$(date +%s)"
INITIAL_COMPLETED="$(ralph_count_completed_stories "$PRD_FILE" || true)"
TOTAL_STORIES="$(ralph_count_total_stories "$PRD_FILE" || true)"

# Initialize monitor if enabled
if declare -F ralph_monitor_init >/dev/null 2>&1; then
  ralph_monitor_init
fi

echo -e "${C_BGREEN}╔══════════════════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_BGREEN}║${C_RESET}  ${C_BWHITE}🚀 STARTING RALPH${C_RESET}"
echo -e "${C_BGREEN}╠══════════════════════════════════════════════════════════════════════════╣${C_RESET}"
echo -e "${C_BGREEN}║${C_RESET}  ${C_DIM}Max iterations:${C_RESET}  ${C_BCYAN}$MAX_ITERATIONS${C_RESET}"
echo -e "${C_BGREEN}║${C_RESET}  ${C_DIM}Mode:${C_RESET}            ${C_BCYAN}${RALPH_MODE:-stories}${C_RESET}"
echo -e "${C_BGREEN}║${C_RESET}  ${C_DIM}Agent:${C_RESET}           ${C_BCYAN}${RALPH_AGENT_PRESET:-codex}${C_RESET}"
if [[ -n "$TOTAL_STORIES" ]]; then
  echo -e "${C_BGREEN}║${C_RESET}  ${C_DIM}Stories:${C_RESET}         ${C_BCYAN}${INITIAL_COMPLETED:-0}${C_DIM}/${TOTAL_STORIES} completed${C_RESET}"
fi
echo -e "${C_BGREEN}╚══════════════════════════════════════════════════════════════════════════╝${C_RESET}"
echo ""

ralph_log_verbose "Prompt file: $PROMPT_FILE"
ralph_log_verbose "PRD file: $PRD_FILE"
ralph_log_verbose "Progress file: $PROGRESS_FILE"
if [[ -n "${AGENT_CMD[*]:-}" ]]; then
  ralph_log_verbose "Agent command: ${AGENT_CMD[*]}"
fi

for i in $(seq "$START_ITERATION" "$MAX_ITERATIONS"); do
  ITERATIONS_RUN=$((ITERATIONS_RUN + 1))
  ITERATION_TS="$(date +'%Y-%m-%d %H:%M:%S')"
  ITERATION_START_EPOCH="$(date +%s)"
  ralph_iteration_banner "$i" "$MAX_ITERATIONS" "running" "$ITERATION_TS"
  if declare -F ralph_cost_control_iteration_start >/dev/null 2>&1; then
    ralph_cost_control_iteration_start
  fi
  if declare -F ralph_circuit_breaker_warn_if_needed >/dev/null 2>&1; then
    ralph_circuit_breaker_warn_if_needed "$i"
  fi

  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Missing prompt file: $PROMPT_FILE" >&2
    exit 1
  fi
  if [[ ! -f "$PRD_FILE" ]]; then
    echo "Missing prd file: $PRD_FILE" >&2
    exit 1
  fi
  if [[ ! -f "$PROGRESS_FILE" ]]; then
    echo "Missing progress file: $PROGRESS_FILE" >&2
    exit 1
  fi

  if declare -F ralph_cost_control_phase_advance_if_needed >/dev/null 2>&1; then
    if ! ralph_cost_control_phase_advance_if_needed "$PRD_FILE"; then
      echo "Phase verification failed; stopping." >&2
      exit 1
    fi
  fi

  STORY_CONTEXT=""
  STORY_ID=""
  STORY_TITLE=""
  STORY_PRIORITY=""
  STORY_STATUS=""
  STORY_DEPS=""
  STORY_JSON=""
  STORY_SELECTION=""
  if [[ "$TESTS_MODE" -eq 0 || -n "$TARGET_STORY" ]]; then
    STORY_SELECTION="$(select_story)"
  fi
  if [[ -n "$STORY_SELECTION" ]]; then
    STORY_JSON="$(jq -c '.story' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_ID="$(jq -r '.story.id // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_TITLE="$(jq -r '.story.title // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_PRIORITY="$(jq -r '.priority // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_STATUS="$(jq -r '.status // empty' <<<"$STORY_SELECTION" 2>/dev/null || true)"
    STORY_DEPS="$(jq -c '.dependencies // []' <<<"$STORY_SELECTION" 2>/dev/null || true)"

    if [[ -n "$STORY_JSON" ]]; then
      echo -e "${C_BCYAN}  📋 Story:${C_RESET} ${C_BYELLOW}${STORY_ID:-unknown}${C_RESET} ${C_DIM}-${C_RESET} ${C_BWHITE}${STORY_TITLE:-untitled}${C_RESET}"
      ralph_log_verbose "Story status: ${STORY_STATUS:-n/a} | priority: ${STORY_PRIORITY:-n/a} | deps: ${STORY_DEPS:-[]}"
      STORY_CONTEXT=$(
        cat <<EOF
# Ralph Story Selection
Selected story: ${STORY_ID:-unknown} - ${STORY_TITLE:-untitled}
Priority: ${STORY_PRIORITY:-n/a}
Status: ${STORY_STATUS:-n/a}
Dependencies: ${STORY_DEPS:-[]}

Story JSON:
${STORY_JSON:-}

EOF
      )
    fi
  fi

  if [[ -z "$STORY_ID" ]]; then
    if [[ "$TESTS_MODE" -eq 1 ]]; then
      echo -e "${C_DIM}  📋 Story: skipped (tests mode)${C_RESET}"
    else
      echo -e "${C_BYELLOW}  📋 Story: none selected${C_RESET}"
    fi
  fi

  # Notify monitor of iteration start
  if declare -F ralph_monitor_on_iteration_start >/dev/null 2>&1; then
    ralph_monitor_on_iteration_start "$i" "$MAX_ITERATIONS" "${STORY_ID:-}" "${STORY_TITLE:-}" "$ITERATION_TS"
  fi

  if [[ "$TESTS_MODE" -eq 0 && -n "$TARGET_STORY" ]]; then
    if [[ -z "$STORY_ID" ]]; then
      if story_passed "$TARGET_STORY"; then
        RALPH_RUN_STATUS="success"
        RALPH_STOP_REASON="target_story_completed"
        ralph_log "Target story ${TARGET_STORY} already completed."
        exit 0
      fi
      RALPH_RUN_STATUS="error"
      RALPH_STOP_REASON="target_story_not_selectable"
      ralph_log_error "Target story ${TARGET_STORY} not found or not selectable."
      exit 1
    fi
    if [[ "$STORY_STATUS" == "completed" ]]; then
      RALPH_RUN_STATUS="success"
      RALPH_STOP_REASON="target_story_completed"
      ralph_log "Target story ${STORY_ID} already completed."
      exit 0
    fi
    if [[ "$STORY_STATUS" == "blocked" ]]; then
      RALPH_RUN_STATUS="error"
      RALPH_STOP_REASON="target_story_blocked"
      ralph_log_error "Target story ${STORY_ID} is blocked."
      exit 1
    fi
  fi

  ITERATION_CONTEXT="$(build_iteration_context "$i" "$MAX_ITERATIONS" "$ITERATION_TS")"
  CACHE_CONTEXT=""
  if declare -F ralph_cache_enabled >/dev/null 2>&1 && ralph_cache_enabled; then
    CACHE_CONTEXT="$(ralph_cache_context "$PROGRESS_FILE" "$AGENTS_FILE" || true)"
  fi

  EXTERNAL_CONTEXT=""
  if ralph_external_enabled; then
    EXTERNAL_CONTEXT="$(ralph_external_context)"
  fi

  TEST_CONTEXT=""
  if [[ "$TESTS_MODE" -eq 1 ]]; then
    if ralph_tests_detect_runner "$TEST_ROOT"; then
      ralph_log "Tests: detected ${RALPH_TEST_FRAMEWORK:-unknown} (${RALPH_TEST_CMD})"
      ralph_tests_run "PRE" "$TEST_ROOT" "$RALPH_TEST_CMD" "$RALPH_TEST_FRAMEWORK" "pre"
      TEST_CONTEXT="$(ralph_tests_context "PRE")"
      if [[ "${PRE_TEST_EXIT:-1}" -eq 0 ]]; then
        if declare -F ralph_checkpoint_clear >/dev/null 2>&1; then
          ralph_checkpoint_clear
        fi
        RALPH_RUN_STATUS="success"
        RALPH_STOP_REASON="tests_passing"
        if ralph_external_enabled; then
          ralph_hook_export_env "post" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "success" "tests_passing"
          ralph_hook_run "${RALPH_POST_HOOK:-}" "post" "${REPO_ROOT:-}" || true
        fi
        ralph_log_success "All tests passing! 🎉"
        exit 0
      fi
    else
      TEST_CONTEXT=$(cat <<EOF
# Ralph Test Status
Mode: tests
Framework: unknown
Command: not detected
Status: no test runner detected from project files.
Goal: add or configure a test runner so the suite can be executed.
EOF
)
    fi
  fi

  if ralph_external_enabled; then
    ralph_hook_export_env "pre" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "running" ""
    ralph_hook_run "${RALPH_PRE_HOOK:-}" "pre" "${REPO_ROOT:-}" || true
  fi

  PLAN_PENDING=0
  PLAN_FAILED=0
  PLAN_STATUS=0
  if declare -F ralph_planner_enabled >/dev/null 2>&1 && ralph_planner_enabled; then
    ralph_log "Planning phase enabled."
    PLAN_CONTEXT=""
    if [[ -n "$TEST_CONTEXT" ]]; then
      PLAN_CONTEXT+="${TEST_CONTEXT}"$'\n'
    fi
    if [[ -n "$STORY_CONTEXT" ]]; then
      PLAN_CONTEXT+="${STORY_CONTEXT}"
    fi
    ralph_planner_run "$PROMPT_FILE" "$ITERATION_CONTEXT" "$PLAN_CONTEXT" "${AGENT_CMD[@]}"
    PLAN_STATUS=$?
    if [[ "$PLAN_STATUS" -eq 2 ]]; then
      PLAN_PENDING=1
    elif [[ "$PLAN_STATUS" -ne 0 ]]; then
      PLAN_FAILED=1
    fi
  fi

  if [[ "$PLAN_PENDING" -eq 1 ]]; then
    PLAN_FILE_DISPLAY="${RALPH_PLAN_FILE:-.ralph-plan.md}"
    if declare -F ralph_planner_plan_file >/dev/null 2>&1; then
      PLAN_FILE_DISPLAY="$(ralph_planner_plan_file)"
    fi
    RALPH_RUN_STATUS="paused"
    RALPH_STOP_REASON="plan_approval"
    if ralph_external_enabled; then
      ralph_hook_export_env "post" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "paused" "plan_approval"
      ralph_hook_run "${RALPH_POST_HOOK:-}" "post" "${REPO_ROOT:-}" || true
    fi
    ralph_log "Plan awaiting manual approval. Review ${PLAN_FILE_DISPLAY} and re-run with RALPH_PLAN_APPROVED=1, add Approved: yes (or ${PLAN_FILE_DISPLAY}.approved), or set RALPH_PLAN_APPROVAL=auto."
    exit 0
  fi

  AGENT_RAN=0
  AGENT_EXIT=0
  OUTPUT=""

  if [[ "$PLAN_FAILED" -eq 0 ]]; then
    PROMPT_INPUT="$(mktemp)"
    {
      printf "%s\n\n" "$ITERATION_CONTEXT"
      if [[ -n "$AGENT_PROMPT_CONTEXT" ]]; then
        printf "%s\n\n" "$AGENT_PROMPT_CONTEXT"
      fi
      if [[ -n "$TEST_CONTEXT" ]]; then
        printf "%s\n\n" "$TEST_CONTEXT"
      fi
      if [[ -n "$STORY_CONTEXT" ]]; then
        printf "%s" "$STORY_CONTEXT"
      fi
      if [[ -n "$CACHE_CONTEXT" ]]; then
        printf "%s" "$CACHE_CONTEXT"
      fi
      if [[ -n "$EXTERNAL_CONTEXT" ]]; then
        printf "%s\n\n" "$EXTERNAL_CONTEXT"
      fi
      cat "$PROMPT_FILE"
    } > "$PROMPT_INPUT"

    OUTPUT_FILE="$(mktemp)"
    set +e
    if [[ "$AGENT_INPUT_MODE" == "file" ]]; then
      if [[ "$RALPH_LOG_ACTIVE" -eq 1 ]]; then
        # When logging to file, tee to both file and colorized stdout
        "${AGENT_CMD[@]}" "$PROMPT_INPUT" 2>&1 | tee "$OUTPUT_FILE" | ralph_colorize_output
        PIPE_STATUS=("${PIPESTATUS[@]}")
        AGENT_EXIT="${PIPE_STATUS[0]:-0}"
      else
        # No log file, just colorize and save output
        "${AGENT_CMD[@]}" "$PROMPT_INPUT" 2>&1 | tee "$OUTPUT_FILE" | ralph_colorize_output
        PIPE_STATUS=("${PIPESTATUS[@]}")
        AGENT_EXIT="${PIPE_STATUS[0]:-0}"
      fi
    else
      AGENT_INVOKE=("${AGENT_CMD[@]}")
      if [[ -n "$AGENT_INPUT_ARG" ]]; then
        AGENT_INVOKE+=("$AGENT_INPUT_ARG")
      fi
      if [[ "$RALPH_LOG_ACTIVE" -eq 1 ]]; then
        # When logging to file, tee to both file and colorized stdout
        cat "$PROMPT_INPUT" | "${AGENT_INVOKE[@]}" 2>&1 | tee "$OUTPUT_FILE" | ralph_colorize_output
        PIPE_STATUS=("${PIPESTATUS[@]}")
        AGENT_EXIT="${PIPE_STATUS[1]:-0}"
      else
        # No log file, just colorize and save output
        cat "$PROMPT_INPUT" | "${AGENT_INVOKE[@]}" 2>&1 | tee "$OUTPUT_FILE" | ralph_colorize_output
        PIPE_STATUS=("${PIPESTATUS[@]}")
        AGENT_EXIT="${PIPE_STATUS[1]:-0}"
      fi
    fi
    set -e
    OUTPUT="$(cat "$OUTPUT_FILE")"

    rm -f "$OUTPUT_FILE"
    rm -f "$PROMPT_INPUT"
    AGENT_RAN=1
  else
    AGENT_EXIT="${RALPH_PLAN_EXIT:-1}"
    OUTPUT="${RALPH_PLAN_OUTPUT:-}"
  fi

  QUALITY_FAILED=0
  QUALITY_REASON=""
  QUALITY_STATUS="skipped"
  if [[ "$AGENT_RAN" -eq 1 ]] && declare -F ralph_quality_gates_run >/dev/null 2>&1; then
    if declare -F ralph_quality_gates_enabled >/dev/null 2>&1 && ralph_quality_gates_enabled; then
      if declare -F ralph_quality_gates_strict >/dev/null 2>&1 && ralph_quality_gates_strict; then
        if ralph_quality_gates_run "$PRD_FILE" "${STORY_ID:-}"; then
          QUALITY_STATUS="passed"
        else
          QUALITY_STATUS="failed (strict)"
          QUALITY_FAILED=1
          QUALITY_REASON="Quality gates failed in strict mode."
        fi
      else
        ralph_quality_gates_run "$PRD_FILE" "${STORY_ID:-}" || true
        QUALITY_STATUS="completed (non-blocking)"
      fi
      ralph_log "Quality gates: ${QUALITY_STATUS}"
    else
      ralph_log_verbose "Quality gates: disabled"
    fi
  fi

  REVIEW_FAILED=0
  REVIEW_REASON=""
  if [[ "$AGENT_RAN" -eq 1 ]] \
    && declare -F ralph_reviewer_enabled >/dev/null 2>&1 \
    && ralph_reviewer_enabled \
    && declare -F ralph_reviewer_run >/dev/null 2>&1; then
    if ! ralph_reviewer_run "$ITERATION_CONTEXT" "$STORY_CONTEXT" "$OUTPUT" "${REVIEW_CMD[@]}"; then
      REVIEW_FAILED=1
      REVIEW_REASON="Reviewer command exited with status ${RALPH_REVIEW_EXIT:-unknown}."
      echo "Adversarial review failed (non-blocking): $REVIEW_REASON" >&2
    fi
  fi

  if [[ "$AGENT_RAN" -eq 1 ]] && declare -F ralph_cost_control_record_cost >/dev/null 2>&1; then
    ralph_cost_control_record_cost "$OUTPUT"
    if declare -F ralph_cost_control_enforce_budget >/dev/null 2>&1; then
      if ! ralph_cost_control_enforce_budget; then
        RALPH_RUN_STATUS="stopped"
        RALPH_STOP_REASON="budget_exceeded"
        if ralph_external_enabled; then
          ralph_hook_export_env "post" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "failed" "budget_exceeded"
          ralph_hook_run "${RALPH_POST_HOOK:-}" "post" "${REPO_ROOT:-}" || true
        fi
        exit 1
      fi
    fi
  fi

  TESTS_PASSED=0
  TESTS_EXIT=""
  TESTS_PROGRESS=""
  if [[ "$TESTS_MODE" -eq 1 && "$AGENT_RAN" -eq 1 ]]; then
    if ralph_tests_detect_runner "$TEST_ROOT"; then
      ralph_log "Tests: detected ${RALPH_TEST_FRAMEWORK:-unknown} (${RALPH_TEST_CMD})"
      ralph_tests_run "POST" "$TEST_ROOT" "$RALPH_TEST_CMD" "$RALPH_TEST_FRAMEWORK" "post"
      TESTS_EXIT="${POST_TEST_EXIT:-1}"
      TESTS_PROGRESS="${POST_TEST_PROGRESS:-counts unavailable}"
      ralph_log "Tests: ${TESTS_PROGRESS}"
      if [[ "$TESTS_EXIT" -eq 0 ]]; then
        TESTS_PASSED=1
      fi
    else
      ralph_log_error "Tests: no test runner detected after iteration."
      TESTS_EXIT=1
      TESTS_PROGRESS="counts unavailable"
    fi
  fi

  if [[ "$TESTS_MODE" -eq 1 && "$AGENT_RAN" -eq 1 && "$TESTS_PASSED" -eq 1 ]]; then
    if [[ "$QUALITY_FAILED" -eq 1 ]]; then
      ralph_log_error "Tests passing but quality gates failed in strict mode."
    else
      if declare -F ralph_checkpoint_clear >/dev/null 2>&1; then
        ralph_checkpoint_clear
      fi
      RALPH_RUN_STATUS="success"
      RALPH_STOP_REASON="tests_passing"
      if ralph_external_enabled; then
        ralph_hook_export_env "post" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "success" "tests_passing"
        ralph_hook_run "${RALPH_POST_HOOK:-}" "post" "${REPO_ROOT:-}" || true
      fi
      ralph_log_success "All tests passing! 🎉"
      exit 0
    fi
  fi

  if [[ "$SINGLE_STORY_MODE" -eq 0 && "$TESTS_MODE" -eq 0 ]] && echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    if [[ "$QUALITY_FAILED" -eq 1 ]]; then
      echo "Ignoring COMPLETE because quality gates failed in strict mode." >&2
    else
      HAS_PENDING=1
      if command -v jq >/dev/null 2>&1; then
        if jq -e '.userStories[] | select(.passes == false)' "$PRD_FILE" >/dev/null 2>&1; then
          HAS_PENDING=1
        else
          HAS_PENDING=0
        fi
      fi

      if [[ "$HAS_PENDING" -eq 0 ]]; then
        if declare -F ralph_checkpoint_clear >/dev/null 2>&1; then
          ralph_checkpoint_clear
        fi
        RALPH_RUN_STATUS="success"
        RALPH_STOP_REASON="all_stories_completed"
        if ralph_external_enabled; then
          ralph_hook_export_env "post" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "success" "all_stories_completed"
          ralph_hook_run "${RALPH_POST_HOOK:-}" "post" "${REPO_ROOT:-}" || true
        fi
        ralph_log_success "All stories completed! 🎉"
        exit 0
      else
        echo "Ignoring COMPLETE because pending stories remain in $PRD_FILE" >&2
      fi
    fi
  fi

  ITERATION_FAILED=0
  FAILURE_REASON=""
  if [[ "$QUALITY_FAILED" -eq 1 ]]; then
    ITERATION_FAILED=1
    FAILURE_REASON="$QUALITY_REASON"
  elif [[ "$AGENT_EXIT" -ne 0 ]]; then
    ITERATION_FAILED=1
    FAILURE_REASON="Agent command exited with status $AGENT_EXIT."
  elif [[ "$TESTS_MODE" -eq 1 ]]; then
    if [[ -n "$TESTS_EXIT" && "$TESTS_EXIT" -ne 0 ]]; then
      ITERATION_FAILED=1
      if [[ -n "$TESTS_PROGRESS" ]]; then
        FAILURE_REASON="Tests still failing (${TESTS_PROGRESS})."
      else
        FAILURE_REASON="Tests still failing."
      fi
    elif [[ -z "$TESTS_EXIT" && "$AGENT_RAN" -eq 1 ]]; then
      ITERATION_FAILED=1
      FAILURE_REASON="Tests not executed (no test runner detected)."
    fi
  elif [[ -n "${STORY_ID:-}" ]] && ! story_passed "$STORY_ID"; then
    ITERATION_FAILED=1
    FAILURE_REASON="Story ${STORY_ID} still not marked as passed."
  fi

  if [[ "$ITERATION_FAILED" -eq 1 ]]; then
    FAILURE_TOTAL=$((FAILURE_TOTAL + 1))
    FAILURE_CONSECUTIVE=$((FAILURE_CONSECUTIVE + 1))
    LAST_FAILURE_REASON="$FAILURE_REASON"
    LAST_FAILURE_EXIT="$AGENT_EXIT"
  else
    FAILURE_CONSECUTIVE=0
    if [[ -n "${STORY_ID:-}" ]]; then
      LAST_COMPLETED_STORY_ID="$STORY_ID"
      LAST_COMPLETED_STORY_TITLE="$STORY_TITLE"
    fi
  fi

  ITERATION_END_EPOCH="$(date +%s)"
  ITERATION_STATUS="success"
  if [[ "$ITERATION_FAILED" -eq 1 ]]; then
    ITERATION_STATUS="failed"
  fi
  ralph_iteration_banner "$i" "$MAX_ITERATIONS" "$ITERATION_STATUS"
  if [[ "$ITERATION_FAILED" -eq 1 ]]; then
    ralph_log_error "Iteration result: failed (${FAILURE_REASON})"
  else
    ralph_log_success "Iteration result: success"
  fi
  if ralph_verbose_enabled && ralph_is_int "$ITERATION_START_EPOCH" && ralph_is_int "$ITERATION_END_EPOCH"; then
    ralph_log_verbose "Iteration duration: $(ralph_format_duration $((ITERATION_END_EPOCH - ITERATION_START_EPOCH)) || true)"
  fi

  # Notify monitor of iteration end
  if declare -F ralph_monitor_on_iteration_end >/dev/null 2>&1; then
    ralph_monitor_on_iteration_end "$i" "$MAX_ITERATIONS" "${STORY_ID:-}" "${STORY_TITLE:-}" "$ITERATION_STATUS" "$ITERATION_TS"
  fi

  if ralph_external_enabled; then
    ralph_hook_export_env "post" "$i" "$MAX_ITERATIONS" "$ITERATION_TS" "$ITERATION_STATUS" "$FAILURE_REASON"
    ralph_hook_run "${RALPH_POST_HOOK:-}" "post" "${REPO_ROOT:-}" || true
  fi

  if declare -F ralph_checkpoint_enabled >/dev/null 2>&1 && ralph_checkpoint_enabled; then
    if declare -F ralph_checkpoint_should_write >/dev/null 2>&1; then
      if ralph_checkpoint_should_write "$i"; then
        CHECKPOINT_TS="$(date +'%Y-%m-%d %H:%M:%S')"
        ralph_checkpoint_write \
          "$i" \
          "$MAX_ITERATIONS" \
          "${STORY_ID:-}" \
          "${STORY_TITLE:-}" \
          "$LAST_COMPLETED_STORY_ID" \
          "$LAST_COMPLETED_STORY_TITLE" \
          "$CHECKPOINT_TS" \
          "$FAILURE_TOTAL" \
          "$FAILURE_CONSECUTIVE" \
          "$LAST_FAILURE_REASON" \
          "$LAST_FAILURE_EXIT"
      fi
    fi
  fi

  if declare -F ralph_circuit_breaker_record_result >/dev/null 2>&1; then
    ralph_circuit_breaker_record_result \
      "$ITERATION_FAILED" \
      "${STORY_ID:-}" \
      "${STORY_TITLE:-}" \
      "$AGENT_EXIT" \
      "$FAILURE_REASON"

    if ! ralph_circuit_breaker_should_stop "$i"; then
      if ralph_is_int "${RALPH_CB_STUCK_FAILURES:-0}" \
        && ralph_is_int "${RALPH_CB_STUCK_THRESHOLD:-0}" \
        && (( RALPH_CB_STUCK_FAILURES >= RALPH_CB_STUCK_THRESHOLD )); then
        RALPH_RUN_STATUS="stopped"
        RALPH_STOP_REASON="stuck_story"
      elif ralph_is_int "${RALPH_CB_CONSECUTIVE_FAILURES:-0}" \
        && ralph_is_int "${RALPH_CB_MAX_CONSECUTIVE_FAILURES:-0}" \
        && (( RALPH_CB_CONSECUTIVE_FAILURES >= RALPH_CB_MAX_CONSECUTIVE_FAILURES )); then
        RALPH_RUN_STATUS="stopped"
        RALPH_STOP_REASON="consecutive_failures"
      else
        RALPH_RUN_STATUS="stopped"
        RALPH_STOP_REASON="circuit_breaker"
      fi
      exit 1
    fi
  fi

  if [[ "$SINGLE_STORY_MODE" -eq 1 && -n "${STORY_ID:-}" ]]; then
    if [[ "$ITERATION_FAILED" -eq 0 ]]; then
      if declare -F ralph_checkpoint_clear >/dev/null 2>&1; then
        ralph_checkpoint_clear
      fi
      RALPH_RUN_STATUS="success"
      RALPH_STOP_REASON="single_story_completed"
      ralph_log "Story ${STORY_ID} completed; exiting single-story mode."
      exit 0
    fi
  fi

  if declare -F ralph_cost_control_sleep_between_iterations >/dev/null 2>&1; then
    ralph_cost_control_sleep_between_iterations
  else
    sleep 2
  fi
done

if declare -F ralph_circuit_breaker_report >/dev/null 2>&1; then
  ralph_circuit_breaker_report "max_iterations" "$MAX_ITERATIONS"
fi
RALPH_RUN_STATUS="stopped"
RALPH_STOP_REASON="max_iterations"
ralph_log_warn "Max iterations reached"
exit 1
