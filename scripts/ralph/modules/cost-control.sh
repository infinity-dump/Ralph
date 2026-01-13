# Ralph cost control helpers (sourced by ralph.sh).

ralph_cost_control_log() {
  echo "[cost] $*" >&2
}

ralph_cost_control_is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

ralph_cost_control_is_number() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

ralph_cost_control_task_type() {
  local raw="${RALPH_TASK_TYPE:-${RALPH_TASK_COMPLEXITY:-${RALPH_TASK_SIZE:-}}}"
  if [[ -z "$raw" ]]; then
    return 1
  fi

  raw="$(echo "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    quick|small|tiny|fast)
      echo "quick"
      ;;
    standard|normal|medium)
      echo "standard"
      ;;
    complex|large|big|slow)
      echo "complex"
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_cost_control_task_max_iterations() {
  local task_type
  task_type="$(ralph_cost_control_task_type || true)"
  case "$task_type" in
    quick)
      echo "5"
      ;;
    standard)
      echo "10"
      ;;
    complex)
      echo "25"
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_cost_control_rate_limit_seconds() {
  local rate="${RALPH_RATE_LIMIT:-}"
  if ! ralph_cost_control_is_int "$rate"; then
    return 1
  fi
  if (( rate <= 0 )); then
    return 1
  fi

  local seconds=$(( (60 + rate - 1) / rate ))
  if (( seconds < 1 )); then
    seconds=1
  fi
  echo "$seconds"
}

ralph_cost_control_parse_dollars_to_cents() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    return 1
  fi

  raw="${raw//,/}"
  raw="${raw//$/}"
  if ! ralph_cost_control_is_number "$raw"; then
    return 1
  fi

  awk -v val="$raw" 'BEGIN { printf "%d", (val * 100 + 0.5) }'
}

ralph_cost_control_format_cents() {
  local cents="${1:-}"
  if ! ralph_cost_control_is_int "$cents"; then
    return 1
  fi

  local dollars=$((cents / 100))
  local remainder=$((cents % 100))
  printf '$%d.%02d' "$dollars" "$remainder"
}

ralph_cost_control_extract_cost_from_output() {
  local output="$1"
  # Use grep + sed for POSIX compatibility (BSD awk lacks capture groups)
  echo "$output" | tr '[:upper:]' '[:lower:]' | \
    grep -oE '(cost|spent|spend|usage)[^0-9$]*\$?[0-9]+(\.[0-9]+)?' | \
    head -n 1 | \
    grep -oE '[0-9]+(\.[0-9]+)?$' || true
}

ralph_cost_control_record_cost() {
  local output="$1"
  local cost_value=""

  if [[ -n "${RALPH_COST_PER_ITERATION:-}" ]]; then
    cost_value="${RALPH_COST_PER_ITERATION}"
  elif [[ -n "${RALPH_COST_TRACKER_CMD:-}" ]]; then
    cost_value="$(eval "${RALPH_COST_TRACKER_CMD}" 2>/dev/null | head -n 1 || true)"
  else
    cost_value="$(ralph_cost_control_extract_cost_from_output "$output")"
  fi

  cost_value="$(echo "$cost_value" | tr -d '[:space:]')"
  if [[ -z "$cost_value" ]]; then
    if [[ -n "${RALPH_MAX_COST:-}" && -z "${RALPH_COST_MISSING_NOTICE:-}" ]]; then
      ralph_cost_control_log "No cost data captured; budget enforcement may be inaccurate."
      RALPH_COST_MISSING_NOTICE=1
    fi
    return 0
  fi

  local cents
  if ! cents="$(ralph_cost_control_parse_dollars_to_cents "$cost_value")"; then
    if [[ -n "${RALPH_MAX_COST:-}" && -z "${RALPH_COST_MISSING_NOTICE:-}" ]]; then
      ralph_cost_control_log "Unable to parse cost value (${cost_value}); budget enforcement may be inaccurate."
      RALPH_COST_MISSING_NOTICE=1
    fi
    return 0
  fi

  local total="${RALPH_COST_TOTAL_CENTS:-0}"
  local entries="${RALPH_COST_ENTRIES:-0}"
  if ! ralph_cost_control_is_int "$total"; then
    total=0
  fi
  if ! ralph_cost_control_is_int "$entries"; then
    entries=0
  fi

  total=$((total + cents))
  entries=$((entries + 1))

  RALPH_COST_TOTAL_CENTS="$total"
  RALPH_COST_ENTRIES="$entries"
  RALPH_COST_LAST_CENTS="$cents"

  if [[ "${RALPH_VERBOSE:-}" == "1" ]]; then
    ralph_cost_control_log "Recorded ${cost_value} (total $(ralph_cost_control_format_cents "$total"))."
  fi
}

