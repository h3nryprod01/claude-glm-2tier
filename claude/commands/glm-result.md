---
description: "Show a finished GLM background job's output, then verify + review it"
argument-hint: "[job-id]  (latest if omitted)"
---
1. Run Bash: `glm-job result $ARGUMENTS` (latest job if no id).
2. If the job is DONE: read `git diff`, run the repo's verify (test/build/lint) YOURSELF — don't trust GLM —
   then give me a short review: what GLM changed, is it correct/in-scope, what needs my decision.
3. If still RUNNING: just tell me, don't block.
