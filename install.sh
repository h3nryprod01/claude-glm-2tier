#!/usr/bin/env bash
# Installer for the two-tier Claude(Opus) + GLM workflow.
# Copies files into ~/.claude and puts `claude-glm` on your PATH. Idempotent.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"

echo "Installing into $CLAUDE ..."
mkdir -p "$CLAUDE/scripts" "$CLAUDE/commands" "$CLAUDE/docs" "$HOME/.local/bin"

for f in "$HERE"/claude/scripts/*; do
  install -m 0755 "$f" "$CLAUDE/scripts/$(basename "$f")"
done
cp "$HERE/claude/glm-role.md"    "$CLAUDE/glm-role.md"
cp "$HERE"/claude/commands/*.md  "$CLAUDE/commands/"
cp "$HERE"/claude/docs/*.md      "$CLAUDE/docs/"

# key file: create empty with locked-down perms if absent (never overwrite an existing key)
[ -f "$CLAUDE/.glm-key" ] || : > "$CLAUDE/.glm-key"
chmod 600 "$CLAUDE/.glm-key"

# put claude-glm on PATH via symlink
ln -sf "$CLAUDE/scripts/claude-glm" "$HOME/.local/bin/claude-glm"
ln -sf "$CLAUDE/scripts/glm-job"    "$HOME/.local/bin/glm-job"

echo
echo "✅ Installed."
case ":$PATH:" in
  *":$HOME/.local/bin:"*) : ;;
  *) echo "⚠  Add ~/.local/bin to your PATH, e.g.:  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc" ;;
esac
echo
echo "Next steps:"
echo "  1) Buy a GLM Coding Plan:  https://z.ai/subscribe   (create an API key)"
echo "  2) Paste ONLY the key into: $CLAUDE/.glm-key"
echo "  3) Open a new terminal, then:  claude-glm --version"
echo
echo "Docs: $CLAUDE/docs/2tier-workflow.md"
