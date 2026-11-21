# Dotfile repo

Contains my profiles for installing and configuring Linux & Mac instances.  
Based on this series of blog posts: <https://haseebmajid.dev/posts/2022-10-15-how-to-manage-your-dotfiles-with-dotbot/>

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

## Usage
`make install profile="<profile from meta/profiles>"`

### Mac profiles
Install brew before running dotbot:  
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

If you get a permissions error try this:

```
sudo chown -R $(whoami) $(brew --prefix)/*
/usr/local/bin/brew update --force --quiet
brew doctor
```

`gcloud` is installed as part of Brewfile, but it is not initialised. To do this, ensure you have already authenticated with your GCP account and execute `gcloud init`. The installation is minimal, use `gcloud components list` to see what components are installed.

### Ubuntu Coder
Use this one for the Linux VM spun up by Coder: `make install profile="ubuntu-coder"`  

Installs: the basics using `apt`, Homebrew and sets the default shell to `zsh`. Once complete log out and back in again and then: `brew bundle -v`

Tmux is also installed and configured. ESC is the prefix key. Copy and paste between local tmux and VM tmux is enabled as long as iterm2 is used AND local tmux `set-clipboard` is set to on.

## TODO

- https://haseebmajid.dev/posts/2022-12-15-how-to-use-dotbot-to-personalise-your-vscode-devcontainers/