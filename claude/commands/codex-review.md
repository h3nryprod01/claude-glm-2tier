---
description: "Independent 3rd-opinion code review via Codex (a different vendor) on the current changes"
argument-hint: "[--base <branch>] [focus text]"
---
Get an INDEPENDENT review from Codex — a different vendor's model, so it catches things Opus and GLM
(both in the Anthropic/CC world) might share blind spots on. Read-only: Codex will not modify anything.

Do this:
1. Check Codex is available: run Bash `command -v codex`.
   - If missing: tell me to install it (`/plugin marketplace add openai/codex-plugin-cc` then `/codex:setup`,
     or `npm i -g @openai/codex` + `codex login`) and STOP.
2. Run the review (read-only) via Bash, choosing the target from my arguments `$ARGUMENTS`:
   - default (no args): `codex exec review --uncommitted`
   - if I passed `--base <branch>`: `codex exec review --base <branch>`
   - any remaining plain text = focus instructions, pass it as the final PROMPT arg
     (e.g. `codex exec review --uncommitted "challenge the retry/caching design"`).
   Never use `--dangerously-bypass-approvals-and-sandbox`.
3. Summarize Codex's findings for me. Explicitly flag where Codex AGREES with, CONTRADICTS, or ADDS to
   the earlier Opus review. Note: this draws your Codex usage limits and sends the diff to OpenAI.
