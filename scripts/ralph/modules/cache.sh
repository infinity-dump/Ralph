# Ralph cache helpers (sourced by ralph.sh).

ralph_cache_enabled() {
  case "${RALPH_CACHE:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_cache_log() {
  echo "[cache] $*" >&2
}

ralph_cache_dir() {
  echo "${RALPH_CACHE_DIR:-.ralph-cache}"
}

ralph_cache_ttl_seconds() {
  local ttl="${RALPH_CACHE_TTL:-86400}"
  if [[ "$ttl" =~ ^[0-9]+$ ]]; then
    echo "$ttl"
  else
    echo "86400"
  fi
}

ralph_cache_manifest_file() {
  local dir
  dir="$(ralph_cache_dir)"
  echo "$dir/manifest.json"
}

ralph_cache_category_file() {
  local category="$1"
  local dir
  dir="$(ralph_cache_dir)"
  echo "$dir/${category}.md"
}

ralph_cache_stat_mtime() {
  local file="$1"
  if stat -f %m "$file" >/dev/null 2>&1; then
    stat -f %m "$file"
  elif stat -c %Y "$file" >/dev/null 2>&1; then
    stat -c %Y "$file"
  else
    echo "0"
  fi
}

ralph_cache_should_refresh() {
  local dir
  dir="$(ralph_cache_dir)"

  if [[ "${RALPH_CACHE_CLEAR:-}" == "1" ]]; then
    return 0
  fi

  local manifest
  manifest="$(ralph_cache_manifest_file)"

  if [[ ! -d "$dir" ]]; then
    return 0
  fi
  if [[ ! -f "$manifest" ]]; then
    return 0
  fi

  local category
  for category in patterns rules common-errors; do
    if [[ ! -f "$(ralph_cache_category_file "$category")" ]]; then
      return 0
    fi
  done

  local ttl
  ttl="$(ralph_cache_ttl_seconds)"
  if (( ttl <= 0 )); then
    return 1
  fi

  local mtime
  local now
  mtime="$(ralph_cache_stat_mtime "$manifest")"
  now="$(date +%s)"

  if [[ "$mtime" =~ ^[0-9]+$ ]] && (( now - mtime >= ttl )); then
    return 0
  fi

  return 1
}

ralph_cache_clear() {
  local dir
  dir="$(ralph_cache_dir)"
  rm -rf "$dir"
}

ralph_cache_extract_section() {
  local file="$1"
  local header="$2"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  awk -v header="$header" '
    BEGIN {found=0}
    $0 ~ "^##[[:space:]]+" header "$" {found=1; next}
    found && /^##[[:space:]]+/ {exit}
    found {print}
  ' "$file"
}

ralph_cache_extract_gotchas() {
  local progress_file="$1"
  local limit="${RALPH_CACHE_GOTCHAS_LIMIT:-20}"

  if [[ ! -f "$progress_file" ]]; then
    return 0
  fi

  local gotchas
  gotchas="$(awk '
    BEGIN {inGotchas=0}
    /\*\*Gotchas:\*\*/ {inGotchas=1; next}
    inGotchas && /^##[[:space:]]+/ {inGotchas=0}
    inGotchas && /^---/ {inGotchas=0}
    inGotchas {
      if ($0 ~ /^[[:space:]]*-[[:space:]]+/) {
        sub(/^[[:space:]]*-[[:space:]]+/, "- ")
        print
      }
    }
  ' "$progress_file")"

  if [[ -n "$limit" && "$limit" =~ ^[0-9]+$ ]] && (( limit > 0 )); then
    printf "%s\n" "$gotchas" | tail -n "$limit"
  else
    printf "%s\n" "$gotchas"
  fi
}

ralph_cache_collect_patterns() {
  local progress_file="$1"
  local override="${RALPH_CACHE_PATTERNS_FILE:-}"

  if [[ -n "$override" && -f "$override" ]]; then
    cat "$override"
    return 0
  fi

  ralph_cache_extract_section "$progress_file" "Codebase Patterns"
}

