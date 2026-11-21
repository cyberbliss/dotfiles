#!/usr/bin/env bash
#
# prereqs.sh - the first thing to run after cloning this repo.
#
# Only `git` is assumed. This installs OpenCode, puts it on PATH (now and for
# future shells), and prints getting-started instructions focused on using an
# OpenRouter API key. Everything after this is driven by the agent described in
# AGENTS.md.
#
# Usage: scripts/prereqs.sh [--launch]
#   --launch   start OpenCode once setup finishes (interactive terminal only)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCODE_DIR="${HOME}/.opencode"
OPENCODE_BIN="${OPENCODE_DIR}/bin"
MARK_BEGIN="# >>> opencode prereqs >>>"
MARK_END="# <<< opencode prereqs <<<"
LAUNCH=0

for arg in "$@"; do
  case "$arg" in
    --launch) LAUNCH=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) printf 'prereqs: unknown option %s\n' "$arg" >&2; exit 2 ;;
  esac
done

log() { printf '==> %s\n' "$*"; }
die() { printf 'prereqs: %s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Linux|Darwin) ;;
  *) die "unsupported OS '$(uname -s)'; install OpenCode from https://opencode.ai/docs/" ;;
esac

# 1. curl is needed by the OpenCode installer.
if ! command -v curl >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing curl + ca-certificates (needed to fetch OpenCode)"
    sudo apt-get update -qq
    sudo apt-get install -y -qq curl ca-certificates
  else
    die "curl is required; install it, then re-run"
  fi
fi

# 2. Install OpenCode into ~/.opencode/bin (official installer).
if [[ -x "${OPENCODE_BIN}/opencode" ]]; then
  log "OpenCode already installed at ${OPENCODE_BIN}/opencode"
else
  log "Installing OpenCode into ${OPENCODE_BIN}"
  curl -fsSL https://opencode.ai/v2/install | bash
fi
[[ -x "${OPENCODE_BIN}/opencode" ]] || die "opencode not found at ${OPENCODE_BIN}/opencode after install"

# 3. Put ~/.opencode/bin on PATH, now and for future shells. Idempotent: a
#    marked block is appended once to each startup file that exists.
add_block() {
  local rc="$1"
  [[ -e "$rc" ]] || return 0
  if grep -qF "$MARK_BEGIN" "$rc" 2>/dev/null; then
    return 0
  fi
  {
    printf '\n%s\n' "$MARK_BEGIN"
    # $HOME and $PATH are intentional literals written into the rc file.
    # shellcheck disable=SC2016
    printf '%s\n' 'export PATH="$HOME/.opencode/bin:$PATH"'
    printf '%s\n' "$MARK_END"
  } >> "$rc"
  log "Added OpenCode to PATH in ${rc/#$HOME/~}"
}

[[ -e "${HOME}/.profile" ]] || : > "${HOME}/.profile"
add_block "${HOME}/.profile"
add_block "${HOME}/.bashrc"
add_block "${HOME}/.zshrc"

export PATH="${OPENCODE_BIN}:${PATH}"

# 4. Report and print getting-started instructions.
log "OpenCode installed: ${OPENCODE_BIN}/opencode"

cat <<EOF

OpenCode is ready. Getting started with an OpenRouter API key:

  1. Load OpenCode into this shell (or just open a new terminal):
       export PATH="\$HOME/.opencode/bin:\$PATH"

  2. Create an OpenRouter API key:
       https://openrouter.ai/keys

  3. Point OpenCode at OpenRouter -- pick one:
     a) TUI (recommended):
          opencode
        then:  /connect   -> choose "OpenRouter" -> paste the key
               /models    -> choose a model, e.g. openrouter/anthropic/claude-sonnet-5.5
     b) CLI (saves the key as an account):
          opencode auth login openrouter --method key
     c) Environment (on the shared background service):
          opencode service set env OPENROUTER_API_KEY sk-or-...
        (one-off instead: OPENROUTER_API_KEY=sk-or-... opencode --standalone)

  4. Start the agent in this repo:
       cd ${REPO_ROOT} && opencode
     It follows AGENTS.md: chezmoi apply, ask which optional stacks you want,
     then run scripts/doctor.sh.

  Check anytime:  opencode auth list   |   opencode --version
EOF

if ((LAUNCH)); then
  if [[ -t 0 && -t 1 ]]; then
    log "Launching OpenCode..."
    exec "${OPENCODE_BIN}/opencode"
  fi
  printf 'prereqs: --launch ignored (no interactive terminal)\n' >&2
fi
