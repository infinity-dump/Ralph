# Ralph PRD generator - AI-powered user story generation (sourced by ralph.sh).

ralph_prd_generator_log() {
  if declare -F ralph_log_info >/dev/null 2>&1; then
    ralph_log_info "[prd-gen] $*"
  else
    echo "[prd-generator] $*"
  fi
}

ralph_prd_generator_log_step() {
  if declare -F ralph_log_step >/dev/null 2>&1; then
    ralph_log_step "[prd-gen] $*"
  else
    echo "  > $*"
  fi
}

ralph_prd_generator_log_success() {
  if declare -F ralph_log_success >/dev/null 2>&1; then
    ralph_log_success "[prd-gen] $*"
  else
    echo "✓ $*"
  fi
}

ralph_prd_generator_log_error() {
  if declare -F ralph_log_error >/dev/null 2>&1; then
    ralph_log_error "[prd-gen] $*"
  else
    echo "✗ $*" >&2
  fi
}

ralph_prd_generator_trim() {
  local text="$1"
  text="$(echo "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  echo "$text"
}

ralph_prd_generator_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ralph_prd_generator_resolve_agent_cmd() {
  # Use same agent preset system as main ralph.sh
  local preset="${RALPH_AGENT:-${RALPH_PRD_AGENT:-codex}}"

  if [[ -n "${RALPH_PRD_AGENT_CMD:-}" ]]; then
    echo "${RALPH_PRD_AGENT_CMD}"
    return 0
  fi

  if [[ -n "${RALPH_AGENT_CMD:-}" ]]; then
    echo "${RALPH_AGENT_CMD}"
    return 0
  fi

  case "$preset" in
    codex)
      echo "codex exec --dangerously-bypass-approvals-and-sandbox"
      ;;
    claude)
      echo "claude --dangerously-skip-permissions"
      ;;
    aider)
      echo "aider --yes --message"
      ;;
    *)
      echo "codex exec --dangerously-bypass-approvals-and-sandbox"
      ;;
  esac
}

ralph_prd_generator_get_agent_input_mode() {
  local preset="${RALPH_AGENT:-${RALPH_PRD_AGENT:-codex}}"
  case "$preset" in
    aider)
      echo "arg"
      ;;
    *)
      echo "stdin"
      ;;
  esac
}

