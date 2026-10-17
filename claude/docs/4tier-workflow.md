# Four-tier workflow: Main (Sonnet) + Worker (MiMo / GLM / Kimi) + Advisor (Opus) + Escalation (Fable)

Goal: do the bulk of the typing on a cheap, separate billing pool, keep one mid-priced model in
charge of the conversation, and spend the expensive model only on short, independent reviews.

```
                 1 GIT REPO   (.claude/memory/activeContext.md = handoff bus)

  ┌────────────────────┐   plan    ┌──────────────────────┐
  │ MAIN               │ ────────► │ WORKER               │
  │ claude (Sonnet 5.5)│           │ claude-mimo          │
  │ talks to you, plans│ ◄──────── │ (or claude-glm/-kimi)│
  │ integrates, reports│  READY    │ code + tests, self-  │
  └─────────┬──────────┘  _REVIEW  │ verifies, never      │
            │                      │ reports "done"       │
            │ diff + criteria      └──────────────────────┘
            ▼
  ┌────────────────────┐
  │ ADVISOR            │   independent, read-only, fresh context every time
  │ Opus 5.5 (Agent)   │   returns findings; Main fixes or hands the step back
  └─────────┬──────────┘
            │ only when the advisor is stuck:  ESCALATE: <question>
            ▼
  ┌────────────────────┐
  │ ESCALATION         │   read-only, rare, most expensive
  │ Fable 5.1 (Agent)  │   answers the stuck question; Main applies it
  └────────────────────┘
```

| Tier | Runs as | Does | Never does |
|---|---|---|---|
| Main | your normal `claude` session on Sonnet 5.5 | talk to you, plan (`/plan-handoff`), integrate, report | accept the worker's word that tests are green |
| Worker | `claude-mimo` in its own terminal (MiMo-V2.6-Pro, pay-as-you-go balance); alternates `claude-glm`, `claude-kimi` | execute the plan, run each `verify:`, write `READY_FOR_OPUS_REVIEW` + `executor:` | tell you "done"; touch files outside the plan; keep editing after READY |
| Advisor | an Opus 5.5 subagent (`Agent` with `subagent_type: Plan` + `model: opus`; that agent type has no Edit/Write/Agent tools) | review the diff AFTER output, run the tests, list what is wrong/overstated, what was missed, and concrete fixes | see the worker's conclusions (it gets paths + criteria only); call other agents or edit files |
| Escalation | a Fable 5.1 subagent (`Agent` with `subagent_type: Plan` + `model: fable`) | answer the one question the advisor could not settle | review routine diffs (too expensive); see the worker's or advisor's conclusions as facts |

Small jobs (a few lines, questions, lookups) Main does itself. The advisor still reviews anything
that produced output — skipping it "because it was small" is how bugs get through.

## When to escalate to Fable

Only when the Opus advisor is stuck. The advisor is told to end with a single line
`ESCALATE: <specific question>` when it cannot reach a verdict, is unsure on a logic / security /
money path, or two review rounds contradict each other. Main also escalates when one step has been
handed back to the worker twice and is still wrong. Main then:

1. writes the question, the paths, and what the advisor tried and where it got stuck (not the
   conclusions it wants checked) into the prompt,
2. launches `Agent` with `subagent_type: Plan` + `model: fable`,
3. applies the answer, or sends the changed diff back through the Opus advisor,
4. tells you it escalated and why.

Routine reviews never go to Fable. Limits: at most ONE Fable consult per step; if the diff re-reviewed
by the Opus advisor afterwards still ends in `ESCALATE:`, stop and ask the user. "Two review rounds
contradict" is judged by Main (each advisor is a fresh subagent and never sees earlier verdicts).

## Why this shape

- The earlier two-tier split had an Opus tab for planning AND review. Measured over the full
  transcript history, that tab burned more tokens than the worker did, because it was never
  restarted and every review re-sent ~500k tokens of session history. Here the advisor is a fresh
  subagent per review (a diff is a few KB), and the long-lived session is the cheaper Sonnet.
- Sonnet/Haiku subagents draw from the same Claude pool as the main session, so they do not
  relieve a weekly cap. Moving bulk work to a different pool (MiMo balance, GLM/Kimi plan) does.

## One-time setup

1. Worker key. For MiMo: sign up at platform.xiaomimimo.com, top up a small balance (do NOT enable
   auto-recharge), create an `sk-...` key under Console > API Keys (not the `tp-...` Token Plan key).