ralph_cost_control_budget_reached() {
  local max="${RALPH_COST_MAX_CENTS:-}"
  local total="${RALPH_COST_TOTAL_CENTS:-0}"

  if ! ralph_cost_control_is_int "$max"; then
    return 1
  fi
  if ! ralph_cost_control_is_int "$total"; then
    return 1
  fi

  if (( total >= max )); then
    return 0
  fi

  return 1
}

ralph_cost_control_enforce_budget() {
  if ! ralph_cost_control_budget_reached; then
    return 0
  fi

  local max="${RALPH_COST_MAX_CENTS:-}"
  local total="${RALPH_COST_TOTAL_CENTS:-0}"

  local max_fmt=""
  local total_fmt=""
  max_fmt="$(ralph_cost_control_format_cents "$max" || true)"
  total_fmt="$(ralph_cost_control_format_cents "$total" || true)"

  ralph_cost_control_log "Budget limit reached (${total_fmt:-$total} >= ${max_fmt:-$max})."
  RALPH_COST_LIMIT_HIT=1
  return 1
}

ralph_cost_control_iteration_start() {
  local count="${RALPH_COST_ITERATION_COUNT:-0}"
  if ! ralph_cost_control_is_int "$count"; then
    count=0
  fi
  count=$((count + 1))
  RALPH_COST_ITERATION_COUNT="$count"
  RALPH_COST_ITERATION_START_TS="$(date +%s)"
}

ralph_cost_control_sleep_between_iterations() {
  local default_sleep="${RALPH_DEFAULT_SLEEP:-2}"
  local rate_seconds="${RALPH_RATE_LIMIT_SECONDS:-}"

  if ! ralph_cost_control_is_int "$rate_seconds" || (( rate_seconds <= 0 )); then
    sleep "$default_sleep"
    return 0
  fi

  local start_ts="${RALPH_COST_ITERATION_START_TS:-}"
  if ! ralph_cost_control_is_int "$start_ts"; then
    sleep "$rate_seconds"
    return 0
  fi

  local now
  now="$(date +%s)"
  local elapsed=$((now - start_ts))
  if (( elapsed < rate_seconds )); then
    local wait=$((rate_seconds - elapsed))
    ralph_cost_control_log "Rate limiting: sleeping ${wait}s to honor ${RALPH_RATE_LIMIT}/min."
    sleep "$wait"
  fi
}

ralph_cost_control_phase_enabled() {
  case "${RALPH_PHASE_CHAINING:-${RALPH_PHASE_CHAIN:-}}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
  esac

  if [[ -n "${RALPH_PHASES:-}" ]]; then
    return 0
  fi

  return 1
}

ralph_cost_control_phase_list() {
  local phases="${RALPH_PHASES:-data,api,ui}"
  phases="$(echo "$phases" | tr ',' ' ' | tr -s ' ' | sed 's/^ *//; s/ *$//')"
  if [[ -z "$phases" ]]; then
    echo "data api ui"
  else
    echo "$phases"
  fi
}

