#!/usr/bin/env bash
#
# zsh-configure.sh [--target lite|fullfat] [--prompt basic|omp]
#                  [--features <a,b,...>] [--list]
#
# Records this machine's zsh options in home/.chezmoidata.toml (machine-keyed)
# and applies them. Intended to be run by the agent, which should WALK THE USER
# THROUGH the choices first (see AGENTS.md) -- recommendations depend on the
# target type. The base zsh config applies everywhere regardless.
#
#   targetType lite    -> constrained/low-power (Raspberry Pi, Crostini):
#                         basic prompt, no heavyweight extras.
#   targetType fullfat -> full dev workstation: oh-my-posh + brew/plugins/...
#
# Features (modules): brew, plugins, gcloud, kubernetes
# Prompt:             basic | omp
#
# With no flags and a terminal it prompts interactively; otherwise it prints the
# current settings.

set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
command -v chezmoi >/dev/null 2>&1 || { printf 'zsh-configure: chezmoi not found\n' >&2; exit 1; }

ALL_FEATURES=(brew plugins gcloud kubernetes)
feature_desc() {
  case "$1" in
    brew)       printf 'Homebrew shellenv integration (needs linuxbrew/macOS Homebrew)' ;;
    plugins)    printf 'antidote + autosuggestions/fast-syntax-highlighting (heavy; needs brew)' ;;
    gcloud)     printf 'Google Cloud SDK path + completion' ;;
    kubernetes) printf 'kubectl/krew aliases + k9s/kubectx' ;;
    *)          printf '%s' "$1" ;;
  esac
}

tpl() { chezmoi execute-template "$1"; }

machine="$(tpl '{{ .machine }}')"
default_target="$(tpl '{{ .defaultTargetType }}')"
current_target="$(tpl '{{ with index .machines .machine }}{{ .targetType }}{{ end }}')"
current_prompt="$(tpl '{{ with index .machines .machine }}{{ .zsh.prompt }}{{ end }}')"
current_features="$(tpl '{{ with index .machines .machine }}{{ .zsh.features | join "," }}{{ end }}')"
[[ -n $current_target ]] || current_target="$default_target"

target=""; prompt=""; features=""
p_target=0; p_prompt=0; p_features=0; interactive=0
while (($#)); do
  case "$1" in
    --target)   target="${2:-}"; p_target=1; shift 2 ;;
    --prompt)   prompt="${2:-}"; p_prompt=1; shift 2 ;;
    --features) features="${2:-}"; p_features=1; shift 2 ;;
    --list)     printf 'target: %s (default %s)\n' "$current_target" "$default_target"
                printf 'prompt: basic|omp\nfeatures: %s\n' "$(IFS=,; printf '%s' "${ALL_FEATURES[*]}")"; exit 0 ;;
    -h|--help)  sed -n '2,24p' "$0"; exit 0 ;;
    -*) printf 'zsh-configure: unknown option %s\n' "$1" >&2; exit 2 ;;
    *)  machine_arg="$1"; shift ;;
  esac
done

if [[ -n ${machine_arg:-} && ${machine_arg} != "$machine" ]]; then
  printf 'zsh-configure: this is %s, not %s (machine is derived from the hostname)\n' "$machine" "$machine_arg" >&2
  exit 2
fi

recommend_features() { if [[ "$1" == fullfat ]]; then printf 'brew,plugins,gcloud,kubernetes'; fi; }
recommend_prompt()   { if [[ "$1" == fullfat ]]; then printf 'omp'; else printf 'basic'; fi; }

# Interactive only when nothing was provided and we have a terminal; otherwise
# report the current settings and exit.
if ((!p_target)) && [[ -z $target && $p_prompt == 0 && $p_features == 0 ]]; then
  if [[ -t 0 ]]; then
    interactive=1
  else
    printf 'zsh-configure: %s target=%s prompt=%s features=[%s]\n' \
      "$machine" "$current_target" "${current_prompt:-basic}" "$current_features"
    printf 'Run with --target/--prompt/--features (or interactively) to change.\n'
    exit 0
  fi
fi
[[ -n $target ]] || target="${current_target:-$default_target}"

if ((interactive)); then
  printf '\nMachine: %s\n' "$machine"
  printf 'Target type:\n'
  printf '  lite    - constrained/low-power (Raspberry Pi, Crostini): basic prompt,\n'
  printf '            no heavyweight extras.\n'
  printf '  fullfat - full dev workstation: oh-my-posh + brew/plugins/gcloud/k8s.\n\n'
  read -r -p "Target type [lite/fullfat] (default ${target}): " _t
  [[ -n $_t ]] || _t="$target"; target="$_t"
fi
[[ "$target" == lite || "$target" == fullfat ]] || { printf 'zsh-configure: target must be lite|fullfat\n' >&2; exit 2; }