2. Store it without echoing it (the prompt hides what you paste):

   ```bash
   printf 'Paste MiMo key, then Enter: '; IFS= read -rs k; echo; printf '%s' "$k" | tr -d '[:space:]' > ~/.claude/.mimo-key && chmod 600 ~/.claude/.mimo-key; unset k
   ```
3. `EXEC_DRYRUN=1 claude-mimo` must print `ANTHROPIC_BASE_URL=https://api.xiaomimimo.com/anthropic`.

## Daily loop

1. **Main**: describe the task. `/plan-handoff <task>` writes goal + steps B1..Bn (each with a
   `verify:` command) into `.claude/memory/activeContext.md`.
2. **Worker**: either open a terminal in the repo, run `claude-mimo` and type `/glm-go` (legacy name,
   provider-agnostic), or run `worker-run --repo .` for one hands-off headless pass. It reads the plan, executes, self-verifies, writes `READY_FOR_OPUS_REVIEW`.
3. **Main**: `/opus-review` snapshots the tree, launches the Opus advisor on the diff, re-snapshots,
   fixes CRITICAL/HIGH (or hands the step back to the worker), escalates to Fable only if the
   advisor says `ESCALATE:`, records one scorecard line, and reports to you — including what the
   advisor caught.

From the desktop app, Main can launch `worker-run` itself in a real terminal tab; never run
`claude -p` nested inside a Bash tool call, it hangs.

## Rules that keep it safe and cheap

- **The worker is isolated from your personal setup, and sandboxed.** It runs with its own config dir
  (`~/.claude-worker`: a generic CLAUDE.md, a permission policy, no user-level hooks, memory or rules),
  so your CLAUDE.md, personal memory and hooks are NOT sent to the provider. `EXEC_SHARE_CONFIG=1` opts
  out; `EXEC_CONFIG_DIR` moves the dir. In one trial a small coding task took 105 s isolated versus 549 s with the personal hooks
  loaded (one run each, two different small tasks: an observation, not a benchmark).
  The policy (`claude/worker-config/settings.json`) turns Claude Code's Bash sandbox on
  (`failIfUnavailable`, no unsandboxed retry, no network domains, personal credential dirs unreadable),
  allows only git read-only, `ls` and the usual test/build commands, and denies reading secrets.
  `install.sh` refreshes this file on every install (the previous copy is kept as `settings.json.bak`).
- **What this does NOT protect.** A coding agent runs arbitrary code by design. The sandbox bounds Bash
  (writes to the repo and temp only, reads except the denied dirs, no allowed network domains: anything else is denied in headless runs and asks in an interactive session); the Read/Edit/Write
  tools follow permission rules instead; repo-level `.claude/settings.json` hooks and the repo's own
  CLAUDE.md are still loaded; and the provider receives the repo, the plan and every tool result. So
  never put personal data (PII), `.env`, secrets or production data in that repo or plan. Checked
  once (Claude Code 2.1.301, macOS): 6 risky probes (read a canary under `~/.claude` with cat, the Read tool and
  node, write outside the repo, curl, read the provider key from env) were all denied, and the control
  command `npm test` ran. The permission layer stopped them, so the OS sandbox itself was not separately exercised.
- **Persistence guard (a tripwire, not a guarantee).** Edits to `.git/`, `.envrc`, `.husky/`, `.githooks/`,
  `.vscode/`, `.devcontainer/`, `.idea/`, `.mcp.json` and `.claude/settings*.json` are denied by policy, and
  `worker-run` fingerprints the git hooks and config (common dir, worktree dir, the effective hooks dir
  including `core.hooksPath`) and those paths, at the repo top level too, before and after every run. Files are
  hashed in full (streamed); symlinks are recorded by link value AND target content, symlinked directories are
  walked through, FIFOs/devices are never opened. Any change is a `BLOCKER - SECURITY` in the bus and a
  non-zero exit, because a modified hook would execute on YOUR machine at your next commit. The worker's
  process group is killed when it returns and the check runs after a 1.5 s grace; an unreadable "after" state
  counts as an alert. The snapshot has limits (20,000 files per watched tree, 512 MB hashed, 60 s) and
  exceeding any of them fails closed: before the run the worker is not started, after the run it is an alert.
  **Known gaps:** a descendant that detaches into its own session can outlive the group
  kill and edit later (macOS has no cgroups to contain it); toolchain-specific auto-run files are unknown to it
  (package.json scripts, Makefiles, CI files are reviewed in the diff instead); and edits made by an
  interactive `claude-mimo` session are not fingerprinted, so check `git status` and `.git/hooks` yourself.
  WebFetch/WebSearch are denied too (the Bash sandbox does not cover them).
