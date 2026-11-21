# AGENTS.md

Canonical operating rules for any coding agent (Continue, OpenCode, etc.) working
in this dotfiles repo. This is the single source of truth for the agent procedure;
there are no separate agent-specific rule files.

## Repo map

| Path | Purpose |
|---|---|
| `machines/<name>.md` | Per-machine intent and quirks. **Read this first.** |
| `home/` | chezmoi source directory. All managed config lives here. |
| `.chezmoiroot` | Points chezmoi at `home/` as the source root. |
| `home/.chezmoi.toml.tmpl` | Generates `~/.config/chezmoi/chezmoi.toml` (`machine`, `zshVariant`). |
| `packages/` | Package lists per platform (consumed by install scripts). |
| `scripts/bootstrap.sh` | Fresh-machine bootstrap (git → clone → chezmoi/mise → hand off). |
| `scripts/doctor.sh <machine>` | Verification. Non-zero exit on any failure. |
| `meta/` | Legacy Dotbot setup, being removed. **Do not extend it.** |

## Golden rules

1. **Read the machine file first.** Open `machines/<name>.md`, then detect
   arch/OS/shell/sudo before changing anything.
2. **Edit sources, never `~` directly.** Configuration is managed with chezmoi
   (source root `home/`, wired via `.chezmoiroot`); make changes under `home/`
   and run `chezmoi apply` to realise them. If `~/.config/chezmoi/chezmoi.toml`
   is missing, run `chezmoi init --source "$PWD"` first.
3. **Show privileged/destructive commands before running them** — `sudo`, `rm`,
   `chsh`, package removals, anything that rewrites system state.
4. **Never commit secrets** (tokens, keys, credentials). Record required manual
   auth steps in the machine file instead.
5. **Verify, don't assume.** Run `scripts/doctor.sh <machine>` and keep fixing
   until it exits 0.
6. **Record workarounds.** Any non-obvious fix goes under "Quirks" in the machine file.
7. **Commit after each step**, on branch `agent-harness`.

## Procedure

1. Read `machines/<name>.md`; detect arch/OS/shell/sudo.
2. Install packages for that OS (apt + `mise` on Linux; Homebrew on macOS).
3. `chezmoi apply` (edit sources in `home/`, never `~` directly).
4. Run `scripts/doctor.sh <name>`; fix and repeat until it passes.
5. Summarise changes and list manual steps (gcloud/gh/ssh auth).

## Platforms

- **Linux (Debian / ChromeOS Crostini, arm64):** `apt` + `mise`. No Homebrew
  on arm64 Linux. Derive apt codename/arch dynamically.
- **macOS (darwin):** Homebrew via `Brewfile`.

## Conventions

- Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, shellcheck-clean.
- Keep everything idempotent: re-running an install/apply must be a no-op.
- Prefer chezmoi templates (`.chezmoi.os`, `.chezmoi.arch`, machine var) over
  duplicated files; gate platform-specific files with `home/.chezmoiignore`.
