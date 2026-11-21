# Dotfiles

Agent-driven machine setup: this repo configures a machine end-to-end with
**chezmoi**. You clone it, install OpenCode, open OpenCode **in the repo**, and
ask it to configure your machine — the `configure-machine` skill
(`.opencode/skills/configure-machine/`) is the entry point, and `AGENTS.md` is
the agent's rulebook.

## Getting started

`git` is the only prerequisite.

```bash
git clone https://github.com/cyberbliss/dotfiles.git ~/dev_work/dotfiles
~/dev_work/dotfiles/scripts/prereqs.sh     # installs OpenCode + prints OpenRouter setup
cd ~/dev_work/dotfiles && opencode
```

Then just ask the agent, e.g.:

> help me configure my laptop

The agent will: identify the machine, run `scripts/bootstrap.sh` (installs
chezmoi/mise + base tools), `chezmoi apply` (managed config + baseline packages),
ask which **optional stacks** you want, walk you through the **zsh options**,
and run `scripts/doctor.sh` until it passes. You can also invoke the skill
explicitly with `@configure-machine`.

## OpenCode setup (reference)

OpenCode is the agent that drives this repo; configure it once with an
OpenRouter API key.

```bash
# Install (scripts/prereqs.sh does this for you)
curl -fsSL https://opencode.ai/v2/install | bash     # Linux
brew install anomalyco/tap/opencode-v2               # macOS
export PATH="$HOME/.opencode/bin:$PATH"              # if not already on PATH
```

1. Create an OpenRouter key: <https://openrouter.ai/keys>
2. Connect it (pick one):

```bash
opencode                                        # TUI: /connect -> OpenRouter, then /models
opencode auth login openrouter --method key     # CLI: save the key as an account
opencode service set env OPENROUTER_API_KEY sk-or-...   # shared background service
```

Then choose a model, e.g. `openrouter/anthropic/claude-sonnet-5.5`. Other
installers (npm, bun, pnpm, mise) are listed at <https://opencode.ai/docs/>.

## What the agent uses

| Script | Purpose |
|---|---|
| `scripts/bootstrap.sh` | Installs chezmoi/mise + base tools, clones if needed, `chezmoi init`. |
| `scripts/install-extras.sh` | Optional stacks: `gcloud`, `docker`, `mise`, `prompt`. |
| `scripts/zsh-configure.sh` | Records the machine's zsh target type + modules. |
| `scripts/doctor.sh <machine>` | Verification (non-zero exit on failure). |
| `scripts/render-matrix.sh` | Proves the per-machine template paths render. |

Configuration is managed from **`home/`** (edit sources there, never `$HOME` —
chezmoi owns those files). Per-machine facts live in `machines/<name>.md`;
per-machine zsh choices in `home/.chezmoidata.toml`.

## Manual / reference (optional)

The same steps by hand, if you prefer. `make` targets are thin wrappers over the
scripts above:

```bash
make apply                       # chezmoi apply: config + baseline packages
make doctor machine=chromebook   # verify a machine
make extras                      # list optional stacks
make zsh                         # walk through zsh target type + modules
make render-matrix               # prove per-machine template rendering
```

## Zsh configuration

Every machine gets `home/.chezmoitemplates/zsh-base` (history, completion,
aliases, colours). On top of that a **target type** picks sensible defaults and
optional **modules** are toggled per machine:

- `lite` (Raspberry Pi, Crostini) → basic git prompt; no heavyweight extras.
- `fullfat` (dev workstation) → oh-my-posh prompt + `brew`, `plugins`, `gcloud`,
  `kubernetes`.

Choices live in `home/.chezmoidata.toml` (machine-keyed) and the agent walks you
through them with `scripts/zsh-configure.sh`:

```bash
scripts/zsh-configure.sh chromebook            # interactive walkthrough
scripts/zsh-configure.sh --prompt omp --features plugins
```

The `omp` prompt and `plugins` module work with **or without** Homebrew: on a
non-brew machine (e.g. arm64 Crostini) install the tooling with
`scripts/install-extras.sh <machine> --with prompt`.

## Machines

- `machines/chromebook.md` — ChromeOS Crostini: Debian 13 (trixie), arm64, apt;
  oh-my-posh prompt + plugins (Nerd Font rendered in a Crostini GUI terminal).
- `machines/mint.md` — Linux Mint 22 (Ubuntu 24.04 / `noble`), amd64, linuxbrew.

## Homebrew machines

macOS, and Linuxbrew on amd64 Linux, install their tools from `Brewfile` /
`Brewfile-ubuntu` via `home/run_onchange_install-brew.sh.tmpl`. Install Homebrew
first if it is missing:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

`gcloud` comes from the `gcloud` optional stack; afterwards run `gcloud init`.
