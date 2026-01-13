# Ralph - Autonomous Agent Loop

Ralph is a bash-based orchestration framework for running AI coding agents (Codex CLI, Claude Code, Aider, or custom agents) in an autonomous loop. It manages user stories from a PRD (Product Requirements Document), tracks progress, and provides safety guardrails for unattended code generation.

## Table of Contents

- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Commands](#commands)
- [Environment Variables](#environment-variables)
- [Modules](#modules)
- [File Structure](#file-structure)
- [Workflow](#workflow)
- [Examples](#examples)

## Quick Start

```bash
# 1. Initialize template files (first time setup)
./ralph.sh init

# 2. Edit prd.json with your user stories
nano scripts/ralph/prd.json

# 3. Customize prompt.md for your project
nano scripts/ralph/prompt.md

# 4. Run Ralph with default settings (10 iterations, Codex agent)
./ralph.sh

# Or specify max iterations
./ralph.sh 20
```

## Core Concepts

### How Ralph Works

1. **Iteration Loop**: Ralph runs in a loop, with each iteration:
   - Selecting the highest-priority incomplete user story
   - Providing context to the AI agent (iteration info, story details, git status)
   - Running the agent to implement the story
   - Checking if the story passes (via `passes: true` in prd.json)
   - Recording progress and handling failures

2. **User Stories**: Defined in `prd.json`, each story has:
   - `id`: Unique identifier (e.g., "US-001")
   - `title`: Short description
   - `priority`: Number (lower = higher priority)
   - `acceptanceCriteria`: Array of requirements
   - `passes`: Boolean indicating completion
   - `dependencies`: Array of story IDs that must complete first

3. **Agent Presets**: Built-in support for:
   - **codex** (default): Uses `codex exec --dangerously-bypass-approvals-and-sandbox`
   - **claude**: Uses `claude --dangerously-skip-permissions`
   - **aider**: Uses `aider --message-file`
   - **custom**: Set `RALPH_AGENT_CMD` for any agent

4. **Safety Features**: Circuit breakers, git guards, checkpoints, and quality gates prevent runaway loops.

## Commands

### Main Script

```bash
# Basic run (default: 10 iterations)
./ralph.sh

# Specify max iterations
./ralph.sh 25

# Resume from checkpoint
./ralph.sh --resume

# Resume with new max iterations
./ralph.sh --resume 50
```

### Initialize Templates

```bash
# Copy template files to working directory
./ralph.sh init

# Force overwrite existing files
./ralph.sh init --force
```

### Generate PRD (AI-Powered)

The `generate-prd` command uses AI to analyze your repository and generate intelligent user stories:

```bash
# Generate a PRD - AI analyzes repo structure, tech stack, and existing code
./ralph.sh generate-prd "Add user authentication with OAuth support"

# Update existing PRD with new stories (preserves completed stories)
./ralph.sh generate-prd "Add password reset functionality"

# Use Claude instead of Codex
RALPH_AGENT=claude ./ralph.sh generate-prd "Implement video recording"

# Read description from stdin
echo "Add dark mode support" | ./ralph.sh generate-prd
```

**What the AI analyzes:**
- Repository structure and tech stack (Node.js, Python, Swift, Go, etc.)
- Existing source files and patterns
- README and documentation
- Existing PRD stories (for updates)

**What it generates:**
- 5-15 atomic user stories with proper dependencies
- Clear acceptance criteria (2-4 per story)
- Effort estimates (small/medium/large)
- Suggested files to modify

### Monitor Commands

```bash
# Start tmux monitoring dashboard (requires RALPH_LOG)
RALPH_LOG=ralph.log ./ralph.sh monitor start

# Attach to monitoring session
./ralph.sh monitor attach

# Stop monitoring dashboard
./ralph.sh monitor stop

# Check current status
./ralph.sh monitor status

# Send test notification
RALPH_NOTIFY=1 ./ralph.sh monitor notify success "Build completed!"
```

## Environment Variables

### Agent Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_AGENT` | Agent preset: `codex`, `claude`, `aider`, `custom` | `codex` |
| `RALPH_AGENT_CMD` | Custom agent command (overrides preset) | - |
| `RALPH_REVIEWER_CMD` | Command for adversarial review | Same as agent |

### Iteration Control

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_ITERATIONS` | Maximum iterations before stopping | `10` |
| `MAX_CONSECUTIVE_FAILURES` | Stop after N consecutive failures | `3` |
| `RALPH_WARN_AT` | Iteration number to show warning | `8` |
| `RALPH_SINGLE_STORY` | Complete one story then stop | `0` |
| `RALPH_STORY_ID` | Target specific story ID | - |
| `RALPH_TASK_TYPE` | `quick`(5), `standard`(10), `complex`(25) iterations | - |

### Modes

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_MODE` | `stories` (PRD-based) or `tests` (test-driven) | `stories` |
| `RALPH_PARALLEL` | Enable parallel worktree execution | `0` |
| `RALPH_PARALLEL_MAX` | Max parallel workers | `2` |

### Quality & Safety

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_QUALITY_GATES` | `1` (non-blocking) or `strict` (blocking) | - |
| `RALPH_GIT_GUARD` | Block destructive git commands | `0` |
| `RALPH_ADVERSARIAL` | Enable adversarial review after each iteration | `0` |

### Planning Phase

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_PLANNING_PHASE` | Enable planning before implementation | `0` |
| `RALPH_PLAN_APPROVAL` | `auto` or `manual` | `auto` |
| `RALPH_PLAN_APPROVED` | Set to `1` to approve pending plan | - |
| `RALPH_PLAN_SELF_REVIEW` | Add self-review section to plans | `0` |
| `RALPH_PLAN_FILE` | Plan file location | `.ralph-plan.md` |

### Checkpoints & Resume

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_CHECKPOINT` | Enable checkpointing | `0` |
| `RALPH_CHECKPOINT_FILE` | Checkpoint file path | `.ralph-checkpoint.json` |
| `RALPH_CHECKPOINT_EVERY` | Save checkpoint every N iterations | `1` |

### Cost & Rate Limiting

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_MAX_COST` | Maximum spend limit (e.g., "$10.00") | - |
| `RALPH_COST_PER_ITERATION` | Fixed cost per iteration | - |
| `RALPH_RATE_LIMIT` | Max iterations per minute | - |

### Phase Chaining

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_PHASE_CHAINING` | Enable phase-based execution | `0` |
| `RALPH_PHASES` | Comma-separated phase list | `data,api,ui` |
| `RALPH_PHASE_CURRENT` | Current phase to execute | First phase |

### Monitoring & Logging

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_LOG` | Log file path (enables logging) | - |
| `RALPH_VERBOSE` | Enable verbose output | `0` |
| `RALPH_MONITOR` | Enable real-time monitoring | `0` |
| `RALPH_MONITOR_MODE` | `stream` or `tmux` | `stream` |
| `RALPH_NOTIFY` | Enable desktop notifications | `0` |
| `RALPH_NOTIFY_CMD` | Custom notification command | Auto-detect |

### Hooks & External Access

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_ALLOW_EXTERNAL` | Enable external tool access | `0` |
| `RALPH_PRE_HOOK` | Shell command to run before each iteration | - |
| `RALPH_POST_HOOK` | Shell command to run after each iteration | - |

### Caching

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_CACHE` | Enable context caching | `0` |
| `RALPH_CACHE_DIR` | Cache directory | `.ralph-cache` |
| `RALPH_CACHE_TTL` | Cache TTL in seconds | `86400` |
| `RALPH_CACHE_CLEAR` | Force cache refresh | `0` |

### Test Mode

| Variable | Description | Default |
|----------|-------------|---------|
| `RALPH_TEST_CMD` | Custom test command | Auto-detect |
| `RALPH_TEST_FRAMEWORK` | Test framework hint | Auto-detect |

## Modules

Ralph is built with a modular architecture. Each module provides specific functionality:

### circuit-breaker.sh
Prevents runaway loops by tracking failures and stopping execution when thresholds are exceeded.
- Consecutive failure detection
- Stuck story detection (same story failing repeatedly)
- Model-specific iteration limits
- Warning messages near iteration limits

### quality-gates.sh
Runs validation checks after each iteration:
- TypeScript (`tsc --noEmit`)
- Python (pyright or ruff)
- Go (`go test ./...`)
- Rust (`cargo check`)
- JSON/YAML validation
- PRD acceptance criteria validation
- Project test suite

### planner.sh
Optional planning phase before implementation:
- Creates implementation plans in `.ralph-plan.md`
- Maps acceptance criteria to planned steps
- Supports manual approval gates
- Self-review section option

### reviewer.sh
Adversarial review of agent output:
- Runs a second agent as critic
- Focuses on edge cases, security, logic errors
- Non-blocking by default

### git-guard.sh
Blocks potentially destructive git commands:
- `git reset --hard`
- `git push --force`
- `git clean -f`
- `git branch -D`

### checkpoint.sh
Saves progress for resume capability:
- Iteration state
- Completed stories
- Failure tracking
- JSON format for easy inspection

### parallel.sh
Runs multiple stories in parallel using git worktrees:
- Creates isolated worktrees per story
- Handles merge coordination
- Lock-based concurrency control

### cost-control.sh
Manages API costs and rate limiting:
- Budget tracking and enforcement
- Rate limiting (iterations per minute)
- Phase chaining for ordered execution
- Task type presets (quick/standard/complex)

### cache.sh
Caches context between iterations:
- Codebase patterns
- Learnings from AGENTS.md
- Common errors/gotchas
- TTL-based refresh

### monitor.sh
Real-time monitoring and notifications:
- Stream mode (stdout updates)
- Tmux dashboard mode
- Desktop notifications (macOS, Linux, Windows)
- Status file for external tools

### prd-generator.sh
Generates PRD files from feature descriptions:
- Template-based generation
- AI-assisted generation option
- Automatic story breakdown

## File Structure

```
scripts/ralph/
├── ralph.sh           # Main orchestration script
├── prd.json           # Product requirements (user stories)
├── prompt.md          # Agent instructions
├── progress.txt       # Progress log and learnings
├── modules/
│   ├── cache.sh
│   ├── checkpoint.sh
│   ├── circuit-breaker.sh
│   ├── cost-control.sh
│   ├── git-guard.sh
│   ├── monitor.sh
│   ├── parallel.sh
│   ├── planner.sh
│   ├── prd-generator.sh
│   ├── quality-gates.sh
│   └── reviewer.sh
└── templates/
    ├── prd-template.json
    ├── prompt-template.md
    └── progress-template.txt
```

## Workflow

### Standard PRD-Based Workflow

```bash
# 1. Generate or create your PRD
./ralph.sh generate-prd "Build a REST API for user management"

# 2. Review and customize prd.json
nano scripts/ralph/prd.json

# 3. Customize prompt.md for your project conventions
nano scripts/ralph/prompt.md

# 4. Run Ralph with safety features
RALPH_CHECKPOINT=1 RALPH_GIT_GUARD=1 ./ralph.sh 20

# 5. If interrupted, resume from checkpoint
./ralph.sh --resume
```

### Test-Driven Workflow

```bash
# Run until all tests pass
RALPH_MODE=tests ./ralph.sh 30
```

### Parallel Execution

```bash
# Run up to 3 stories in parallel
RALPH_PARALLEL=1 RALPH_PARALLEL_MAX=3 ./ralph.sh
```

### Monitored Overnight Run

```bash
# Full-featured overnight run with monitoring
RALPH_LOG=ralph.log \
RALPH_MONITOR=1 \
RALPH_NOTIFY=1 \
RALPH_CHECKPOINT=1 \
RALPH_GIT_GUARD=1 \
RALPH_QUALITY_GATES=1 \
RALPH_MAX_COST='$50.00' \
./ralph.sh 100

# In another terminal, attach to monitor
./ralph.sh monitor attach
```

### With Planning Phase

```bash
# Enable planning with manual approval
RALPH_PLANNING_PHASE=1 \
RALPH_PLAN_APPROVAL=manual \
./ralph.sh 20

# After reviewing .ralph-plan.md, approve and continue
RALPH_PLAN_APPROVED=1 ./ralph.sh 20
```

## Examples

### Using Claude Code as Agent

```bash
RALPH_AGENT=claude ./ralph.sh 15
```

### Using Aider

```bash
RALPH_AGENT=aider ./ralph.sh 10
```

### Custom Agent Command

```bash
RALPH_AGENT=custom \
RALPH_AGENT_CMD="my-agent --batch-mode" \
./ralph.sh 20
```

### Targeting a Specific Story

```bash
RALPH_STORY_ID=US-003 ./ralph.sh 5
```

### Quick Task (5 iterations max)

```bash
RALPH_TASK_TYPE=quick ./ralph.sh
```

### Complex Task with Budget

```bash
RALPH_TASK_TYPE=complex \
RALPH_MAX_COST='$25.00' \
./ralph.sh
```

### Rate-Limited Execution

```bash
# Max 20 iterations per minute
RALPH_RATE_LIMIT=20 ./ralph.sh 100
```

### Phase-Based Execution

```bash
# Execute in phases: data -> api -> ui
RALPH_PHASE_CHAINING=1 \
RALPH_PHASES="data,api,ui" \
./ralph.sh 30
```

### Strict Quality Gates

```bash
# Fail iteration if quality checks fail
RALPH_QUALITY_GATES=strict ./ralph.sh 20
```

### With Adversarial Review

```bash
# Second agent reviews each iteration
RALPH_ADVERSARIAL=1 ./ralph.sh 15
```

### Non-Git Repository

```bash
RALPH_SKIP_GIT_CHECK=1 ./ralph.sh 10
```

## Exit Codes

- `0`: Success (all stories completed or tests passing)
- `1`: Failure (max iterations, circuit breaker, budget exceeded, etc.)

## Output Files

- `.ralph-checkpoint.json`: Resume state
- `.ralph-plan.md`: Planning phase output
- `.ralph-monitor-status`: Real-time status (JSON)
- `.ralph-cache/`: Cached context files

## Tips

1. **Start Small**: Begin with 5-10 iterations to validate your setup
2. **Use Checkpoints**: Enable `RALPH_CHECKPOINT=1` for long runs
3. **Review Progress**: Check `progress.txt` for learnings and gotchas
4. **Git Guard**: Enable `RALPH_GIT_GUARD=1` to prevent destructive operations
5. **Monitor Long Runs**: Use `RALPH_NOTIFY=1` to get desktop notifications
6. **Phase Chaining**: Use phases to ensure data models exist before APIs
7. **Quality Gates**: Enable `RALPH_QUALITY_GATES=1` for continuous validation
