# Ralph parallel execution helpers (sourced by ralph.sh).

ralph_parallel_enabled() {
  case "${RALPH_PARALLEL:-}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ralph_parallel_log() {
  echo "[parallel] $*"
}

ralph_parallel_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ralph_parallel_worktree_root() {
  local root
  root="$(ralph_parallel_repo_root)"
  local dir="${RALPH_PARALLEL_ROOT:-$root/.ralph-worktrees}"
  echo "$dir"
}

ralph_parallel_lock_dir() {
  local root
  root="$(ralph_parallel_repo_root)"
  local dir="${RALPH_PARALLEL_LOCK_DIR:-$root/.ralph-parallel-locks}"
  echo "$dir"
}

ralph_parallel_max_workers() {
  local max="${RALPH_PARALLEL_MAX:-${RALPH_PARALLEL_WORKERS:-}}"
  if [[ "$max" =~ ^[0-9]+$ ]] && (( max > 0 )); then
    echo "$max"
  else
    echo "2"
  fi
}

ralph_parallel_slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
}

ralph_parallel_lock_path() {
  local name="$1"
  local lock_dir
  lock_dir="$(ralph_parallel_lock_dir)"
  echo "$lock_dir/${name}.lock"
}

ralph_parallel_acquire_lock() {
  local story_id="$1"
  local lock_dir
  lock_dir="$(ralph_parallel_lock_dir)"
  mkdir -p "$lock_dir"
  local lock_path="$lock_dir/${story_id}.lock"

  if mkdir "$lock_path" 2>/dev/null; then
    printf "%s\n" "$$" > "$lock_path/pid"
    return 0
  fi

  return 1
}

ralph_parallel_release_lock() {
  local story_id="$1"
  local lock_dir
  lock_dir="$(ralph_parallel_lock_dir)"
  local lock_path="$lock_dir/${story_id}.lock"
  rm -rf "$lock_path"
}

ralph_parallel_write_status() {
  local story_id="$1"
  local status="$2"
  local lock_dir
  lock_dir="$(ralph_parallel_lock_dir)"
  local lock_path="$lock_dir/${story_id}.lock"

  if [[ -d "$lock_path" ]]; then
    printf "%s\n" "$status" > "$lock_path/status"
  fi
}

ralph_parallel_acquire_global_lock() {
  local name="$1"
  local lock_path
  lock_path="$(ralph_parallel_lock_path "$name")"
  mkdir -p "$(dirname "$lock_path")"

  local attempts=0
  local max_attempts="${RALPH_PARALLEL_LOCK_WAIT:-30}"
  while (( attempts < max_attempts )); do
    if mkdir "$lock_path" 2>/dev/null; then
      printf "%s\n" "$$" > "$lock_path/pid"
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done

  return 1
}

ralph_parallel_release_global_lock() {
  local name="$1"
  local lock_path
  lock_path="$(ralph_parallel_lock_path "$name")"
  rm -rf "$lock_path"
}

ralph_parallel_has_tracked_changes() {
  local root="$1"
  local dirty
  dirty="$(git -C "$root" status --porcelain | awk '$1 != "??" {print; exit}')"
  [[ -n "$dirty" ]]
}

