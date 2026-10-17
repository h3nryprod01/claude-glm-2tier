#!/usr/bin/env bash
# Installer for the four-tier workflow: Main (Sonnet) + Worker (MiMo / GLM / Kimi) + Advisor (Opus)
# + Escalation (Fable). Copies files into ~/.claude and puts the worker launchers on your PATH.
# Idempotent. Never touches ~/.claude/settings.json and never overwrites an existing key file.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

echo "Installing into $CLAUDE ..."
mkdir -p "$CLAUDE/scripts" "$CLAUDE/commands" "$CLAUDE/docs" "$HOME/.local/bin"

for f in "$HERE"/claude/scripts/*; do
  install -m 0755 "$f" "$CLAUDE/scripts/$(basename "$f")"
done
cp "$HERE/claude/executor-role.md" "$CLAUDE/executor-role.md"
cp "$HERE"/claude/commands/*.md    "$CLAUDE/commands/"
cp "$HERE"/claude/docs/*.md        "$CLAUDE/docs/"

# One launcher script (claude-exec); one symlink per worker lane. A key file is created empty with
# locked-down perms if absent (an existing key is never overwritten).
for lane in glm kimi mimo; do
  [ -f "$CLAUDE/.$lane-key" ] || : > "$CLAUDE/.$lane-key"
  chmod 600 "$CLAUDE/.$lane-key"
  ln -sf claude-exec "$CLAUDE/scripts/claude-$lane"
  ln -sf "$CLAUDE/scripts/claude-$lane" "$HOME/.local/bin/claude-$lane"
done
for tool in glm-job exec-scorecard session-usage; do
  ln -sf "$CLAUDE/scripts/$tool" "$HOME/.local/bin/$tool"
done

echo
echo "Installed."
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) echo "Add ~/.local/bin to your PATH, e.g.:  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
esac
echo
echo "Next steps (pick at least one worker lane; MiMo shown, see the docs for glm / kimi):"
echo "  1) Sign up at https://platform.xiaomimimo.com, top up a small balance (no auto-recharge),"
echo "     create an sk-... key under Console > API Keys (NOT a tp-... Token Plan key)."
echo "  2) Store it without echoing it:"
echo "       printf 'Paste MiMo key, then Enter: '; IFS= read -rs k; echo; printf '%s' \"\$k\" | tr -d '[:space:]' > $CLAUDE/.mimo-key && chmod 600 $CLAUDE/.mimo-key; unset k"
echo "  3) Open a new terminal, then:  EXEC_DRYRUN=1 claude-mimo"
echo
echo "Docs: $CLAUDE/docs/4tier-workflow.md"