ralph_cost_control_phase_index_for() {
  local target="$1"
  shift
  local phases=("$@")
  local idx=0
  local phase
  for phase in "${phases[@]}"; do
    if [[ "$phase" == "$target" ]]; then
      echo "$idx"
      return 0
    fi
    idx=$((idx + 1))
  done
  echo "0"
}

ralph_cost_control_phase_init() {
  if [[ -n "${RALPH_PHASES_LIST:-}" ]]; then
    return 0
  fi

  local phases
  phases="$(ralph_cost_control_phase_list)"
  RALPH_PHASES_LIST="$phases"

  local phases_array
  read -r -a phases_array <<<"$phases"

  local current="${RALPH_PHASE_CURRENT:-${phases_array[0]}}"
  RALPH_PHASE_CURRENT="$current"
  RALPH_PHASE_INDEX="$(ralph_cost_control_phase_index_for "$current" "${phases_array[@]}")"

  if [[ -z "${RALPH_PHASE_INCLUDE_UNSPECIFIED:-}" ]]; then
    RALPH_PHASE_INCLUDE_UNSPECIFIED=1
  fi
}

ralph_cost_control_phase_has_any() {
  local prd_file="$1"
  local phase="$2"

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  jq -e --arg phase "$phase" '
    def phase_list:
      if (.phase | type) == "string" then [ .phase ]
      elif (.phases | type) == "array" then .phases
      elif (.tags | type) == "array" then .tags
      else [] end;

    (.userStories // [])
    | map(select((phase_list | index($phase)) != null))
    | length > 0
  ' "$prd_file" >/dev/null 2>&1
}

ralph_cost_control_phase_has_remaining() {
  local prd_file="$1"
  local phase="$2"
  local include_unspecified="${3:-1}"

  if ! command -v jq >/dev/null 2>&1; then
    return 1
  fi

  jq -e --arg phase "$phase" --argjson include "$include_unspecified" '
    def normalized_status:
      if .passes == true then "completed"
      elif .status then .status
      else "pending"
      end;
    def phase_list:
      if (.phase | type) == "string" then [ .phase ]
      elif (.phases | type) == "array" then .phases
      elif (.tags | type) == "array" then .tags
      else [] end;
    def in_phase:
      (phase_list | index($phase)) != null
      or ($include == 1 and (phase_list | length == 0));

    (.userStories // [])
    | map(select((. | normalized_status) != "completed"))
    | map(select(in_phase))
    | length > 0
  ' "$prd_file" >/dev/null 2>&1
}

ralph_cost_control_phase_verify() {
  local phase="$1"
  local prd_file="$2"

  if [[ -n "${RALPH_PHASE_VERIFY_CMD:-}" ]]; then
    ralph_cost_control_log "Verifying phase ${phase} via RALPH_PHASE_VERIFY_CMD."
    eval "${RALPH_PHASE_VERIFY_CMD}"
    return $?
  fi

  if declare -F ralph_quality_gates_run >/dev/null 2>&1 \
    && declare -F ralph_quality_gates_enabled >/dev/null 2>&1 \
    && ralph_quality_gates_enabled; then
    ralph_cost_control_log "Verifying phase ${phase} via quality gates."
    ralph_quality_gates_run "$prd_file" ""
    return $?
  fi

  ralph_cost_control_log "Phase ${phase} verification skipped (no verifier configured)."
  return 0
}

ralph_cost_control_phase_advance_if_needed() {
  local prd_file="$1"

  if ! ralph_cost_control_phase_enabled; then
    RALPH_PHASE_CHAINING_ACTIVE=0
    return 0
  fi

  if [[ ! -f "$prd_file" ]]; then
    ralph_cost_control_log "PRD file not found; skipping phase chaining."
    RALPH_PHASE_CHAINING_ACTIVE=0
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    ralph_cost_control_log "Phase chaining requires jq; skipping."
    RALPH_PHASE_CHAINING_ACTIVE=0
    return 0
  fi

  ralph_cost_control_phase_init
  RALPH_PHASE_CHAINING_ACTIVE=1

  local include_unspecified="${RALPH_PHASE_INCLUDE_UNSPECIFIED:-1}"
  if ! ralph_cost_control_is_int "$include_unspecified"; then
    include_unspecified=1
  fi

  local phases_array
  read -r -a phases_array <<<"${RALPH_PHASES_LIST}"
  if (( ${#phases_array[@]} == 0 )); then
    phases_array=("data" "api" "ui")
  fi

  local idx="${RALPH_PHASE_INDEX:-0}"
  if ! ralph_cost_control_is_int "$idx"; then
    idx=0
  fi

  while (( idx < ${#phases_array[@]} )); do
    local current="${phases_array[$idx]}"
    RALPH_PHASE_CURRENT="$current"
    RALPH_PHASE_INDEX="$idx"

    if ralph_cost_control_phase_has_remaining "$prd_file" "$current" "$include_unspecified"; then
      return 0
    fi

    if ralph_cost_control_phase_has_any "$prd_file" "$current"; then
      if ! ralph_cost_control_phase_verify "$current" "$prd_file"; then
        return 1
      fi
    fi

    idx=$((idx + 1))
  done

  RALPH_PHASE_CHAINING_COMPLETE=1
  return 0
}

ralph_cost_control_report() {
  local entries="${RALPH_COST_ENTRIES:-0}"
  local iterations="${RALPH_COST_ITERATION_COUNT:-0}"
  local total="${RALPH_COST_TOTAL_CENTS:-0}"
  local max="${RALPH_COST_MAX_CENTS:-}"

  echo "=== Ralph Cost Summary ==="

  if ralph_cost_control_is_int "$entries" && (( entries > 0 )); then
    local total_fmt
    total_fmt="$(ralph_cost_control_format_cents "$total" || true)"
    echo "Cost estimate: ${total_fmt:-$total} (tracked iterations: ${entries}/${iterations})"
  else
    if ralph_cost_control_is_int "$iterations" && (( iterations > 0 )); then
      echo "Cost estimate: unavailable (no cost data captured; iterations: ${iterations})"
    else
      echo "Cost estimate: unavailable (no cost data captured)"
    fi
  fi

  if ralph_cost_control_is_int "$max" && (( max > 0 )); then
    local max_fmt
    max_fmt="$(ralph_cost_control_format_cents "$max" || true)"
    echo "Budget limit: ${max_fmt:-$max}"
    if ralph_cost_control_is_int "$entries" && (( entries > 0 )); then
      if (( total >= max )); then
        echo "Budget status: exceeded"
      else
        echo "Budget status: within limit"
      fi
    else
      echo "Budget status: unknown (no cost data captured)"
    fi
  fi
}

ralph_cost_control_init() {
  RALPH_COST_TOTAL_CENTS=0
  RALPH_COST_ENTRIES=0
  RALPH_COST_ITERATION_COUNT=0
  RALPH_COST_LAST_CENTS=0
  RALPH_COST_LIMIT_HIT=0

  local max_cents=""
  if [[ -n "${RALPH_MAX_COST:-}" ]]; then
    max_cents="$(ralph_cost_control_parse_dollars_to_cents "$RALPH_MAX_COST" || true)"
    if [[ -z "$max_cents" ]]; then
      ralph_cost_control_log "Invalid RALPH_MAX_COST value (${RALPH_MAX_COST}); budget enforcement disabled."
    fi
  fi
  RALPH_COST_MAX_CENTS="$max_cents"

  local rate_seconds=""
  rate_seconds="$(ralph_cost_control_rate_limit_seconds || true)"
  RALPH_RATE_LIMIT_SECONDS="$rate_seconds"

  if ralph_cost_control_phase_enabled; then
    ralph_cost_control_phase_init
  fi
}
