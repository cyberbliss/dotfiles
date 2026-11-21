---
name: Configure machine
description: Set up or configure this laptop, desktop, or server from the dotfiles repo — install the toolchain, apply the chezmoi config, choose optional packages and zsh options, then verify with doctor. Use when the user asks to configure, set up, bootstrap, prepare, or "get started" with their machine.
---

# Configure a machine

This repo configures a machine end-to-end with chezmoi and is driven by you (the
agent). `AGENTS.md` in the repo root is the canonical rulebook — read it and
follow it. This skill is the entry point for a request like "help me configure
my laptop".

## Workflow

1. **Read `AGENTS.md`** and follow its Golden rules: edit sources under `home/`,
   never `~` directly; show privileged/destructive commands before running them;
   never commit secrets.
2. **Identify the machine.** Detect `hostname`, OS + distro codename, arch,
   login shell, and whether sudo is passwordless. Resolve the machine name from
   the hostname map in `home/.chezmoi.toml.tmpl`.
   If the hostname is **not** mapped (the machine resolves to `unknown`), agree a
   short machine name with the user, add the `hostname -> name` mapping, and
   create `machines/<name>.md` modelled on `machines/chromebook.md`. See
   "Machine discovery" in `AGENTS.md`.
3. **Ensure the toolchain + chezmoi config exist.** Run `scripts/bootstrap.sh`
   (installs chezmoi/mise and base tools; safe to re-run), then
   `chezmoi init --source "$PWD"` if `~/.config/chezmoi/chezmoi.toml` is missing.
4. **Apply.** `chezmoi apply` — installs the baseline packages (`packages/*.txt`)
   and the managed config for this machine.
5. **Ask about optional stacks.** List them with `scripts/install-extras.sh
   --list` (`gcloud`, `docker`, `mise`, `prompt`), then apply the user's choices
   with `scripts/install-extras.sh <machine> --with <stack,...>`.
6. **Walk through the zsh options.** Run `scripts/zsh-configure.sh <machine>`
   (target type `lite` vs `fullfat`, prompt, modules). Offer the non-brew prompt
   tooling (`--with prompt`) when oh-my-posh/plugins are wanted without Homebrew.
7. **Verify.** Run `scripts/doctor.sh <machine>` until it exits 0. Fix problems,
   record any non-obvious fix under "Quirks" in the machine file, and repeat.
8. **Summarise** what changed and list the manual steps that need secrets or a
   browser (`gh auth login`, `gcloud init`, SSH keys).

## Supporting files

- `AGENTS.md` — canonical rules and the fuller procedure.
- `machines/chromebook.md` — reference machine file (intent, facts, doctor block).
- `scripts/bootstrap.sh`, `scripts/install-extras.sh`, `scripts/zsh-configure.sh`,
  `scripts/doctor.sh`, `scripts/render-matrix.sh`.
