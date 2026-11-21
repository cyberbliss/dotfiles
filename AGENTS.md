# AGENTS.md

Operating rules for the agent that drives this repo. The repo configures a
machine end-to-end with **chezmoi**: the user clones it, installs OpenCode
(`scripts/prereqs.sh`), opens OpenCode **in the repo**, and asks something like
*"help me configure my laptop"*. The `configure-machine` skill
(`.opencode/skills/configure-machine/SKILL.md`) is the entry point; **this file
is the rulebook that skill follows** and the single source of truth for the
procedure.

## Repo map

| Path | Purpose |
|---|---|
| `machines/<name>.md` | Per-machine intent and quirks. **Read this first.** |
| `home/` | chezmoi source directory. All managed config lives here. |
| `.chezmoiroot` | Points chezmoi at `home/` as the source root. |
| `home/.chezmoi.toml.tmpl` | Generates `~/.config/chezmoi/chezmoi.toml`; maps **hostname → machine** and sets `brew`, `defaultTargetType`. |
| `home/.chezmoidata.toml` | Per-machine zsh options (machine-keyed): `targetType`, prompt, modules. |
| `home/.chezmoitemplates/` | Shared zsh base + prompt/module partials. |
| `packages/` | Package lists: `common.txt`, `debian.txt` (baseline), `mise.txt` (optional runtimes). |
| `.opencode/skills/` | The `configure-machine` skill (the "just ask the agent" entry point). |
| `scripts/prereqs.sh` | **User** runs first: installs OpenCode + PATH + OpenRouter guidance. |
| `scripts/bootstrap.sh` | Fresh-machine bootstrap (base tools → chezmoi/mise → `chezmoi init`). |
| `scripts/install-extras.sh` | Optional stacks (gcloud/docker/mise/prompt); the agent asks first. |
| `scripts/zsh-configure.sh` | Records this machine's zsh target type + modules (agent walks the user). |
| `scripts/doctor.sh <machine>` | Verification. Non-zero exit on any failure. |
| `scripts/render-matrix.sh` | Proves the OS/arch/machine template paths render. |
| `Makefile` | Optional human convenience wrappers over `scripts/*` (not used by the agent). |

## Golden rules

1. **Read the machine file first.** Resolve the machine name (see *Machine
   discovery*), open `machines/<name>.md`, then detect arch/OS/shell/sudo.
2. **Edit sources, never `~` directly.** Configuration is managed with chezmoi
   (source root `home/`, wired via `.chezmoiroot`); make changes under `home/`
   and run `chezmoi apply`. If `~/.config/chezmoi/chezmoi.toml` is missing, run
   `chezmoi init --source "$PWD"` first.
3. **Show privileged/destructive commands before running them** — `sudo`, `rm`,
   `chsh`, package removals, anything that rewrites system state.
4. **Never commit secrets** (tokens, keys, credentials). Record required manual
   auth steps in the machine file instead.
5. **Verify, don't assume.** Run `scripts/doctor.sh <machine>` and keep fixing
   until it exits 0.
6. **Record workarounds.** Any non-obvious fix goes under "Quirks" in the machine file.
7. **Commit after each step** on the current branch. Normal work happens on
   `main`; `agent-harness` was a one-time migration branch and may be stale.

## Configure a machine (the main task)

1. **Identify the machine** — detect `hostname`, OS + distro codename, arch,
   login shell, and sudo; resolve the machine name (see *Machine discovery*).
2. **Toolchain + config** — run `scripts/bootstrap.sh`, then
   `chezmoi init --source "$PWD"` if `~/.config/chezmoi/chezmoi.toml` is missing.
   (`bootstrap.sh` installs the base tools and `chezmoi`/`mise`, and is safe to
   re-run. The user has already run `scripts/prereqs.sh` to install OpenCode.)
3. **`chezmoi apply`** — installs the **baseline** packages from `packages/*.txt`
   (via the `run_onchange_` scripts) and the managed config for this machine.
4. **Ask** which optional stacks the user wants (`scripts/install-extras.sh
   --list`: `gcloud`, `docker`, `mise`, `prompt`), then apply their choices with
   `scripts/install-extras.sh <name> --with <stack,...>`.
5. **Walk the user through the zsh options** with `scripts/zsh-configure.sh
   <name>` (target type `lite` vs `fullfat`, prompt, modules; see the "zsh"
   notes in the machine file). The shared base applies regardless. `omp` and
   `plugins` work with or without Homebrew — the prompt tooling can come from
   `scripts/install-extras.sh <name> --with prompt` (no brew required).
6. Run `scripts/doctor.sh <name>`; fix and repeat until it exits 0.
7. Summarise changes and list manual steps (gcloud/gh/ssh auth).

## Machine discovery

The machine name is derived from the hostname by the map in
`home/.chezmoi.toml.tmpl`:

```
"penguin" -> "chromebook"   # ChromeOS Crostini
"steve"   -> "mint"         # Linux Mint laptop
```

- **Known hostname:** `machine` is set; read `machines/<machine>.md` and go.
- **Unknown hostname:** `machine` resolves to `unknown` and there is **no**
  `machines/unknown.md` — treat this as a new machine:
  1. Agree a short, lowercase machine name with the user (e.g. derive from the
     hostname).
  2. Add the `hostname -> name` entry to the map in `home/.chezmoi.toml.tmpl`
     (also set `brew` and the `defaultTargetType` for that class of machine).
  3. Create `machines/<name>.md` modelled on `machines/chromebook.md`: intent,
     identity, verified environment facts, package strategy, quirks, and a
     ```doctor``` block (start with `require_os`/`require_arch`/`require_cmd`
     checks; promote `warn_*` to `require_*` as things land).
  4. Re-run `chezmoi init --source "$PWD"` so `~/.config/chezmoi/chezmoi.toml`
     picks up the new machine, then continue with *Configure a machine*.

## Platforms

- **Linux (Debian / Ubuntu / Mint / ChromeOS Crostini):** `apt` + `mise`. No
  Homebrew on arm64 Linux; on amd64, linuxbrew is optional. Derive the apt
  codename/arch dynamically and prefer `UBUNTU_CODENAME` on Mint.
- **macOS (darwin):** Homebrew via `Brewfile`.

## Conventions

- Shell scripts: `#!/usr/bin/env bash`, `set -euo pipefail`, shellcheck-clean.
- Keep everything idempotent: re-running an install/apply must be a no-op.
- Prefer chezmoi templates (`.chezmoi.os`, `.chezmoi.arch`, machine data) over
  duplicated files; gate platform-specific targets with `home/.chezmoiignore`.
