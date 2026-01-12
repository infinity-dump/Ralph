# Ralph

Ralph is an autonomous AI coding loop that ships features while you sleep.

A bash-based orchestration framework for running AI coding agents (Codex CLI, Claude Code, Aider, or custom agents) in an autonomous loop. It manages user stories from a PRD, tracks progress, and provides safety guardrails for unattended code generation.

## Quick Start

```bash
cd scripts/ralph

# Initialize template files
./ralph.sh init

# Edit prd.json with your user stories
# Run Ralph (default: 10 iterations, Codex agent)
./ralph.sh
```

## Features

- **Agent-agnostic**: Works with Codex CLI, Claude Code, Aider, or any custom agent
- **Fresh context per iteration**: Each iteration re-anchors from source files, preventing drift
- **Circuit breakers**: Configurable limits prevent runaway loops and detect stuck states
- **Quality gates**: Optional validation (TypeScript, Python, Go, Rust, etc.)
- **Git safety guard**: Blocks destructive git commands
- **Checkpoints**: Save/resume for long overnight runs
- **Parallel execution**: Run multiple stories simultaneously via git worktrees
- **Cost controls**: Budget limits and rate limiting
- **Planning phase**: Optional plan-first workflow with approval gates
- **Test-driven mode**: Run until all tests pass

## Documentation

Full documentation is available in [scripts/ralph/README.md](scripts/ralph/README.md).

## How It Works

A bash loop that:
1. Reads your PRD (`prd.json`) and picks the next incomplete story
2. Provides context to the AI agent (git state, iteration info, story details)
3. Agent implements the story
4. Validates completion and runs quality checks
5. Commits on success, logs learnings
6. Repeats until done or limits reached

Memory persists only through:
- Git commits
- `progress.txt` (learnings and gotchas)
- `prd.json` (task status)

## File Structure

```
scripts/ralph/
├── ralph.sh           # Main orchestration script
├── prd.json           # Product requirements (user stories)
├── prompt.md          # Agent instructions
├── progress.txt       # Progress log and learnings
├── modules/           # Optional feature modules
└── templates/         # Starter templates
```

## License

MIT
