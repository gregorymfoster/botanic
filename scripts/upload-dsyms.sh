#!/usr/bin/env bash
#
# Upload dSYMs for a Botanic archive to Sentry, so crash/error stack traces symbolicate.
#
# Usage:
#   scripts/upload-dsyms.sh [path/to/App.xcarchive]
#
#   If no archive path is given, the newest *.xcarchive under build/ is used.
#
# Requires:
#   - SENTRY_AUTH_TOKEN env var (Sentry auth token with project:write / project:releases scope)
#   - sentry-cli on PATH (brew install getsentry/tools/sentry-cli)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }

fail() { red "✗ $1"; exit 1; }

command -v sentry-cli >/dev/null 2>&1 || fail "sentry-cli not found on PATH — install: brew install getsentry/tools/sentry-cli"
[ -n "${SENTRY_AUTH_TOKEN:-}" ] || fail "SENTRY_AUTH_TOKEN is not set — export a Sentry auth token before running this script."

ARCHIVE="${1:-}"
if [ -z "$ARCHIVE" ]; then
  ARCHIVE="$(find build -maxdepth 2 -name '*.xcarchive' -print0 2>/dev/null \
    | xargs -0 ls -dt 2>/dev/null | head -n1 || true)"
  [ -n "$ARCHIVE" ] || fail "No archive path given and no *.xcarchive found under build/."
fi

[ -d "$ARCHIVE" ] || fail "Archive not found: $ARCHIVE"

bold "Uploading dSYMs from: $ARCHIVE"
sentry-cli debug-files upload --include-sources --org gregorymfoster --project botanic "$ARCHIVE/dSYMs"
green "✓ dSYMs uploaded"
