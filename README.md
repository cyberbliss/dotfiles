# Dotfiles

Managed with **chezmoi** (source in `home/`) and driven by an agent — see
`AGENTS.md` and `machines/<name>.md`. Previously managed with Dotbot, now retired.

## Pre-requisites

An agent (see `AGENTS.md`) drives this repo, so **install OpenCode first** — the
agent skill and automation depend on it:

```bash
# Linux (Debian / ChromeOS Crostini, arm64) — installs to ~/.opencode/bin
curl -fsSL https://opencode.ai/v2/install | bash

# macOS
brew install anomalyco/tap/opencode-v2
```

The curl installer drops the binary in `~/.opencode/bin`, which is **not** on
`PATH` by default (and is not added by `~/.profile`). Add it, or call the binary
by absolute path:

```bash
export PATH="$HOME/.opencode/bin:$PATH"
```

Other installers (npm, bun, pnpm, mise) and standalone binaries are listed at
<https://opencode.ai/docs/>. A working `git` and `curl` are assumed.

## Bootstrap a machine

```bash
git clone https://github.com/cyberbliss/dotfiles.git ~/dev_work/dotfiles
~/dev_work/dotfiles/scripts/bootstrap.sh
```

`bootstrap.sh` installs base tooling plus `chezmoi`/`mise`, then hands off to an
agent. The agent follows `AGENTS.md`: `chezmoi apply` (managed config + baseline
packages), **asks** which optional stacks you want, then runs `doctor.sh`.

## Common tasks

```bash
make apply                       # chezmoi apply: config + baseline packages
make doctor machine=chromebook   # verify a machine (non-zero exit on failure)
make extras                      # list optional stacks (gcloud/docker/mise/prompt)
make render-matrix               # prove per-machine template rendering
```

Edit configuration in `home/`, **never** in `$HOME` — chezmoi owns those files.
For example the shell config lives in `home/.chezmoitemplates/zshrc-<variant>`
(`zshrc-simple` on the chromebook, `zshrc-client` on Homebrew machines).

## Machines

- `machines/chromebook.md` — ChromeOS Crostini: Debian 13 (trixie), arm64,
  `simple` zsh variant, apt only.
- `machines/mint.md` — Linux Mint 22 (Ubuntu 24.04 / `noble`), amd64, `client`
  zsh variant with linuxbrew.

## Homebrew machines

macOS, and Linuxbrew on amd64 Linux, install their tools from `Brewfile` /
`Brewfile-ubuntu` via `home/run_onchange_install-brew.sh.tmpl`. Install Homebrew
first if it is missing:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

`gcloud` comes from the `gcloud` optional stack (`scripts/install-extras.sh`),
which pulls the Google apt repo; afterwards run `gcloud init` to authenticate.
