---
description: "Tab B (claude-glm) — read activeContext.md, execute the plan + self-verify"
---
Read `.claude/memory/activeContext.md` and execute the plan step by step.

- Run each step's `verify:` yourself — not green, not done.
- Minimal diff, follow the repo's CLAUDE.md (surgical, simplicity-first, immutable).
- When done: set `status: READY_FOR_OPUS_REVIEW` + `files changed:` + paste the REAL test/lint output.
- Do NOT report "done" to the user — you are the hands, Opus signs off.
- If stuck, write `status: BLOCKER` + a question into the file and stop. Don't guess.
