---
description: "Tab A (Opus) — turn a task into a plan in activeContext.md to hand off to GLM"
argument-hint: <task to do>
---
Task: $ARGUMENTS

Don't code. Write a plan into `.claude/memory/activeContext.md` (create it if missing) with:
- **Goal** (1-2 sentences)
- **Plan**: steps B1..Bn, EACH with a concrete `verify:` command (e.g. `npm test -- foo`, `tsc --noEmit`)
- Break steps small & mechanical enough that GLM can execute without architectural reasoning
- State which files MAY be touched / MUST NOT be touched
- Set `status: GLM_EXECUTING` when the plan is done

Only plan. Do NOT execute — leave the coding to GLM (Tab B).
