---
description: "Tab A (Opus) — review the git diff GLM just produced before reporting to the user"
---
GLM just finished (status READY_FOR_OPUS_REVIEW in `.claude/memory/activeContext.md`).

Review `git diff`:
- bugs / security / does it match the plan
- did it change anything out of scope (surgical?)
- are the tests REALLY green — run them yourself, don't trust GLM's word

Fix any CRITICAL/HIGH issues now. Then give me a SHORT summary: what was done, what needs my decision.
