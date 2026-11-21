#!/usr/bin/env bash
#
# bootstrap.sh - prepare a fresh machine to be configured by an agent.
#
# Installs base tooling, ensures the dotfiles repo is present, installs the
# chezmoi + mise toolchain into ~/.local/bin, then hands off to an agent
# (see AGENTS.md). Idempotent: safe to re-run.
#
# Overrides:
#   DOTFILES_REPO  git URL to clone (default: https://github.com/cyberbliss/dotfiles.git)
#   DOTFILES_DIR   where to clone (default: $HOME/dev_work/dotfiles)

set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/cyberbliss/dotfiles.git}"
REPO_DIR="${DOTFILES_DIR:-$HOME/dev_work/dotfiles}"
LOCAL_BIN="$HOME/.local/bin"

log()  { printf '==> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# 1. Base packages (Debian/apt systems).
if have apt-get; then
  log "Installing base packages (git, curl, ca-certificates)"
  sudo apt-get update -qq
  sudo apt-get install -y -qq git curl ca-certificates
fi

# 2. Ensure the repo is present.
if [[ -f "$REPO_DIR/scripts/bootstrap.sh" ]]; then
  log "dotfiles already present at $REPO_DIR"
else
  log "Cloning dotfiles into $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

# 3. Toolchain into ~/.local/bin (see machines/chromebook.md for PATH note).
mkdir -p "$LOCAL_BIN"
if [[ ! -x "$LOCAL_BIN/chezmoi" ]]; then
  log "Installing chezmoi -> $LOCAL_BIN"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$LOCAL_BIN"
fi
if [[ ! -x "$LOCAL_BIN/mise" ]]; then
  log "Installing mise -> $LOCAL_BIN"
  curl -fsSL https://mise.run | sh
fi
if have apt-get; then
  log "Installing shellcheck and gh"
  sudo apt-get install -y -qq shellcheck gh
fi

log "Toolchain ready."
printf '  repo:    %s\n' "$REPO_DIR"
printf '  chezmoi: %s\n' "$("$LOCAL_BIN/chezmoi" --version | cut -d, -f1)"
printf '  mise:    %s\n' "$("$LOCAL_BIN/mise" --version)"
printf 'Next: open the repo with an agent and follow AGENTS.md.\n'
