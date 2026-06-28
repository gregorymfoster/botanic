#!/usr/bin/env bash
#
# Botanic's local verify gate — the single command to answer "is it safe to commit / release?".
# There is no cloud CI; this script is the gate. Run it before committing and before releasing.
#
# Usage:
#   scripts/check.sh            Full gate: package tests → xcodegen → simulator build (+ lint if installed)
#   scripts/check.sh --fast     Inner loop: package tests only (fast; used by the pre-commit hook)
#   scripts/check.sh --release  Full gate + a clean build (used before tagging a release)
#
# Exits non-zero on the first failing step.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MODE="full"
case "${1:-}" in
  --fast) MODE="fast" ;;
  --release) MODE="release" ;;
  "" ) MODE="full" ;;
  *) echo "Unknown option: $1"; echo "Usage: scripts/check.sh [--fast|--release]"; exit 2 ;;
esac

# --- pretty output -----------------------------------------------------------
bold() { printf '\033[1m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
red() { printf '\033[31m%s\033[0m\n' "$1"; }
step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }

fail() { red "✗ $1"; exit 1; }

# --- 1. package tests (always) ----------------------------------------------
step "Package tests — swift test --package-path BotanicKit"
swift test --package-path BotanicKit || fail "BotanicKit tests failed"
green "✓ package tests passed"

if [ "$MODE" = "fast" ]; then
  bold "Fast check passed (package tests only)."
  exit 0
fi

# --- 2. regenerate the Xcode project ----------------------------------------
# Botanic.xcodeproj is gitignored and regenerated from project.yml, so this must run before any build.
step "Generate project — xcodegen generate"
command -v xcodegen >/dev/null 2>&1 || fail "xcodegen not found (brew install xcodegen)"
xcodegen generate >/dev/null || fail "xcodegen generate failed"
green "✓ project generated"

# --- 3. build the app -------------------------------------------------------
BUILD_ACTION="build"
[ "$MODE" = "release" ] && BUILD_ACTION="clean build"
step "Build app — xcodebuild $BUILD_ACTION (iOS Simulator)"
BUILD_LOG="$(mktemp -t botanic-build.XXXXXX.log)"
trap 'rm -f "$BUILD_LOG"' EXIT
# Build once; tee full output to a log, surface only errors/warnings/result on screen.
set +e
xcodebuild -project Botanic.xcodeproj -scheme Botanic \
  -destination 'generic/platform=iOS Simulator' $BUILD_ACTION 2>&1 | tee "$BUILD_LOG" \
  | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" || true
BUILD_STATUS=${PIPESTATUS[0]}
set -e
if [ "$BUILD_STATUS" -ne 0 ]; then
  red "  see full output: $BUILD_LOG"
  trap - EXIT  # keep the log around for debugging on failure
  fail "app build failed"
fi
green "✓ app built"

# --- 4. lint / format (optional, only if installed) -------------------------
if command -v swiftlint >/dev/null 2>&1 && [ -f .swiftlint.yml ]; then
  step "Lint — swiftlint"
  swiftlint --quiet || fail "swiftlint reported violations"
  green "✓ lint clean"
else
  printf '\n  (swiftlint not configured — skipping)\n'
fi

printf '\n'
green "✓ All checks passed — safe to commit/release."
