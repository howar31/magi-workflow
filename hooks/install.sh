#!/usr/bin/env bash
# Install magi-workflow git hooks into a target repo.
# Usage:
#   bash install.sh                     # current repo
#   bash install.sh /path/to/repo

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-$(pwd)}"

if [[ ! -d "$TARGET/.git" ]]; then
  echo "✗ $TARGET is not a git repo (no .git/)" >&2
  exit 1
fi

DEST="$TARGET/.git/hooks"

for hook in commit-msg pre-commit pre-push; do
  src="$HOOKS_DIR/$hook"
  dst="$DEST/$hook"
  if [[ ! -f "$src" ]]; then
    echo "⚠ $hook not found in $HOOKS_DIR; skipping" >&2
    continue
  fi
  if [[ -f "$dst" ]] && ! cmp -s "$src" "$dst"; then
    echo "⚠ $hook already exists at $dst and differs; backing up to ${dst}.bak" >&2
    cp "$dst" "${dst}.bak"
  fi
  install -m 0755 "$src" "$dst"
  echo "✓ installed $hook → $dst"
done

echo
echo "Done. Bypass any time with: MAGI_SKIP_HOOKS=1 git <command>"