ralph_prd_generator_analyze_repo() {
  local root="$1"
  local analysis=""

  ralph_prd_generator_log_step "Analyzing repository structure..."

  # Get basic repo info
  local repo_name
  repo_name="$(basename "$root")"
  analysis+="Repository: $repo_name\n"

  # Detect project type and tech stack
  local tech_stack=""
  if [[ -f "$root/package.json" ]]; then
    tech_stack+="Node.js/JavaScript"
    if [[ -f "$root/tsconfig.json" ]]; then
      tech_stack+=" (TypeScript)"
    fi
    if grep -q "react" "$root/package.json" 2>/dev/null; then
      tech_stack+=", React"
    fi
    if grep -q "next" "$root/package.json" 2>/dev/null; then
      tech_stack+=", Next.js"
    fi
    if grep -q "vue" "$root/package.json" 2>/dev/null; then
      tech_stack+=", Vue"
    fi
  fi
  if [[ -f "$root/pyproject.toml" ]] || [[ -f "$root/requirements.txt" ]]; then
    [[ -n "$tech_stack" ]] && tech_stack+=", "
    tech_stack+="Python"
    if grep -q "django" "$root/requirements.txt" 2>/dev/null || grep -q "django" "$root/pyproject.toml" 2>/dev/null; then
      tech_stack+=", Django"
    fi
    if grep -q "fastapi" "$root/requirements.txt" 2>/dev/null || grep -q "fastapi" "$root/pyproject.toml" 2>/dev/null; then
      tech_stack+=", FastAPI"
    fi
  fi
  if [[ -f "$root/go.mod" ]]; then
    [[ -n "$tech_stack" ]] && tech_stack+=", "
    tech_stack+="Go"
  fi
  if [[ -f "$root/Cargo.toml" ]]; then
    [[ -n "$tech_stack" ]] && tech_stack+=", "
    tech_stack+="Rust"
  fi
  if [[ -f "$root/Gemfile" ]]; then
    [[ -n "$tech_stack" ]] && tech_stack+=", "
    tech_stack+="Ruby"
    if grep -q "rails" "$root/Gemfile" 2>/dev/null; then
      tech_stack+=", Rails"
    fi
  fi
  if ls "$root"/*.xcodeproj "$root"/*.xcworkspace 2>/dev/null | head -1 >/dev/null; then
    [[ -n "$tech_stack" ]] && tech_stack+=", "
    tech_stack+="iOS/Swift"
  fi
  if [[ -f "$root/build.gradle" ]] || [[ -f "$root/pom.xml" ]]; then
    [[ -n "$tech_stack" ]] && tech_stack+=", "
    tech_stack+="Java"
    if [[ -f "$root/build.gradle.kts" ]]; then
      tech_stack+="/Kotlin"
    fi
  fi

  [[ -z "$tech_stack" ]] && tech_stack="Unknown"
  analysis+="Tech Stack: $tech_stack\n\n"

  # Get directory structure (top 2 levels)
  analysis+="Directory Structure:\n"
  analysis+="$(find "$root" -maxdepth 2 -type d \
    -not -path '*/.git*' \
    -not -path '*/node_modules*' \
    -not -path '*/.venv*' \
    -not -path '*/venv*' \
    -not -path '*/__pycache__*' \
    -not -path '*/dist*' \
    -not -path '*/build*' \
    -not -path '*/.next*' \
    -not -path '*/target*' \
    2>/dev/null | head -50 | sed "s|$root|.|g")\n\n"

  # Get key source files
  analysis+="Key Source Files:\n"
  local src_files
  src_files="$(find "$root" -type f \( \
    -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
    -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.swift" \
    -o -name "*.java" -o -name "*.kt" -o -name "*.rb" \
  \) \
    -not -path '*/.git*' \
    -not -path '*/node_modules*' \
    -not -path '*/.venv*' \
    -not -path '*/dist*' \
    -not -path '*/build*' \
    2>/dev/null | head -30 | sed "s|$root|.|g")"
  analysis+="$src_files\n\n"

  # Check for existing PRD
  if [[ -f "$root/scripts/ralph/prd.json" ]]; then
    analysis+="Existing PRD found at scripts/ralph/prd.json\n"
    if command -v jq >/dev/null 2>&1; then
      local existing_stories
      existing_stories="$(jq -r '.userStories[]? | "- \(.id): \(.title) [passes=\(.passes)]"' "$root/scripts/ralph/prd.json" 2>/dev/null || true)"
      if [[ -n "$existing_stories" ]]; then
        analysis+="Existing User Stories:\n$existing_stories\n"
      fi
    fi
    analysis+="\n"
  fi

  # Get README content if exists
  if [[ -f "$root/README.md" ]]; then
    analysis+="README Summary:\n"
    analysis+="$(head -50 "$root/README.md" 2>/dev/null)\n\n"
  fi

  echo -e "$analysis"
}

