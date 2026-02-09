#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/matiasvillaverde/think.git"
REPO_URL="${THINK_REPO_URL:-$REPO_URL_DEFAULT}"
REF="${THINK_REF:-main}"

say() { printf "%s\n" "$*"; }
die() { say "Error: $*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

pick_bindir() {
  # Prefer system-wide Homebrew bin dirs if writable; otherwise fall back to ~/.local/bin.
  local candidates=()
  candidates+=("/opt/homebrew/bin")
  candidates+=("/usr/local/bin")
  candidates+=("$HOME/.local/bin")

  for dir in "${candidates[@]}"; do
    if mkdir -p "$dir" >/dev/null 2>&1; then
      if [ -w "$dir" ]; then
        printf "%s" "$dir"
        return 0
      fi
    fi
  done

  # Last resort: current directory.
  printf "%s" "$(pwd)"
}

main() {
  require git
  require make
  require swift

  if ! xcode-select -p >/dev/null 2>&1; then
    die "Xcode Command Line Tools not found. Install with: xcode-select --install"
  fi

  local bindir
  bindir="$(pick_bindir)"

  say "Installing ThinkCLI (think) into: $bindir"
  say "Source: $REPO_URL (ref: $REF)"

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  git clone --depth 1 --branch "$REF" "$REPO_URL" "$tmp" >/dev/null 2>&1 || \
    die "Failed to clone $REPO_URL (ref: $REF)"

  make -C "$tmp/ThinkCLI" install BINDIR="$bindir"

  if [ -x "$bindir/think" ]; then
    "$bindir/think" --help >/dev/null 2>&1 || true
  fi

  if command -v think >/dev/null 2>&1; then
    say "Verified: think is on PATH ($(command -v think))"
    return 0
  fi

  say ""
  say "Installed, but 'think' is not on your PATH."
  say "Add this to your shell profile:"
  say "  export PATH=\"$bindir:\$PATH\""
}

main "$@"
