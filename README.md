# Dotfiles

Managed with **chezmoi** (source in `home/`) and driven by an agent — see
`AGENTS.md` and `machines/<name>.md`. Previously managed with Dotbot, now retired.

## Getting started

`git` is the only prerequisite. Clone, run the prereqs script, then start the
agent:

```bash
git clone https://github.com/cyberbliss/dotfiles.git ~/dev_work/dotfiles
~/dev_work/dotfiles/scripts/prereqs.sh     # installs OpenCode + prints OpenRouter setup
cd ~/dev_work/dotfiles && opencode         # the agent follows AGENTS.md
```

`scripts/prereqs.sh` installs OpenCode into `~/.opencode/bin`, adds it to your
shell PATH (now and for future shells), and prints getting-started instructions.
Everything after that is agent-driven: `chezmoi apply` (managed config + baseline
packages), choose any optional stacks, then `scripts/doctor.sh <machine>`.

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

## Common tasks

```bash
make apply                       # chezmoi apply: config + baseline packages
make doctor machine=chromebook   # verify a machine (non-zero exit on failure)
make extras                      # list optional stacks (gcloud/docker/mise/prompt)
make zsh                         # walk through zsh target type + modules
make render-matrix               # prove per-machine template rendering
```

Edit configuration in `home/`, **never** in `$HOME` — chezmoi owns those files.
The shell config is a shared base plus per-machine prompt/modules; see below.

## Zsh configuration

Every machine gets `home/.chezmoitemplates/zsh-base` (history, completion,
aliases, colours). On top of that a **target type** picks sensible defaults and
optional **modules** are toggled per machine:

- `lite` (Raspberry Pi, Crostini) → basic git prompt; no heavyweight extras.
- `fullfat` (dev workstation) → oh-my-posh prompt + `brew`, `plugins`, `gcloud`,
  `kubernetes`.

Choices live in `home/.chezmoidata.toml` (machine-keyed). The agent walks you
through them with `scripts/zsh-configure.sh`; you can also run it directly:

```bash
make zsh                                   # interactive walkthrough
scripts/zsh-configure.sh --target fullfat --prompt omp \
  --features brew,plugins,gcloud,kubernetes
```

## Machines

- `machines/chromebook.md` — ChromeOS Crostini: Debian 13 (trixie), arm64,
  `lite` (basic prompt), apt only.
- `machines/mint.md` — Linux Mint 22 (Ubuntu 24.04 / `noble`), amd64, `fullfat`
  (linuxbrew + oh-my-posh).

## Homebrew machines

macOS, and Linuxbrew on amd64 Linux, install their tools from `Brewfile` /
`Brewfile-ubuntu` via `home/run_onchange_install-brew.sh.tmpl`. Install Homebrew
first if it is missing:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

`gcloud` comes from the `gcloud` optional stack (`scripts/install-extras.sh`),
which pulls the Google apt repo; afterwards run `gcloud init` to authenticate.