ralph_parallel_list_ready_stories() {
  local prd_file="$1"

  jq -r '
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
    | sort_by(.priority, .index)
    | .[]
    | [.story.id, (.story.title // ""), (.priority | tostring)] | @tsv
  ' "$prd_file" 2>/dev/null || true
}

ralph_parallel_create_worktree() {
  local root="$1"
  local story_id="$2"

  local slug
  slug="$(ralph_parallel_slugify "$story_id")"
  local timestamp
  timestamp="$(date +%Y%m%d%H%M%S)"
  local branch="ralph-parallel/${slug}-${timestamp}-${RANDOM}"

  local worktree_root
  worktree_root="$(ralph_parallel_worktree_root)"
  mkdir -p "$worktree_root"

  local worktree_dir
  worktree_dir="$(mktemp -d "$worktree_root/${slug}-XXXXXX" 2>/dev/null)" || return 1

  if ! git -C "$root" worktree add -b "$branch" "$worktree_dir" >/dev/null 2>&1; then
    rm -rf "$worktree_dir"
    return 1
  fi

  printf "%s\t%s\n" "$branch" "$worktree_dir"
}

ralph_parallel_remove_worktree() {
  local root="$1"
  local worktree_dir="$2"

  git -C "$root" worktree remove --force "$worktree_dir" >/dev/null 2>&1 || true
}

ralph_parallel_merge_branch() {
  local root="$1"
  local branch="$2"
  local story_id="${3:-}"

  if ! ralph_parallel_acquire_global_lock "merge"; then
    ralph_parallel_log "Merge lock busy; skipping merge for ${story_id:-$branch}."
    return 1
  fi

  if ralph_parallel_has_tracked_changes "$root"; then
    ralph_parallel_log "Tracked changes present in main repo; skipping merge for ${story_id:-$branch}."
    ralph_parallel_release_global_lock "merge"
    return 1
  fi

  local current_branch
  current_branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [[ "$current_branch" != "main" ]]; then
    if ! git -C "$root" checkout main >/dev/null 2>&1; then
      ralph_parallel_log "Failed to checkout main for merge (${story_id:-$branch})."
      ralph_parallel_release_global_lock "merge"
      return 1
    fi
  fi

  if ! git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    ralph_parallel_log "Branch not found for merge: $branch"
    ralph_parallel_release_global_lock "merge"
    return 1
  fi

  if ! git -C "$root" merge --no-ff --no-edit "$branch" >/dev/null 2>&1; then
    ralph_parallel_log "Merge failed for ${story_id:-$branch}."
    ralph_parallel_release_global_lock "merge"
    return 1
  fi

  ralph_parallel_release_global_lock "merge"
  return 0
}

ralph_parallel_run_worker() {
  local root="$1"
  local worktree_dir="$2"
  local branch="$3"
  local story_id="$4"
  local story_title="$5"

  local max_iterations="${RALPH_PARALLEL_ITERATIONS:-${MAX_ITERATIONS:-1}}"
  if [[ ! "$max_iterations" =~ ^[0-9]+$ ]] || (( max_iterations < 1 )); then
    max_iterations=1
  fi

  ralph_parallel_log "Starting ${story_id:-unknown} (${story_title:-untitled}) in $worktree_dir"
  ralph_parallel_write_status "$story_id" "running"

  (
    cd "$worktree_dir" || exit 1
    export RALPH_PARALLEL=0
    export RALPH_SINGLE_STORY=1
    export RALPH_STORY_ID="$story_id"
    ./scripts/ralph/ralph.sh "$max_iterations"
  )
  local exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    ralph_parallel_write_status "$story_id" "completed"
    if ! ralph_parallel_merge_branch "$root" "$branch" "$story_id"; then
      ralph_parallel_write_status "$story_id" "merge_failed"
      exit_code=1
    fi
  else
    ralph_parallel_write_status "$story_id" "failed"
  fi

  if [[ "${RALPH_PARALLEL_KEEP_WORKTREES:-}" != "1" ]]; then
    ralph_parallel_remove_worktree "$root" "$worktree_dir"
  fi

  ralph_parallel_release_lock "$story_id"
  return "$exit_code"
}

ralph_parallel_run() {
  local prd_file="$1"

  if ! command -v jq >/dev/null 2>&1; then
    ralph_parallel_log "jq is required for parallel selection; install jq or disable RALPH_PARALLEL."
    return 1
  fi

  local root
  root="$(ralph_parallel_repo_root)"
  if ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    ralph_parallel_log "Not a git repo; parallel mode requires git."
    return 1
  fi

  if ! git -C "$root" worktree list >/dev/null 2>&1; then
    ralph_parallel_log "git worktree not available; parallel mode requires git worktree support."
    return 1
  fi

  local max_workers
  max_workers="$(ralph_parallel_max_workers)"

  local story_lines
  story_lines="$(ralph_parallel_list_ready_stories "$prd_file" | head -n "$max_workers")"
  if [[ -z "$story_lines" ]]; then
    ralph_parallel_log "No eligible stories to run in parallel."
    return 0
  fi

  ralph_parallel_log "Launching up to $max_workers parallel worktrees."

  local pids=()
  local ids=()
  while IFS=$'\t' read -r story_id story_title story_priority; do
    [[ -z "$story_id" ]] && continue

    if ! ralph_parallel_acquire_lock "$story_id"; then
      ralph_parallel_log "Story $story_id already locked; skipping."
      continue
    fi

    ralph_parallel_write_status "$story_id" "queued"

    local worktree_info
    worktree_info="$(ralph_parallel_create_worktree "$root" "$story_id")"
    if [[ -z "$worktree_info" ]]; then
      ralph_parallel_log "Failed to create worktree for $story_id."
      ralph_parallel_write_status "$story_id" "worktree_failed"
      ralph_parallel_release_lock "$story_id"
      continue
    fi

    local branch
    local worktree_dir
    IFS=$'\t' read -r branch worktree_dir <<<"$worktree_info"

    (ralph_parallel_run_worker "$root" "$worktree_dir" "$branch" "$story_id" "$story_title") &
    pids+=("$!")
    ids+=("$story_id")
  done <<<"$story_lines"

  if [[ "${#pids[@]}" -eq 0 ]]; then
    ralph_parallel_log "No parallel worktrees started."
    return 0
  fi

  local failed=0
  for idx in "${!pids[@]}"; do
    if ! wait "${pids[$idx]}"; then
      ralph_parallel_log "Story ${ids[$idx]} failed."
      failed=1
    fi
  done

  return "$failed"
}