ralph_prd_generator_build_prompt() {
  local description="$1"
  local analysis="$2"
  local existing_prd="$3"
  local mode="$4"  # "create" or "update"

  local prompt=""

  prompt+="# Ralph PRD Generator - AI-Powered User Story Creation

You are an expert software architect and product manager. Your task is to analyze a codebase and generate a Product Requirements Document (PRD) with well-structured user stories.

## Repository Analysis
$analysis

## User Request
$description

## Task
"

  if [[ "$mode" == "update" ]] && [[ -n "$existing_prd" ]]; then
    prompt+="UPDATE the existing PRD by:
1. Keeping completed stories (passes=true) as-is
2. Analyzing incomplete stories and improving them if needed
3. Adding new user stories based on the user's request
4. Ensuring proper dependency ordering

Existing PRD:
\`\`\`json
$existing_prd
\`\`\`

"
  else
    prompt+="CREATE a new PRD with intelligent user stories that:
1. Break down the feature into atomic, implementable units
2. Order stories by dependency (foundational first)
3. Include clear acceptance criteria for each story
4. Consider the existing codebase patterns and conventions

"
  fi

  prompt+="## Output Requirements

Return ONLY valid JSON matching this exact schema:
\`\`\`json
{
  \"title\": \"PRD: <descriptive title>\",
  \"version\": \"1.0.0\",
  \"status\": \"active\",
  \"created\": \"YYYY-MM-DD\",
  \"updated\": \"YYYY-MM-DD\",
  \"author\": \"ralph-ai\",
  \"overview\": {
    \"summary\": \"<1-2 sentence summary of the PRD scope>\"
  },
  \"userStories\": [
    {
      \"id\": \"US-001\",
      \"title\": \"<short, action-oriented title>\",
      \"description\": \"<detailed description of what needs to be implemented>\",
      \"priority\": 1,
      \"acceptanceCriteria\": [
        \"<specific, testable criterion 1>\",
        \"<specific, testable criterion 2>\",
        \"<specific, testable criterion 3>\"
      ],
      \"passes\": false,
      \"effort\": \"small|medium|large\",
      \"files\": [\"<likely files to modify>\"],
      \"dependencies\": [],
      \"status\": \"pending\"
    }
  ]
}
\`\`\`

## Story Creation Guidelines

1. **Atomic Stories**: Each story should be completable in 1-3 AI iterations
2. **Clear Acceptance Criteria**: 2-4 specific, testable criteria per story
3. **Proper Dependencies**: Foundation stories (data models, utils) come first
4. **Priority Order**: 1=highest priority, larger numbers=lower priority
5. **Effort Estimation**:
   - small: <100 lines of code, single file
   - medium: 100-300 lines, 2-3 files
   - large: 300+ lines, multiple files
6. **Files Array**: List specific files that will likely need changes
7. **Story Types to Consider**:
   - Data models / schemas
   - Core business logic
   - API endpoints / services
   - UI components
   - Integration / glue code
   - Tests / validation
   - Documentation (only if explicitly needed)

Generate 5-15 well-structured user stories. Return ONLY the JSON, no explanations."

  echo "$prompt"
}

ralph_prd_generator_extract_json() {
  local response="$1"

  # Try to extract JSON from response
  # First, try to find a complete JSON object
  local json=""

  # Look for JSON between ```json and ``` markers
  json="$(echo "$response" | sed -n '/```json/,/```/p' | sed '1d;$d')"

  if [[ -z "$json" ]]; then
    # Look for JSON between ``` markers (no language specified)
    json="$(echo "$response" | sed -n '/```/,/```/p' | sed '1d;$d')"
  fi

  if [[ -z "$json" ]]; then
    # Try to find raw JSON starting with {
    json="$(echo "$response" | grep -Pzo '\{[\s\S]*\}' 2>/dev/null | tr '\0' '\n' || true)"
  fi

  if [[ -z "$json" ]]; then
    # Last resort: assume entire response is JSON
    json="$response"
  fi

  # Validate JSON
  if command -v jq >/dev/null 2>&1; then
    if echo "$json" | jq -e . >/dev/null 2>&1; then
      echo "$json" | jq .
      return 0
    fi
  fi

  # Return raw if jq not available
  echo "$json"
}

ralph_prd_generator_run_agent() {
  local prompt="$1"
  local agent_cmd
  agent_cmd="$(ralph_prd_generator_resolve_agent_cmd)"
  local input_mode
  input_mode="$(ralph_prd_generator_get_agent_input_mode)"

  # shellcheck disable=SC2206
  local cmd=(${agent_cmd})
  if [[ "${#cmd[@]}" -eq 0 ]]; then
    ralph_prd_generator_log_error "Agent command not configured"
    return 1
  fi

  ralph_prd_generator_log_step "Running AI agent (${cmd[0]})..."

  local response=""
  local temp_file
  temp_file="$(mktemp)"

  if [[ "$input_mode" == "arg" ]]; then
    # Aider-style: pass prompt as argument
    "${cmd[@]}" "$prompt" 2>&1 | tee "$temp_file"
  else
    # Codex/Claude style: pass prompt via stdin
    printf "%s" "$prompt" | "${cmd[@]}" - 2>&1 | tee "$temp_file"
  fi

  response="$(cat "$temp_file")"
  rm -f "$temp_file"

  if [[ -z "$response" ]]; then
    ralph_prd_generator_log_error "Agent returned empty response"
    return 1
  fi

  echo "$response"
}