ralph_cache_collect_rules() {
  local agents_file="$1"
  local override="${RALPH_CACHE_RULES_FILE:-}"

  if [[ -n "$override" && -f "$override" ]]; then
    cat "$override"
    return 0
  fi

  ralph_cache_extract_section "$agents_file" "Learnings"
}

ralph_cache_collect_errors() {
  local progress_file="$1"
  local override="${RALPH_CACHE_ERRORS_FILE:-}"

  if [[ -n "$override" && -f "$override" ]]; then
    cat "$override"
    return 0
  fi

  ralph_cache_extract_gotchas "$progress_file"
}

ralph_cache_write_manifest() {
  local manifest
  manifest="$(ralph_cache_manifest_file)"

  local ttl
  local now
  local timestamp
  ttl="$(ralph_cache_ttl_seconds)"
  now="$(date +%s)"
  timestamp="$(date +'%Y-%m-%d %H:%M:%S')"

  cat > "$manifest" <<CACHE_MANIFEST
{
  "createdAt": "${timestamp}",
  "createdAtEpoch": ${now},
  "ttlSeconds": ${ttl}
}
CACHE_MANIFEST
}

ralph_cache_write_file() {
  local path="$1"
  local content="$2"
  local dir
  dir="$(dirname "$path")"
  if [[ -n "$dir" && "$dir" != "." ]]; then
    mkdir -p "$dir"
  fi

  printf "%s\n" "$content" > "$path"
}

ralph_cache_build() {
  local progress_file="$1"
  local agents_file="$2"
  local dir
  dir="$(ralph_cache_dir)"

  if [[ "${RALPH_CACHE_CLEAR:-}" == "1" ]]; then
    ralph_cache_clear
  fi

  mkdir -p "$dir"

  local patterns
  local rules
  local errors

  patterns="$(ralph_cache_collect_patterns "$progress_file")"
  rules="$(ralph_cache_collect_rules "$agents_file")"
  errors="$(ralph_cache_collect_errors "$progress_file")"

  ralph_cache_write_file "$(ralph_cache_category_file "patterns")" "$patterns"
  ralph_cache_write_file "$(ralph_cache_category_file "rules")" "$rules"
  ralph_cache_write_file "$(ralph_cache_category_file "common-errors")" "$errors"
  ralph_cache_write_manifest
}

ralph_cache_load_manifest_field() {
  local field="$1"
  local manifest
  manifest="$(ralph_cache_manifest_file)"

  if [[ ! -f "$manifest" ]]; then
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r --arg field "$field" '.[$field] // empty' "$manifest" 2>/dev/null
    return 0
  fi

  sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\?\([^\",}]*\)\"\?.*/\1/p" "$manifest" | head -n 1
}

ralph_cache_context() {
  local progress_file="$1"
  local agents_file="$2"

  if ! ralph_cache_enabled; then
    return 1
  fi

  if ralph_cache_should_refresh; then
    ralph_cache_log "refreshing cache"
    ralph_cache_build "$progress_file" "$agents_file"
  else
    ralph_cache_log "using cached context"
  fi

  local patterns
  local rules
  local errors
  local updated

  patterns="$(cat "$(ralph_cache_category_file "patterns")" 2>/dev/null || true)"
  rules="$(cat "$(ralph_cache_category_file "rules")" 2>/dev/null || true)"
  errors="$(cat "$(ralph_cache_category_file "common-errors")" 2>/dev/null || true)"
  updated="$(ralph_cache_load_manifest_field "createdAt")"

  if [[ -z "$patterns" && -z "$rules" && -z "$errors" ]]; then
    return 0
  fi

  printf "%s\n" "# Ralph Cached Context"
  if [[ -n "$updated" ]]; then
    printf "Cache Updated: %s\n\n" "$updated"
  else
    printf "\n"
  fi

  if [[ -n "$patterns" ]]; then
    printf "%s\n" "## Patterns"
    printf "%s\n\n" "$patterns"
  fi

  if [[ -n "$rules" ]]; then
    printf "%s\n" "## Rules"
    printf "%s\n\n" "$rules"
  fi

  if [[ -n "$errors" ]]; then
    printf "%s\n" "## Common Errors"
    printf "%s\n\n" "$errors"
  fi
}
