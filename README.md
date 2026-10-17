I create this because I get weekly rate limit on Max x20 just after 3 working 5-hour windows.
Disappointed @Anthropic.

# claude-glm-2tier

**Keep coding after your Claude weekly cap runs out — without paying a premium model to type.**

(The repo started as a two-tier Opus + GLM split and kept its name. It is now a four-tier setup.)

A tiny, no-dependency setup that gives each model the job it is cheapest at:

| Tier | Model | Runs as | Job |
|---|---|---|---|
| 1. **Main** | Claude Sonnet 5.5 | your normal `claude` session | talks to you, plans, integrates, reports |
| 2. **Worker** | MiMo-V2.6-Pro (default), or GLM / Kimi | `claude-mimo` / `claude-glm` / `claude-kimi` | writes code, runs the tests, never says "done" |
| 3. **Advisor** | Claude Opus 5.5 | read-only subagent, fresh every review | independent review of the worker's diff, runs the tests itself |
| 4. **Escalation** | Claude Fable 5.1 | read-only subagent, rare | answers the one question the advisor could not settle |

They share one git repo and a plain handoff file (`.claude/memory/activeContext.md`). The worker
leaves the work as `READY_FOR_OPUS_REVIEW`; Main launches the advisor on the diff; only if the advisor
ends with `ESCALATE: <question>` does Fable get asked. Nothing reaches you unreviewed.

```
 Main (Sonnet) ──plan──► Worker (MiMo/GLM/Kimi) ──READY_FOR_OPUS_REVIEW──► Main
                                                                             │ diff + criteria
                                                                             ▼
                                                              Advisor (Opus, read-only)
                                                                             │ only if stuck: ESCALATE:
                                                                             ▼
                                                              Escalation (Fable, read-only)
```

## Why this works (and why Sonnet subagents don't)

If your bottleneck is the **weekly** cap, using Sonnet or Haiku subagents doesn't help: they draw
from the **same Claude pool**. To actually keep going you must move the bulk work to a **different
billing pool**. MiMo (pay-as-you-go balance), GLM (Coding Plan) and Kimi (Kimi Code) all expose
Anthropic-compatible endpoints that Claude Code can drive directly, so your Claude quota is spent on
planning, short reviews, and rare escalations.

A lesson from measuring the first version: the Opus tab that planned *and* reviewed burned more
tokens than the worker did, because it was never restarted and every review re-sent hundreds of
thousands of tokens of session history. The advisor is therefore a **fresh subagent per review**
(a diff is a few KB), and the long-lived session is the cheaper Sonnet.

## Requirements

