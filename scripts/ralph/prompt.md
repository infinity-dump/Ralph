# Ralph Agent Instructions

## Compatibility

These instructions are agent-agnostic and work with Codex CLI or Claude Code.

## Workflow (Every Iteration)

1. Read `scripts/ralph/prd.json` from disk.
2. Read `scripts/ralph/progress.txt` (check Codebase Patterns first).
3. Check you are on the correct branch.
4. Pick the highest priority story where `passes: false`.
5. Implement that ONE story (keep scope tight).
6. Run typecheck and tests.
7. Update AGENTS.md files with learnings.
8. Commit: `feat: [ID] - [Title]`.
9. Update prd.json: set `passes: true` for the story.
10. Append learnings to progress.txt.

## Fresh Context Anchoring

- Treat every iteration as a clean start: re-open prd.json, progress.txt, and git state.
- Do not rely on cached memory of file contents; always re-read from disk.
- Ralph may prepend a "Ralph Iteration Context" section with git status and optional Codebase Patterns when `RALPH_CONTEXT_SUMMARY=1`; treat it as authoritative for the current run.

## Quality Criteria (Must Be True Before Completion)

- The chosen story’s acceptance criteria are satisfied.
- Typecheck and tests were executed (or explicitly noted as unavailable).
- AGENTS.md learning list is updated.
- prd.json updated for the story (`passes: true`, status updated if present).
- progress.txt entry appended with Learnings and Gotchas.
- Commit message matches: `feat: [ID] - [Title]`.

## Progress Format

APPEND to progress.txt:

## [Date] - [Story ID]
- What was implemented
- Files changed
- **Learnings:**
  - Patterns discovered
- **Gotchas:**
  - Gotchas encountered
---

Notes:
- Use date format YYYY-MM-DD.
- Always append an entry, even on failures; document what failed plus learnings/gotchas.
- Keep the Codebase Patterns section at the very top and read it before starting work.

## Codebase Patterns

Add reusable patterns to the TOP of progress.txt:

## Codebase Patterns
- Migrations: Use IF NOT EXISTS
- React: useRef<Timeout | null>(null)

## Stop Condition

If ALL stories pass, reply:
<promise>COMPLETE</promise>

Otherwise end normally.

## Browser Testing

For UI changes, use the dev-browser skill.

Example:

${CODEX_HOME:-~/.codex}/skills/dev-browser/server.sh &

cd ${CODEX_HOME:-~/.codex}/skills/dev-browser && npx tsx <<'EOF'
import { connect, waitForPageLoad } from "@/client.js";

const client = await connect();
const page = await client.page("test");
await page.setViewportSize({ width: 1280, height: 900 });

const port = process.env.PORT || "3000";
await page.goto(`http://localhost:${port}/your-page`);
await waitForPageLoad(page);
await page.screenshot({ path: "tmp/screenshot.png" });
await client.disconnect();
EOF

Not complete until verified with a screenshot.

## Common Gotchas

- Idempotent migrations
  - ADD COLUMN IF NOT EXISTS email TEXT;
- Interactive prompts
  - echo -e "\n\n\n" | npm run db:generate
- Schema changes
  - After editing schema, check server actions, UI components, API routes
  - Fixing related files is OK - not scope creep

## Monitoring

# Story status
cat scripts/ralph/prd.json | jq '.userStories[] | {id, passes}'

# Learnings
cat scripts/ralph/progress.txt

# Commits
git log --oneline -10
