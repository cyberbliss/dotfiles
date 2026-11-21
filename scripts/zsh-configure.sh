#!/usr/bin/env bash
#
# zsh-configure.sh [--target lite|fullfat] [--prompt basic|omp]
#                  [--features <a,b,...>] [--list] [--force]
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
brew_data="$(tpl '{{ .brew }}')"
default_target="$(tpl '{{ .defaultTargetType }}')"
current_target="$(tpl '{{ with index .machines .machine }}{{ .targetType }}{{ end }}')"
current_prompt="$(tpl '{{ with index .machines .machine }}{{ .zsh.prompt }}{{ end }}')"
current_features="$(tpl '{{ with index .machines .machine }}{{ .zsh.features | join "," }}{{ end }}')"
[[ -n $current_target ]] || current_target="$default_target"

target=""; prompt=""; features=""; interactive=0; FORCE=0
while (($#)); do
  case "$1" in
    --target)   target="${2:-}"; shift 2 ;;
    --prompt)   prompt="${2:-}"; shift 2 ;;
    --features) features="${2:-}"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    --list)     printf 'target: %s (default %s)\n' "$current_target" "$default_target"
                printf 'prompt: basic|omp\nfeatures: %s\n' "$(IFS=,; printf '%s' "${ALL_FEATURES[*]}")"; exit 0 ;;
    -h|--help)  sed -n '2,26p' "$0"; exit 0 ;;
    *) printf 'zsh-configure: unknown option %s\n' "$1" >&2; exit 2 ;;
  esac
done

recommend_features() { if [[ "$1" == fullfat ]]; then printf 'brew,plugins,gcloud,kubernetes'; fi; }
recommend_prompt()   { if [[ "$1" == fullfat ]]; then printf 'omp'; else printf 'basic'; fi; }

if [[ -z $target ]]; then
  if [[ -t 0 ]]; then
    interactive=1
    printf '\nMachine: %s (default target: %s)\n\n' "$machine" "$default_target"
    printf 'Target type:\n'
    printf '  lite    - constrained/low-power (Raspberry Pi, Crostini): basic prompt,\n'
    printf '            no heavyweight extras.\n'
    printf '  fullfat - full dev workstation: oh-my-posh + brew/plugins/gcloud/k8s.\n\n'
    read -r -p "Target type [lite/fullfat] (default ${current_target}): " target
    [[ -n $target ]] || target="$current_target"
  else
    printf 'zsh-configure: %s target=%s prompt=%s features=[%s]\n' \
      "$machine" "$current_target" "${current_prompt:-basic}" "$current_features"
    printf 'Run with --target/--prompt/--features (or interactively) to change.\n'
    exit 0
  fi
fi
[[ "$target" == lite || "$target" == fullfat ]] || { printf 'zsh-configure: target must be lite|fullfat\n' >&2; exit 2; }

rec_feat="$(recommend_features "$target")"
rec_prompt="$(recommend_prompt "$target")"

if [[ $interactive == 1 ]]; then
  printf '\nOptional modules (recommended for %s: %s):\n' "$target" "${rec_feat:-none}"
  selected=()
  for f in "${ALL_FEATURES[@]}"; do
    default_no=1; [[ ",$rec_feat," == *",$f,"* ]] && default_no=0
    prompt_str=" [y/N]"; [[ $default_no == 0 ]] && prompt_str=" [Y/n]"
    read -r -p "  Enable ${f}${prompt_str}? $(feature_desc "$f"): " ans
    if [[ $default_no == 0 ]]; then
      [[ $ans =~ ^[Nn]$ ]] || selected+=("$f")
    else
      [[ $ans =~ ^[Yy]$ ]] && selected+=("$f")
    fi
  done
  features="$(IFS=,; printf '%s' "${selected[*]:-}")"
  read -r -p "Prompt [basic/omp] (default ${rec_prompt}): " prompt
  [[ -n $prompt ]] || prompt="$rec_prompt"
fi

[[ -n $prompt ]] || prompt="$rec_prompt"
[[ -n $features ]] || features="$rec_feat"
[[ "$prompt" == basic || "$prompt" == omp ]] || { printf 'zsh-configure: prompt must be basic|omp\n' >&2; exit 2; }

# Coherence: fullfat / omp / brew / plugins only make sense where Homebrew exists.
incoherent=""
[[ $target == fullfat ]] && incoherent+="targetType=fullfat "
[[ $prompt == omp ]] && incoherent+="prompt=omp "
if [[ -n $features ]]; then
  IFS=',' read -ra _inc <<< "$features"
  for f in "${_inc[@]}"; do
    case "$f" in brew|plugins) incoherent+="feature=$f " ;; esac
  done
fi
if [[ -n $incoherent && $brew_data != true ]]; then
  printf '\nWARNING: %sselected, but this machine has brew=false.\n' "$incoherent" >&2
  printf '  Homebrew / oh-my-posh / antidote are unavailable, and the client assets\n' >&2
  printf '  (zsh_plugins.txt, the omp theme) are not shipped -- those modules no-op.\n' >&2
  if ((interactive)); then
    read -r -p "Proceed anyway? [y/N] " _ok
    [[ $_ok =~ ^[Yy]$ ]] || { printf 'zsh-configure: aborted\n' >&2; exit 1; }
  elif ((!FORCE)); then
    printf 'zsh-configure: refusing without --force\n' >&2
    exit 3
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
chezmoi apply ~/.zshrc 2>/dev/null || true
printf '==> Applied ~/.zshrc. Review with: chezmoi diff %s ; open a new shell or run: source ~/.zshrc\n' "$data_file"
