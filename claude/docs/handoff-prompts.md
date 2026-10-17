# Handoff prompt templates — copy-paste for the four-tier loop

Three prompts for three beats. The bus is `.claude/memory/activeContext.md`.
(If you installed the slash commands, use `/plan-handoff`, `/glm-go`, `/opus-review` instead.)

---

## ① Main (Sonnet) PLANS — paste into `claude`

```
Task: <what to build>.

Don't code. Write a plan into .claude/memory/activeContext.md:
- Goal (1-2 sentences)
- Steps B1..Bn, EACH with a concrete `verify:` command (e.g. `npm test -- foo`, `tsc --noEmit`)
- Break steps small & mechanical enough that the worker executes without architectural reasoning
- State which files MAY / MUST NOT be touched
- No personal data, secrets or production data in the plan or the repo copy the worker sees
- Set `status: WORKER_EXECUTING` when done
```

## ② Worker EXECUTES — paste into `claude-mimo` (or `claude-glm` / `claude-kimi`)

```
Read .claude/memory/activeContext.md and execute the plan step by step. Run each step's `verify:`;
not green, not done. When done: set status READY_FOR_OPUS_REVIEW + executor: <your model> +
files changed + real test output. Do not report "done" — you are the hands. If stuck (including
rate-limited or out of balance), write BLOCKER into the file and stop.
```

## ③ Main launches the OPUS ADVISOR — paste into `claude`

```
The worker just finished (status READY_FOR_OPUS_REVIEW in activeContext.md). Snapshot
`git status --porcelain && git diff --stat`, then launch an Agent (subagent_type Plan, model opus) on
the diff and the plan file (give it paths and criteria, not the worker's summary):
- bugs / security / does it match the plan
- anything out of scope (surgical?)
- run the plan's verify commands itself — the worker's "green" is not evidence
- if it is stuck it ends with one line `ESCALATE: <question>`; only then launch an Agent (subagent_type Plan,
  model fable, at most once per step) with the question + paths + where Opus got stuck
Re-snapshot, fix CRITICAL/HIGH (or hand the step back), then give me a short summary: what was
done, what the advisor caught, what needs my decision.
```

---

## When the worker is blocked (empty balance, 429)

Switch lane by hand (`claude-glm`, `claude-kimi`), or let Main do the step itself and then run the
advisor as usual. There is deliberately no automatic failover.
