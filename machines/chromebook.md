# Machine: chromebook

## Intent
Primary personal dev machine: a Chromebook running the Crostini Linux container.
Goal is a deterministic, agent-bootstrapped setup: clone → install → `chezmoi apply`
→ `doctor.sh` passes, with no hand-editing of files in `$HOME`.

## Identity
- Machine name: `chromebook` (hostname `penguin`)
- User: `steve`
- Legacy Dotbot profile this maps to: `ubuntu` (`zsh-simple` + apt)

## Verified environment facts
Last verified: 2026-11-21 on branch `agent-harness`.

| Fact | Value | How verified |
|---|---|---|
| OS | Debian GNU/Linux 13 (trixie) | `/etc/os-release` |
| Kernel arch | `aarch64` | `uname -m` |
| Package arch | `arm64` | `dpkg --print-architecture` |
| Environment | ChromeOS Crostini container "penguin" | `/mnt/chromeos` present |
| Login shell | `/bin/bash` (zsh not yet installed) | `getent passwd` |
| sudo | passwordless (`sudo -n` succeeds) | `sudo -n true` |
| Homebrew | not installed; **no official ARM Linux support** | upstream policy |
| gcloud | not installed; available via Google apt repo (arm64) | apt repo |

## Package strategy
- System packages: `apt` (lists in `packages/`).
- Language runtimes: `mise` (`~/.local/bin/mise`).
- **Do not use Homebrew on this machine** — no ARM Linux support. `Brewfile` is for macOS only.
- Derive the apt codename dynamically (`$VERSION_CODENAME`) and arch
  (`dpkg --print-architecture`); do not hardcode `bookworm`/`arm64`.

## Quirks
- **Clipboard / OSC 52:** the ChromeOS Terminal supports OSC 52, but the current
  `tmux-ubuntu.conf` has no `set-clipboard on` (only commented-out `xsel` bindings).
  Set `set -g set-clipboard on` so copy/paste works without X11 tooling.
- **chsh requires a container restart:** after `sudo chsh -s $(which zsh)`,
  the Linux container (not just the shell) must be restarted for it to take effect.
- **gcloud:** install from Google's apt repo (has arm64); after install run the
  manual `gcloud init` step.
- **PATH:** `~/.local/bin` (chezmoi, mise) is added by `~/.profile` for login
  shells only. Non-login agent shells must reference these by absolute path.
- **No X11 display server:** terminal-only tooling; avoid GUI/clipboard utilities
  that assume X.

## Manual steps after bootstrap (cannot be automated / require secrets)
- `gh auth login` (git credential helper depends on it; `~/.gitconfig` already
  references `/usr/bin/gh`).
- `gcloud init` (GCP auth).
- SSH key generation/authorisation for GitHub.

## Verification
- `scripts/doctor.sh chromebook` must exit 0.