- **Consequences:** `failIfUnavailable` means the worker will not start on a machine without sandbox
  support (Linux needs `bubblewrap` and `socat`); an empty `allowedDomains` blocks `npm/pip install`
  during verification (install dependencies yourself first); verify commands outside the allow-list (go,
  cargo, make, `node -e`) are denied in headless mode: add them per run with `worker-run --allow
  "Bash(go test:*)"` or per repo in `.claude/settings.json`.
- **One worker per repo.** Two executors in one tree means the review reads a moving tree.
- **No automatic failover** on 429 or an empty balance: the worker writes `status: BLOCKER` and
  stops. Switch lane by hand (`claude-glm`, `claude-kimi`) or let Main do it. Automatic switching
  would also destroy the comparison `exec-scorecard` collects.
- **Cache is the cost lever on MiMo.** A cache miss costs 120x a cache hit; compact and fresh
  subagents break the cache. Keep worker sessions focused. Auto-compact is set to 400k for MiMo.
- **Headless runs cannot write the bus file, so use `worker-run`.** Claude Code refuses edits under
  `.claude/` in `-p` mode, and an explicit allow rule for `.claude/memory/**` does not override it
  (probed 2026-10-17 on Claude Code 2.1.301). `worker-run --repo . [--lane mimo]` runs one headless pass, has the worker print
  its report as the final answer, appends that report to `activeContext.md` from outside Claude Code,
  and logs the run's exact token usage to `~/.claude/exec-usage.jsonl`. The report is untrusted third-party
  output: it is stored in a fenced block and Main and the advisor must not follow instructions in it. Run it from a real terminal
  (the desktop app's terminal tool works); a nested `claude -p` inside a Bash tool call hangs. In an
  interactive `claude-mimo` session the worker writes the bus itself after you approve.
- **Track spend**: `session-usage --log` (exact, headless runs) and `session-usage --mimo --budget 10` (estimate; transcripts can undercount output tokens, ~25% in one run, so the
  provider's Balance page is the truth). `/cost` is meaningless on non-Anthropic providers.
- **Compare lanes**: `exec-scorecard --days 14` once there are >= 5 reviews per lane.

## `.claude/memory/activeContext.md` template (the handoff bus)

```markdown
# Active Context — <repo>

## Goal
<1-2 sentences>

## Plan  (Main writes)
- [ ] B1: … — verify: <command / expected result>
- [ ] B2: … — verify: …

## Status  (Worker updates)
- status: PLANNING | WORKER_EXECUTING | READY_FOR_OPUS_REVIEW | BLOCKER | DONE
- executor: <model name>
- files changed:
- test/lint:

## NOTES FOR ADVISOR / BLOCKER
<Worker writes questions or uncertainties here instead of guessing>
```

Rewrite the Goal / Plan / Status block in place each cycle; move finished work to `progress.md`.
This file is a bus, not a log.

## Worker lanes

`claude-mimo`, `claude-glm`, `claude-kimi` are symlinks to one script, `claude-exec`; only the
endpoint, key file and model names differ. Env is set per process, never in `settings.json`.

| Lane | Endpoint | Key | Billing | Model |
|---|---|---|---|---|
| mimo | `https://api.xiaomimimo.com/anthropic` | `~/.claude/.mimo-key` (`sk-`) | pay-as-you-go balance | `mimo-v2.6-pro[1m]` |
| glm | `https://api.z.ai/api/anthropic` | `~/.claude/.glm-key` | Coding Plan (credits, 5h + weekly caps) | `glm-5.2[1m]` (routed to 5.3 by the provider) |
| kimi | `https://api.kimi.com/coding/` | `~/.claude/.kimi-key` | Kimi Code subscription | `k3[1m]` |

Traps: MiMo's `tp-` Token Plan keys belong to a different host (`token-plan-*`) than the `sk-` API
key; Kimi has an Open Platform endpoint that bills per token and a subscription endpoint that does
not. The launcher refuses a MiMo key that is not `sk-` and strips inherited Anthropic credentials
before launching, so your Anthropic key/OAuth token is never sent to a third-party host.

| Want | Command |
|---|---|
| Main | `claude` |
| Worker (default) | `claude-mimo` |
| Other lanes | `claude-glm`, `claude-kimi` |
| See the env a lane would use | `EXEC_DRYRUN=1 claude-mimo` |
| Override a model | `MIMO_MODEL=mimo-v2.6-flash claude-mimo` (in one informal trial on 2026-10-17 Flash was slow and over-verbose on a one-word prompt; Pro is the default) |
| If tool calls leak into reasoning text | `MAX_THINKING_TOKENS=0 claude-mimo` |
