---
description: "Offload code to GLM (separate pool) WITHIN this session; Opus self-verifies + reviews"
argument-hint: <task; empty = execute the plan in activeContext.md>
---
Offload the coding below to GLM to save Max quota, then verify and review it YOURSELF (don't trust GLM).

Task: $ARGUMENTS

Do this in order:
1. Run Bash (GLM writes the code — GLM pool, does NOT spend Max):
   `claude-glm --strict-mcp-config --permission-mode acceptEdits -p "<put the Task above here. If empty: read .claude/memory/activeContext.md and execute its plan>. Only change code as asked, minimal diff, follow the repo CLAUDE.md. Do NOT run tests — Opus will verify."`
   - To feed GLM more data: tell it to read specific files (paths) or write context into activeContext.md first — don't stuff it all into the prompt.
2. Read `git diff` to see what GLM changed.
3. Run the repo's verify yourself (test/build/lint) — don't trust GLM's "it's done".
4. Fix CRITICAL/HIGH issues if any. Report SHORT: what GLM did, verify result, what needs my decision.