- [Claude Code](https://claude.com/claude-code) installed (`claude` on your PATH) with a Claude
  subscription for Main, Advisor and Escalation.
- At least one worker lane: a [Xiaomi MiMo](https://platform.xiaomimimo.com) API key, a
  [Z.ai GLM Coding Plan](https://z.ai/subscribe), or a [Kimi Code](https://www.kimi.com/code) subscription.
- macOS or Linux, `bash`, `python3`.

## Install

```bash
git clone https://github.com/h3nryprod01/claude-glm-2tier.git
cd claude-glm-2tier
./install.sh
```

The installer copies into `~/.claude/` (launcher, role card, slash commands, docs, helper scripts), creates the
isolated worker config in `~/.claude-worker`, and symlinks `claude-mimo`, `claude-glm`, `claude-kimi`,
`worker-run`, `exec-scorecard`, `session-usage` into `~/.local/bin`. Run `./tests/run.sh` for the offline test suite. Your
`~/.claude/settings.json` is **not** touched, and an existing key file is never overwritten.

Then set up one lane. For MiMo:

1. Sign up at https://platform.xiaomimimo.com, top up a small balance (leave auto-recharge off),
   and create an `sk-...` key under Console > API Keys. A `tp-...` Token Plan key belongs to a
   different host and is rejected by the launcher on purpose.
2. Store the key without echoing it (the prompt hides what you paste):

   ```bash
   printf 'Paste MiMo key, then Enter: '; IFS= read -rs k; echo; printf '%s' "$k" | tr -d '[:space:]' > ~/.claude/.mimo-key && chmod 600 ~/.claude/.mimo-key; unset k
   ```
3. Check: `EXEC_DRYRUN=1 claude-mimo` should print `ANTHROPIC_BASE_URL=https://api.xiaomimimo.com/anthropic`.

For GLM put the key in `~/.claude/.glm-key`; for Kimi (Kimi Code key, not an Open Platform key)
in `~/.claude/.kimi-key`.

## Usage

```
Main   (claude):       /plan-handoff add input validation to the login form
Worker (claude-mimo):  /glm-go
Main   (claude):       /opus-review
```

`/glm-go` is a legacy name; it works for every worker lane. `/opus-review` snapshots the tree,
launches the Opus advisor on the diff (a read-only `Plan` subagent), re-snapshots, fixes CRITICAL/HIGH
findings (or hands the step back to the worker) and re-checks the fix, escalates to Fable 5.1 only if the
advisor says `ESCALATE:` (at most once per step), appends one
scorecard line, and reports what the advisor caught.

For a hands-off headless pass use `worker-run --repo .`: the worker prints its report, the wrapper appends
it to `activeContext.md` (Claude Code refuses edits under `.claude/` in `-p` mode) and logs the run's exact
token usage. From the Claude desktop app, Main can launch it in a real terminal tab. **Do not run
`claude -p` nested inside a Bash tool call** — it hangs.

Full loop, rules, and the `activeContext.md` template: [`claude/docs/4tier-workflow.md`](claude/docs/4tier-workflow.md)
and [`claude/docs/handoff-prompts.md`](claude/docs/handoff-prompts.md). The original measurements and
Kimi endpoint notes are kept in [`claude/docs/2tier-workflow.md`](claude/docs/2tier-workflow.md).

### Measuring a lane

```bash
session-usage --log                                           # exact numbers from headless runs
session-usage --mimo --budget 10                              # estimate from transcripts, both config dirs
exec-scorecard --days 14                                      # lanes compared on real reviews (installed on PATH)
```

`/cost` is meaningless on non-Anthropic providers (it prices tokens at Anthropic rates). Transcripts
undercount output tokens (about 25% in one run), so the provider's balance page is the source of truth
for interactive sessions; headless runs logged by `worker-run` are exact.

### Background jobs and third-opinion review (GLM-era extras)

`/glm`, `/glm-bg`, `/glm-status`, `/glm-result`, `/glm-cancel` and `glm-job` still target the GLM
lane (`GLM_BIN=claude-mimo glm-job ...` points the job runner at another lane). `/codex-review` adds
an independent review from a different vendor (Codex) through `codex exec review`; install
[openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) separately and run `codex login` once.

## Slash commands

| Command | Tier | What |
|---|---|---|
| `/plan-handoff <task>` | Main | Turn a task into a plan in `activeContext.md` |
| `/glm-go` | Worker | Read the plan, execute, self-verify (any lane) |
| `/opus-review` | Main | Run the Opus advisor on the diff, escalate to Fable only if stuck |
| `/glm <task>` | Main | Offload one chunk to `claude-glm` inline (nests Claude Code; may hang) |
| `/glm-bg <task>` | Main | Fire a GLM job in the background |
| `/glm-status [id]` · `/glm-result [id]` · `/glm-cancel [id]` | Main | Manage background GLM jobs |
| `/codex-review [--base b]` | Main | Independent third-opinion review via Codex (different vendor) |

## Rules that matter

- **The worker is isolated from your personal setup.** It runs with its own config dir
  (`~/.claude-worker`: generic CLAUDE.md, no user-level hooks or memory, Bash sandbox on, a narrow
  allow-list, secrets unreadable), so your own CLAUDE.md, memory and hooks are not sent to the provider
  (`EXEC_SHARE_CONFIG=1` opts out). A coding agent still runs arbitrary code and the provider receives the
  repo, the plan and every tool result: never put PII, `.env`, secrets or production data there. Limits and
  consequences (sandbox required, no `npm install` during verify, `--allow`) are in
  [`4tier-workflow.md`](claude/docs/4tier-workflow.md).
- **One worker per repo**, so the review never reads a moving tree.
- **No automatic failover** on 429 or an empty balance. The worker writes `status: BLOCKER` and
  stops; you switch lane by hand. Automatic switching would also destroy the comparison the
  scorecard collects.
- **Cache is the cost lever on MiMo**: a cache miss costs 120x a cache hit, so keep worker sessions
  focused. Auto-compact is set to 400k for MiMo (1M for the other lanes).

## Design notes / gotchas (learned the hard way)

- **Never put worker env in `~/.claude/settings.json`.** It is global and would turn every session
  into the worker. The launcher sets env per process, and strips inherited Anthropic credentials
  (`ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`) before launching, so they
  are never sent to a third-party host.
- **Transcripts of the worker live in `~/.claude-worker/projects`**; `exec-scorecard` and `session-usage` scan both dirs
  (`EXEC_SKIP_DIR` or the file `~/.claude/exec-skip-dir` excludes transcript paths containing a substring).
- **`--strict-mcp-config` on the worker.** With many MCP servers, tool schemas can overflow a
  smaller context window on startup. The worker doesn't need MCP, so it is disabled.
- **`CLAUDE_CODE_SUBAGENT_MODEL` and `ANTHROPIC_DEFAULT_FABLE_MODEL` are set on every lane**; without
  them a subagent spawned inside the worker silently falls back to a Claude model and leaks work back
  onto the pool this setup exists to spare.
- **Endpoints that look alike but bill differently.** Kimi has an Open Platform endpoint (per token)
  and a Kimi Code endpoint (subscription). MiMo has a pay-as-you-go host (`sk-` key) and Token Plan
  hosts (`tp-` key). The launcher pins the intended host per lane.
- **In `/model`, "Opus/Sonnet/Haiku" are only tier slots**; the launcher remaps them to the worker
  model, so the picker may say "Opus" while the real model is MiMo/GLM/Kimi.
- **MiMo quirks:** old `mimo-v2.5*` ids stop working 2026-10-21 (the launcher uses `mimo-v2.6-pro`).
  If tool calls leak into reasoning text, try `MAX_THINKING_TOKENS=0 claude-mimo`. `mimo-v2.6-flash`
  is accepted by the endpoint but was slow and over-verbose in one informal trial (2026-10-17), so Pro is the default.

## The Results

<img width="1241" height="550" alt="image" src="https://github.com/user-attachments/assets/5787d701-a5d2-4a6b-94e8-3eec2e28ac8c" />

This is Z lite plan, so cheap with the same output compare to Opus 4.8 (so f*cking expensive)
<img width="623" height="215" alt="image" src="https://github.com/user-attachments/assets/5b6ef6f3-9918-428b-9ef2-9ecb5ec2c897" />

## Security

Worker keys live in `~/.claude/.mimo-key`, `.glm-key`, `.kimi-key` (mode 600), outside this repo.
`.gitignore` blocks `*.key`, `.*-key` and `*.token`. No secret is ever committed.

## License

MIT — see [LICENSE](LICENSE).
