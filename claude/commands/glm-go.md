---
description: "Worker (claude-mimo / claude-glm / claude-kimi) — read activeContext.md, execute the plan + self-verify"
argument-hint: "[step range, e.g. B2.1-B2.3; empty = whatever the status line points at]"
---
Read `.claude/memory/activeContext.md` and execute the plan step by step.

Scope: $ARGUMENTS. If empty, do the steps the status line names.

- Run each step's `verify:` yourself — not green, not done.
- Minimal diff, follow the repo's CLAUDE.md (surgical, simplicity-first, immutable).
- When done: set `status: READY_FOR_OPUS_REVIEW` + `executor: <your model name>` + `files changed:`
  + paste the REAL test/lint output. The `executor:` line is what lets `exec-scorecard` tell the
  lanes apart — the review runs in a different session and has no other way to know who you were.
- Do NOT report "done" to the user — you are the hands, the advisor reviews and Main reports.
- If stuck, write `status: BLOCKER` + a question into the file and stop. Don't guess.
