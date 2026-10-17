---
description: "Main (Sonnet) — turn a task into a plan in activeContext.md to hand off to the worker (claude-mimo / glm / kimi)"
argument-hint: <task to do>
---
Task: $ARGUMENTS

Don't code. Write a plan into `.claude/memory/activeContext.md` (create it if missing) with:
- **Goal** (1-2 sentences)
- **Plan**: steps B1..Bn, EACH with a concrete `verify:` command (e.g. `npm test -- foo`, `tsc --noEmit`)
- Break steps small & mechanical enough that the worker can execute without architectural reasoning
- State which files MAY be touched / MUST NOT be touched
- Set `status: WORKER_EXECUTING` when the plan is done

**Rewrite the `## Goal` / `## Plan` / `## Status` block in place — one cycle only.**
Anything already shipped moves to `progress.md` first. This file is a handoff bus, not a
log: every handoff re-reads it, so an append-only history makes every cycle more expensive
than the last. The largest one on disk reached 82 KB, of which 6 KB is ever actually loaded.

The worker may be a third-party provider: never put personal data, `.env` contents, secrets or
production data into the plan or the repo copy it works on.

Only plan. Do NOT execute — leave the coding to the worker (Tab B: `claude-mimo`).
