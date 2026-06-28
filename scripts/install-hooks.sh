#!/usr/bin/env bash
#
# Opt-in git hooks for Botanic. Run once to wire local checks into your git workflow:
#
#   scripts/install-hooks.sh
#
#   pre-commit → scripts/check.sh --fast   (package tests; keeps commits quick)
#   pre-push   → scripts/check.sh          (full gate: tests + build)
#
# Hooks live in .git/hooks (not tracked), so installing them is each contributor's choice.
# Bypass a hook for a single command with `git commit --no-verify` / `git push --no-verify`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

[ -d "$REPO_ROOT/.git" ] || { echo "Not a git repository: $REPO_ROOT"; exit 1; }
mkdir -p "$HOOKS_DIR"

write_hook() {
  local name="$1" arg="$2" dest="$HOOKS_DIR/$1"
  if [ -e "$dest" ] && ! grep -q "botanic-managed-hook" "$dest" 2>/dev/null; then
    echo "⚠ $name already exists and isn't managed by this script — leaving it untouched."
    echo "  To use Botanic's hook, remove $dest and re-run this script."
    return
  fi
  cat > "$dest" <<EOF
#!/usr/bin/env bash
# botanic-managed-hook — regenerate with scripts/install-hooks.sh
exec "\$(git rev-parse --show-toplevel)/scripts/check.sh" $arg
EOF
  chmod +x "$dest"
  echo "✓ installed $name → check.sh ${arg:-(full)}"
}

write_hook pre-commit "--fast"
write_hook pre-push ""

echo
echo "Done. Bypass once with --no-verify if you ever need to."
