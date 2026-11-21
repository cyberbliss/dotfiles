# Machine: chromebook

## Intent
Primary personal dev machine: a Chromebook running the Crostini Linux container.
Goal is a deterministic, agent-bootstrapped setup: clone → install → `chezmoi apply`
→ `doctor.sh` passes, with no hand-editing of files in `$HOME`.

## Identity
- Machine name: `chromebook` (hostname `penguin`)
- User: `steve`
- Legacy Dotbot profile this maps to: `ubuntu` (`zsh-simple` + apt)
- Transitional Stage 3 profile: `chromebook` (`git`, `packages.ubuntu-sudo`,
  `zsh-simple`). The `bash` config is intentionally omitted — see Quirks.

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

### Baseline vs optional
- **Baseline** (installed automatically, non-interactive, by
  `home/run_onchange_install-packages.sh.tmpl`): `packages/common.txt` +
  `packages/debian.txt` via apt. All of these are in Debian trixie main, so no
  third-party repo is needed. Idempotent — only missing packages are installed.
- **Optional** (the agent must *ask* before installing; applied by
  `scripts/install-extras.sh`): `gcloud`, `docker`, `mise` runtimes
  (`packages/mise.txt`), and `prompt` (oh-my-posh + antidote). Run as
  `scripts/install-extras.sh chromebook --with <stack,...>`. Re-runnable.
- This machine's zsh variant is `simple`, so it does **not** need antidote /
  oh-my-posh / brew; only offer `prompt` if the user asks.

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
- **Dotbot could not overwrite existing regular files:** the legacy `bash.yaml`
  config linked `~/.profile`, `~/.bashrc`, `~/.bash_logout`, but Crostini ships
  these as regular files. With `force` unset, Dotbot warned and exited non-zero
  (and the legacy installer used `set -e`), aborting the run. The transitional
  `chromebook` profile therefore omitted `bash`; those files stayed as shipped
  until chezmoi took over (now the source of truth).

## Manual steps after bootstrap (cannot be automated / require secrets)
- `gh auth login` (git credential helper depends on it; `~/.gitconfig` already
  references `/usr/bin/gh`).
- `gcloud init` (GCP auth).
- SSH key generation/authorisation for GitHub.

## Doctor checks
Consumed by `scripts/doctor.sh <machine>`. `require_*` lines are gating
(non-zero exit on failure); `warn_*` lines are reported but do not fail the run.
Promote `warn_*` to `require_*` as later stages land.

```doctor
require_os trixie
require_arch arm64
require_cmd git
require_cmd curl
require_cmd gh
require_cmd chezmoi
require_cmd mise
require_cmd shellcheck
require_cmd zsh
require_shell zsh
require_git_identity
require_file ~/.profile
require_file ~/.bashrc
require_file ~/.bash_logout
require_file ~/.gitconfig
require_file ~/.zshrc
require_file ~/.dir_colours
require_cmd tmux
warn_file ~/.tmux.conf
warn_tmux_clipboard ~/.tmux.conf
warn_cmd gcloud
warn_cmd docker
warn_pkg docker-ce
```

## Verification
- `scripts/doctor.sh chromebook` must exit 0.
