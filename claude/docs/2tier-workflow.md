> **Superseded 2026-10-17 by [4tier-workflow.md](4tier-workflow.md)** (Main Sonnet + Worker MiMo/GLM/Kimi + Advisor Opus + Escalation Fable). Kept for the measurements and the executor-lane notes below.

# Two-tier workflow: Opus (brain) + GLM (hands)

Goal: keep working even after your Claude Max **weekly** cap runs out, by pushing ~80% of the
mechanical work to a different billing pool (GLM Coding Plan, flat-fee). Opus only spends quota
on the expensive-but-rare parts: planning + review.

```
        1 GIT REPO  (.claude/memory/activeContext.md = handoff bus)
        ┌──────────────┐            ┌──────────────┐
Tab A → │ claude (Max) │            │ claude-glm   │ ← Tab B
        │ = OPUS       │  activeContext.md  │ = GLM-5.2 │
        │ THE BRAIN    │ ─── plan ──►│ THE HANDS    │
        │ plan+review  │ ◄── review─ │ code+test    │
        └──────────────┘            └──────────────┘
         spends Max pool             spends GLM pool
```

Key idea: Sonnet/Haiku subagents do NOT relieve a weekly cap — they draw from the *same* Claude
pool. To actually keep going you must move bulk work to a *different* pool. GLM Coding Plan is
that pool.

---

## One-time setup (3 manual steps only you can do)

1. Buy a **GLM Coding Plan** at https://z.ai/subscribe (Lite is enough to start). Create an **API key**.
2. Paste the key (one line) into `~/.claude/.glm-key` (the installer creates it with mode 600).
3. Open a new terminal (so `claude-glm` / `claude-kimi` are on PATH). Check: `claude-glm --version`.

---

## Daily loop

1. **Tab A (`claude`, Opus)** — brainstorm + write the plan into `.claude/memory/activeContext.md`
   (use the template below). Each step gets a `verify:` command.
2. **Switch to Tab B (`claude-glm` or `claude-kimi`)** — say: *"read activeContext, do B1..Bn, self-verify each step."*
   GLM reads its role card automatically, executes, runs tests/lint.
3. **GLM done** → sets `status: READY_FOR_OPUS_REVIEW` + files changed + test results. It does NOT
   tell you it's "done".
4. **Back in Tab A (Opus)** — *"review the diff GLM just made"*. Opus reads `git diff` (not the whole
   repo), catches bugs, then reports to you.
5. **Close Tab A.** Its state lives in `activeContext.md` — that is what the bus is for.
6. Repeat, from a fresh Tab A.

→ Mechanical work runs on the GLM pool. But **plan+review are not free**, and step 5 is what
keeps them cheap.

**Measured 2026-08-01, over the full transcript history — read this before trusting the
paragraph above:** Opus plan+review consumed **1,421M Max-pool tokens** against GLM's
**1,279M** GLM-pool tokens. The brain cost *more* than the hands. Not because reviewing is
expensive — a diff is a few KB — but because `/opus-review` was firing at a median context of
**532k** (p90 804k) inside a Tab A that never restarted, so ~95% of each review's cost was
re-sending accumulated session history. The same 17 never-closed Tab A sessions were 0.33% of
all sessions and 34.7% of all tokens ever spent.

A Tab A that survives more than one plan→review cycle is the leak. Close it.

---

## Review gate

```
GLM codes → GLM self-verifies (tests/lint GREEN, GLM pool) → Opus reviews the DIFF (Max pool) → reports to you
```

- Opus reviews **`git diff` only** — cheap *if the session is fresh*. Reading a diff is far
  cheaper than generating it, but only the diff is small; the session around it is not.
- Opus must **snapshot `git status --porcelain` before and after** the review. GLM has been
  observed to keep editing after writing `READY_FOR_OPUS_REVIEW`; a review of a moving tree
  is worthless, and the one time it happened the whole 2-tier split was abandoned mid-task.
- GLM must leave tests green first → Opus never wastes quota reviewing broken code.
- Tier the depth: mechanical changes get a skim; logic / security / money paths get a deep review.

---

## `.claude/memory/activeContext.md` template (the handoff bus)

```markdown
# Active Context — <repo>

## Goal
<1-2 sentences>

## Plan  (Opus writes)
- [ ] B1: … — verify: <command / expected result>
- [ ] B2: … — verify: …

## Status  (GLM updates)
- status: PLANNING | GLM_EXECUTING | READY_FOR_OPUS_REVIEW | DONE
- files changed:
- test/lint:

## NOTES FOR OPUS / BLOCKER
<GLM writes questions or uncertainties here instead of guessing>
```

---

## Fail-over (the "keep working" guarantee)

- **Normal:** Opus is the brain, GLM is the hands.
- **Max weekly cap exhausted:** close Tab A. Do everything in Tab B — GLM plans+codes+reviews itself.
  Quality on the hard 20% dips a notch, but work never stops, until Max resets.
- **Rare: GLM plan also exhausted:** upgrade the GLM tier, or fall back to another provider.

---

## Cheatsheet

| Want | Command |
|---|---|
| Brain (Opus, Max) | `claude` |
| Hands — GLM | `claude-glm` |
| Hands — Kimi | `claude-kimi` |
| Check a lane is alive | `claude-glm --version` / `claude-kimi --version` |
| See the env a lane would use | `EXEC_DRYRUN=1 claude-kimi` |
| Change a key | edit `~/.claude/.glm-key` / `~/.claude/.kimi-key` |
| Use a different model | `GLM_MODEL=glm-4.7 claude-glm` · `KIMI_MODEL=kimi-k2.7-code claude-kimi` |
| Compare the two lanes | `exec-scorecard --days 14` |

## Two executor lanes

`claude-glm` and `claude-kimi` are symlinks to one script, `~/.claude/scripts/claude-exec` —
same role card, same flags, only the endpoint and model names differ. 

**Kimi ships TWO Anthropic-compatible endpoints and they bill completely differently:**

| endpoint | product | billing |
|---|---|---|
| `api.moonshot.ai/anthropic` | Kimi **Open Platform** | **per token** |
| `api.kimi.com/coding/` | Kimi **Code** (subscription) | flat monthly |

The launcher uses the second one. Both work; only one respects the plan you paid for.
Subscribe at [kimi.com/membership/pricing](https://www.kimi.com/membership/pricing), then create
the key in the [Kimi Code Console](https://www.kimi.com/code/console) — not on
`platform.kimi.ai`. Kimi's terms allow the subscription key in Kimi Code CLI, **Claude Code**,
and Roo Code; using it elsewhere can get access restricted.

Run them on **different repos**, not the same one. Two executors in one working tree means the
review reads a moving tree, which is exactly the failure that once got a whole handoff thrown
away. There is deliberately no automatic 429 failover: switching provider mid-task would also
destroy the comparison `exec-scorecard` is collecting. Blocked → switch tabs by hand.

Most seamless: use **VS Code** — the Claude Code extension panel = Tab A (Opus), an integrated
terminal running `claude-glm` = Tab B (GLM). One window, both models, shared workspace.
