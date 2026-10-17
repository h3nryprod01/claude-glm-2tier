---
description: "Main (Sonnet) — launch the independent Opus advisor on the worker's git diff (escalate to Fable 5.1 only if it is stuck) before reporting to the user"
---
Review the worker's work through the Opus advisor. **Read everything from disk — do not rely on
this session's history.** If you need context, read `.claude/memory/activeContext.md`.

**1. Snapshot the tree first.** Before launching anything:

```bash
git status --porcelain && git diff --stat
```

Keep that output. A worker writing `READY_FOR_OPUS_REVIEW` does not mean it stopped — executors
have been observed to keep editing while a review was underway. Trust the tree, not the status.

**2. Launch the advisor** — `Agent` with `subagent_type: Plan` + `model: opus` (that agent type has no
Edit/Write/Agent tools, so read-only is requested AND Edit/Write are unavailable; Bash could still write, so say so in the prompt), foreground (you need its
answer next). Tell it explicitly not to call other agents. Give it: the repo path, the path to `activeContext.md` (the plan), `git diff` / `git diff
--staged` as the thing to review, and the criteria. Do NOT give it the worker's summary or your
own conclusion. Criteria to include:

- bugs / security / does the diff match the plan; anything out of scope (was it surgical?)
- run the plan's `verify:` commands itself — the worker's word that tests are green is not evidence
- may run tests and read files, must NOT edit anything
- answer in <= 25 lines: (a) wrong/overstated, (b) missed, (c) concrete fixes; no flattery
- if it cannot reach a verdict, is unsure on a logic/security/money path, or contradicts an earlier
  review round, end with exactly one line `ESCALATE: <specific question>` (and say what it tried)

**2b. Escalate only if the advisor wrote `ESCALATE:` (or one step has gone back to the worker twice
and is still wrong).** Launch `Agent` with `subagent_type: Plan` + `model: fable`, foreground. At most ONE Fable consult
per step: if the changed diff, re-checked by the Opus advisor, still ends in `ESCALATE:`, stop and ask
the user. "Two review rounds contradict" is judged by you (each advisor is a fresh subagent and never
sees earlier verdicts). Prompt = the
question, the repo/plan/diff paths, and what the advisor tried and where it got stuck — not the
conclusions you want confirmed. Apply the answer, or run the changed diff through the Opus advisor
again. Never use Fable for routine review (most expensive tier). Tell the user you escalated and why.

**3. Re-snapshot before you act.** Run the same `git status --porcelain && git diff --stat`. If it
differs from step 1, the tree moved under the review: say so, stop, and ask the user to stop the
worker before continuing.

**4. Act on the findings.** Fix CRITICAL/HIGH now (or hand the step back to the worker with the
finding written into `activeContext.md`). Anything you changed yourself is output too: re-run the
advisor on that small fix diff before reporting. Anything below CRITICAL/HIGH goes in the summary as a note. If you
find yourself writing more than a handful of edits, the handoff failed — say so and record it in
`activeContext.md` so a failed handoff is visible.

**5. Record one scorecard line.** Append to `~/.claude/exec-scorecard.jsonl` (create if absent):

```json
{"ts":"<ISO8601 UTC>","repo":"<repo dir name>","executor":"<the `executor:` line from activeContext.md>","critical":<n>,"high":<n>,"rework":<true|false>}
```

`rework` is true when you hand the same step back to the executor instead of fixing it or moving
on. This is the only place the lanes get compared on real work. One line, append-only; never let
it block the review.

**6. Report.** A SHORT summary: what was done, **what the advisor caught**, what needs the user's
decision. The advisor is a fresh subagent each time, so there is nothing to close afterwards.
