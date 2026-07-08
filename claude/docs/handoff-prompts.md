# Handoff prompt templates — copy-paste for the two-tier loop

Three prompts for three beats. The bus is `.claude/memory/activeContext.md`.
(If you installed the slash commands, use `/plan-handoff`, `/glm-go`, `/opus-review` instead.)

---

## ① Tab A — Opus PLANS (paste into `claude`)

```
Task: <what to build>.

Don't code. Write a plan into .claude/memory/activeContext.md:
- Goal (1-2 sentences)
- Steps B1..Bn, EACH with a concrete `verify:` command (e.g. `npm test -- foo`, `tsc --noEmit`)
- Break steps small & mechanical enough that GLM executes without architectural reasoning
- State which files MAY / MUST NOT be touched
- Set `status: GLM_EXECUTING` when done
```

## ② Tab B — GLM EXECUTES (paste into `claude-glm`)

```
Read .claude/memory/activeContext.md and execute the plan step by step. Run each step's `verify:`;
not green, not done. When done: set status READY_FOR_OPUS_REVIEW + files changed + real test output.
Do not report "done" — you are the hands. If stuck, write BLOCKER into the file and stop.
```

## ③ Tab A — Opus REVIEWS (paste into `claude`)

```
GLM just finished (status READY_FOR_OPUS_REVIEW in activeContext.md). Review `git diff`:
- bugs / security / does it match the plan
- anything out of scope (surgical?)
- are the tests REALLY green — run them yourself
Fix CRITICAL/HIGH now. Then give me a short summary: what was done, what needs my decision.
```

---

## When the Max cap is exhausted (fail-over)

Skip beats ①③, do everything in Tab B:

```
Read + write the plan into .claude/memory/activeContext.md yourself, then execute + self-verify.
Task: <task>. Minimal diff, follow the repo's CLAUDE.md.
```
