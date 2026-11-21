# Machine: mint

## Intent
Second personal dev machine: a Linux Mint 22 laptop currently running the legacy
Dotbot ("original") dotfiles. Target is the same deterministic flow as the
chromebook: clone → install → `chezmoi apply` → `doctor.sh` passes, with no
hand-editing of files in `$HOME`.

## Identity
- Machine name: `mint` (hostname `steve`)
- Legacy Dotbot profile this maps to: `ubuntu-coder` (apt + gcloud + docker +
  `zsh-client` + linuxbrew `Brewfile-ubuntu`)
- zsh target type: `fullfat` (base + oh-my-posh prompt + `brew`, `plugins`,
  `gcloud`, `kubernetes` modules) — see `home/.chezmoidata.toml`
- Homebrew: **linuxbrew** at `/home/linuxbrew/.linuxbrew` (amd64 Linux is
  supported, unlike the chromebook's arm64).

## Verified environment facts
Last verified: **pending** — this machine was not reachable from the agent that
wrote this file; confirm the rows below on the real hardware, then update the
date. Values from the user: Mint 22, Ubuntu 24.04 base, amd64.

| Fact | Expected value | How to verify |
|---|---|---|
| OS | Linux Mint 22 (Ubuntu 24.04 base) | `cat /etc/os-release` |
| Ubuntu codename | `noble` | `UBUNTU_CODENAME` in `/etc/os-release` |
| Mint codename | `wilma` (may appear as `VERSION_CODENAME`) | `cat /etc/os-release` |
| Package arch | `amd64` | `dpkg --print-architecture` |
| Homebrew | linuxbrew present | `/home/linuxbrew/.linuxbrew/bin/brew --version` |
| Login shell | `/bin/zsh` | `getent passwd` |

## Package strategy
- Baseline: `packages/common.txt` + `packages/debian.txt` via apt (same
  `run_onchange_install-packages.sh.tmpl` as every Linux machine).
- Homebrew: `home/run_onchange_install-brew.sh.tmpl` runs `brew bundle` with
  `Brewfile-ubuntu` (selected by `.chezmoi.os`), because `brew = true` for this
  machine (fullfat).
- Optional (agent asks first): `scripts/install-extras.sh mint --with
  gcloud,docker`. The legacy `ubuntu-coder` profile installed both.
- Derive apt codename dynamically; **prefer `UBUNTU_CODENAME`** (see Quirks).

## Quirks
- **Mint codename vs Ubuntu codename:** third-party apt repos (Docker, etc.)
  publish per *Ubuntu* codename, but Linux Mint sets `VERSION_CODENAME` to the
  Mint name (`wilma`). `scripts/install-extras.sh` resolves this via
  `apt_codename()` (prefers `UBUNTU_CODENAME`), and `doctor.sh`'s `os` check
  accepts either `VERSION_CODENAME` or `UBUNTU_CODENAME`.
- **linuxbrew on amd64 Linux only:** supported here; the chromebook (arm64) has
  no Homebrew, which is why the brew module and client assets are gated on the
  `brew` data value rather than on OS alone.
- **Existing Dotbot install:** migrate with `chezmoi apply` after removing the
  old symlinks; keep the machine running until `doctor.sh` passes (rollback is
  re-running the old `make install profile=ubuntu-coder`).

## Manual steps after bootstrap (cannot be automated / require secrets)
- `gh auth login` (git credential helper depends on it).
- `gcloud init` (GCP auth) if the `gcloud` stack is installed.
- SSH key generation/authorisation for GitHub.

## Doctor checks
`require_*` gates (non-zero exit on failure); `warn_*` is reported only.
Promote `warn_*` to `require_*` once the optional stacks land and are verified.

```doctor
require_os noble
require_arch amd64
require_cmd git
require_cmd curl
require_cmd gh
require_cmd chezmoi
require_cmd mise
require_cmd shellcheck
require_cmd zsh
require_shell zsh
require_git_identity
require_cmd brew
require_cmd tmux
require_cmd oh-my-posh
require_file ~/.profile
require_file ~/.gitconfig
require_file ~/.zshrc
require_file ~/.dir_colours
require_file ~/.zsh_plugins.txt
require_file ~/.config/stevejudd-full.omp.json
warn_file ~/.tmux.conf
warn_tmux_clipboard ~/.tmux.conf
warn_cmd gcloud
warn_cmd docker
warn_pkg docker-ce
```

## Verification
- `scripts/doctor.sh mint` must exit 0 **on the laptop** (cannot be run from the
  chromebook; the render matrix in `scripts/render-matrix.sh` proves the mint
  template path renders as intended).
