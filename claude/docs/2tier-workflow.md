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
3. Open a new terminal (so `claude-glm` is on PATH). Check: `claude-glm --version`.

---

## Daily loop

1. **Tab A (`claude`, Opus)** — brainstorm + write the plan into `.claude/memory/activeContext.md`
   (use the template below). Each step gets a `verify:` command.
2. **Switch to Tab B (`claude-glm`)** — say: *"read activeContext, do B1..Bn, self-verify each step."*
   GLM reads its role card automatically, executes, runs tests/lint.
3. **GLM done** → sets `status: READY_FOR_OPUS_REVIEW` + files changed + test results. It does NOT
   tell you it's "done".
4. **Back in Tab A (Opus)** — *"review the diff GLM just made"*. Opus reads `git diff` (not the whole
   repo), catches bugs, then reports to you.
5. Repeat.

→ 80% of mechanical work runs on the GLM pool. Your Max weekly cap only drains on plan+review.

---

## Review gate

```
GLM codes → GLM self-verifies (tests/lint GREEN, GLM pool) → Opus reviews the DIFF (Max pool) → reports to you
```

- Opus reviews **`git diff` only** — cheap (reading a diff << generating it).
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
| Hands (GLM) | `claude-glm` |
| Check GLM alive | `claude-glm --version` |
| Change GLM key | edit `~/.claude/.glm-key` |
| Use a different GLM model | `GLM_MODEL=glm-4.7 claude-glm` |

Most seamless: use **VS Code** — the Claude Code extension panel = Tab A (Opus), an integrated
terminal running `claude-glm` = Tab B (GLM). One window, both models, shared workspace.