rec_feat="$(recommend_features "$target")"
rec_prompt="$(recommend_prompt "$target")"
def_feat="${current_features:-$rec_feat}"
def_prompt="${current_prompt:-$rec_prompt}"

if ((interactive)); then
  printf '\nOptional modules (current default: %s):\n' "${def_feat:-none}"
  selected=()
  for f in "${ALL_FEATURES[@]}"; do
    default_no=1; [[ ",$def_feat," == *",$f,"* ]] && default_no=0
    [[ $default_no == 0 ]] && suffix=" [Y/n]" || suffix=" [y/N]"
    read -r -p "  Enable ${f}${suffix}? $(feature_desc "$f"): " ans
    if [[ $default_no == 0 ]]; then
      [[ $ans =~ ^[Nn]$ ]] || selected+=("$f")
    else
      [[ $ans =~ ^[Yy]$ ]] && selected+=("$f")
    fi
  done
  features="$(IFS=,; printf '%s' "${selected[*]:-}")"; p_features=1
  read -r -p "Prompt [basic/omp] (default ${def_prompt}): " _p
  [[ -n $_p ]] || _p="$def_prompt"; prompt="$_p"; p_prompt=1
fi

((p_prompt))   || prompt="$def_prompt"
((p_features)) || features="$def_feat"

[[ "$prompt" == basic || "$prompt" == omp ]] || { printf 'zsh-configure: prompt must be basic|omp\n' >&2; exit 2; }
if [[ -n $features ]]; then
  IFS=',' read -ra _fa <<< "$features"
  for f in "${_fa[@]}"; do
    [[ -n $f ]] || continue
    printf '%s\n' "${ALL_FEATURES[@]}" | grep -qxF "$f" \
      || { printf 'zsh-configure: unknown feature %s (allowed: %s)\n' "$f" "$(IFS=,; printf '%s' "${ALL_FEATURES[*]}")" >&2; exit 2; }
  done
fi

# Advisory: the omp prompt and plugins module need tools that may not be
# installed yet. They come from Homebrew OR a standalone install (no brew
# required) via `scripts/install-extras.sh --with prompt`.
missing=""
if [[ $prompt == omp ]]; then
  command -v oh-my-posh >/dev/null 2>&1 || [[ -x $HOME/.local/bin/oh-my-posh ]] || missing+="oh-my-posh "
fi
if [[ ",$features," == *",plugins,"* ]]; then
  if [[ ! -f "$HOME/.antidote/antidote.zsh" ]] \
     && ! { command -v brew >/dev/null 2>&1 && [[ -f "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh" ]]; }; then
    missing+="antidote "
  fi
fi
if [[ -n $missing ]]; then
  printf '\nNOTE: %snot installed yet. Install the prompt tooling (no Homebrew needed) with:\n' "$missing" >&2
  printf '  scripts/install-extras.sh %s --with prompt\n' "$machine" >&2
  if ((interactive)); then
    read -r -p "Continue anyway? [Y/n] " _ok
    [[ $_ok =~ ^[Nn]$ ]] && { printf 'zsh-configure: aborted\n' >&2; exit 1; }
  fi
fi

# Build the TOML block.
feature_toml=""
if [[ -n $features ]]; then
  IFS=',' read -ra fa <<< "$features"
  for f in "${fa[@]}"; do
    [[ -n $f ]] || continue
    feature_toml+="${feature_toml:+, }\"${f}\""
  done
fi
block="[machines.${machine}]
targetType = \"${target}\"

[machines.${machine}.zsh]
prompt = \"${prompt}\"
features = [${feature_toml}]
"

source_dir="$(chezmoi source-path)"
data_file="${source_dir}/.chezmoidata.toml"
[[ -f $data_file ]] || : > "$data_file"

tmp="$(mktemp)"
if grep -qE "^\[machines\.${machine}([.]|\])" "$data_file"; then
  awk -v m="$machine" -v block="$block" '
    /^\[machines\./ {
      if ($0 ~ ("^\\[machines\\." m "([.]|\\])")) { if (!printed) { print block; printed=1 }; inblk=1; next }
      else { inblk=0 }
    }
    !inblk { print }
  ' "$data_file" > "$tmp"
else
  cp "$data_file" "$tmp"
  printf '\n%s\n' "$block" >> "$tmp"
fi
mv "$tmp" "$data_file"

printf '\n==> Updated %s for %s (target=%s, prompt=%s, features=[%s])\n' \
  "${data_file/#$HOME/~}" "$machine" "$target" "$prompt" "$features"
printf '==> Applying changes (chezmoi apply)...\n'
chezmoi apply
printf '==> Done. Open a new shell or run: source ~/.zshrc\n'
