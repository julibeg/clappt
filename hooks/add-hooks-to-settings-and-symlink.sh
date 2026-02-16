#!/usr/bin/env bash
# Replaces the "hooks" field in ~/.claude/settings.json with the one from hooks.settings.json

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SETTINGS="$HOME/.claude/settings.json"
HOOKS_SOURCE="$SCRIPT_DIR/hooks.settings.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "Error: $SETTINGS not found" >&2
  exit 1
fi

if [[ ! -f "$HOOKS_SOURCE" ]]; then
  echo "Error: $HOOKS_SOURCE not found" >&2
  exit 1
fi

# Use jq to replace the hooks field
jq --argjson hooks "$(jq '.hooks' "$HOOKS_SOURCE")" '.hooks = $hooks' "$SETTINGS" \
  > "$SETTINGS.tmp"

mv "$SETTINGS.tmp" "$SETTINGS"

# symlink this dir to ~/.claude/hooks (using a relative path so that in `clappt` we
# don't have to expose the actual host path when binding to the container)
RELATIVE_SCRIPT_DIR="$(realpath --relative-to="$HOME/.claude" "$SCRIPT_DIR")"

pushd ~/.claude
ln -sf "$RELATIVE_SCRIPT_DIR" .
popd

echo -n "Updated hooks in '$SETTINGS' and symlinked '$SCRIPT_DIR' to '~/.claude/hooks' "
echo "(using the relative path '$RELATIVE_SCRIPT_DIR')"