ralph_prd_generator_main() {
  local output="$1"
  shift
  local description="$*"

  # Print banner
  if declare -F ralph_print_banner >/dev/null 2>&1 && [[ "${RALPH_NO_BANNER:-}" != "1" ]]; then
    ralph_print_banner
  fi

  ralph_prd_generator_log "Starting AI-powered PRD generation"

  # Get description from stdin if not provided
  if [[ -z "$description" ]]; then
    if [[ -t 0 ]]; then
      ralph_prd_generator_log_error "Usage: ralph.sh generate-prd 'Feature description'"
      echo ""
      echo "Examples:"
      echo "  ./ralph.sh generate-prd 'Add user authentication with OAuth'"
      echo "  ./ralph.sh generate-prd 'Implement video recording during room scans'"
      echo "  echo 'Add dark mode support' | ./ralph.sh generate-prd"
      return 1
    fi
    description="$(cat)"
  fi

  description="$(ralph_prd_generator_trim "$description")"
  if [[ -z "$description" ]]; then
    ralph_prd_generator_log_error "Feature description is required"
    return 1
  fi

  ralph_prd_generator_log "Feature: $description"

  # Get repo root
  local root
  root="$(ralph_prd_generator_repo_root)"

  # Analyze repository
  local analysis
  analysis="$(ralph_prd_generator_analyze_repo "$root")"

  # Check for existing PRD
  local existing_prd=""
  local mode="create"
  if [[ -f "$output" ]]; then
    ralph_prd_generator_log_step "Found existing PRD at $output"
    existing_prd="$(cat "$output")"
    mode="update"
  fi

  # Build the prompt
  ralph_prd_generator_log_step "Building AI prompt..."
  local prompt
  prompt="$(ralph_prd_generator_build_prompt "$description" "$analysis" "$existing_prd" "$mode")"

  # Run the agent
  local response
  if ! response="$(ralph_prd_generator_run_agent "$prompt")"; then
    ralph_prd_generator_log_error "Agent failed to generate PRD"
    return 1
  fi

  # Extract and validate JSON
  ralph_prd_generator_log_step "Extracting and validating JSON..."
  local json
  json="$(ralph_prd_generator_extract_json "$response")"

  if [[ -z "$json" ]]; then
    ralph_prd_generator_log_error "Failed to extract valid JSON from agent response"
    echo "Raw response saved to /tmp/ralph-prd-response.txt"
    echo "$response" > /tmp/ralph-prd-response.txt
    return 1
  fi

  # Validate JSON structure
  if command -v jq >/dev/null 2>&1; then
    if ! echo "$json" | jq -e '.userStories | length > 0' >/dev/null 2>&1; then
      ralph_prd_generator_log_error "Generated PRD has no user stories"
      echo "$json" > /tmp/ralph-prd-invalid.json
      return 1
    fi

    # Pretty print and save
    mkdir -p "$(dirname "$output")"
    echo "$json" | jq . > "$output"

    # Report results
    local story_count
    story_count="$(echo "$json" | jq '.userStories | length')"
    local title
    title="$(echo "$json" | jq -r '.title')"

    ralph_prd_generator_log_success "PRD generated successfully!"
    echo ""
    echo "  Title: $title"
    echo "  Stories: $story_count"
    echo "  Output: $output"
    echo ""

    # Show story summary
    ralph_prd_generator_log "User Stories:"
    echo "$json" | jq -r '.userStories[] | "  \(.id): \(.title) [\(.effort)] - \(.acceptanceCriteria | length) criteria"'

  else
    # No jq, just save raw
    mkdir -p "$(dirname "$output")"
    echo "$json" > "$output"
    ralph_prd_generator_log_success "PRD generated at $output (install jq for validation)"
  fi

  return 0
}
