---
description: "Fire a coding task at GLM in the BACKGROUND (non-blocking); check later with /glm-status, /glm-result"
argument-hint: <task>
---
Start a background GLM job for the task below, then let me keep working — don't wait for it.

Run Bash: `glm-job start "$ARGUMENTS"`

Report the job id it prints and remind me: `/glm-status` to check, `/glm-result` to see + review output,
`/glm-cancel` to stop. The job runs on the GLM pool (does NOT spend Max quota) in the current repo.
