#!/usr/bin/env bash
#
# install-extras.sh [machine] [--with <stack,...>] [--list]
#
# Installs OPTIONAL stacks that are intentionally kept out of the chezmoi
# baseline (home/run_onchange_install-packages.sh.tmpl). The intended flow is
# that an agent ASKS which of these the user wants, then runs:
#
#   scripts/install-extras.sh <machine> --with gcloud,docker
#
# Stack names:
#   gcloud  Google Cloud CLI (Google apt repo; run `gcloud init` afterwards)
#   docker  Docker Engine + compose/buildx (Docker apt repo; enables services)
#   mise    Language/runtime tools listed in packages/mise.txt (via mise)
#   prompt  oh-my-posh + antidote for the client-style zsh prompt
#
# Safe to re-run: every step is idempotent. With no --with and an interactive
# terminal it prompts for each stack; otherwise it prints what is available.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"

# gcloud/docker write here inside Crostini where there is no systemd.
export DEBIAN_FRONTEND=noninteractive

STACKS=(gcloud docker mise prompt)

log()  { printf '==> %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }

# apt_codename: prefer the Ubuntu base codename, because Linux Mint sets
# VERSION_CODENAME to the Mint release name (e.g. "wilma") while third-party apt
# repos (docker, etc.) key on the Ubuntu base (e.g. "noble").
apt_codename() {
  local c
  c="$(sed -n 's/^UBUNTU_CODENAME=//p' /etc/os-release)"
  [[ -n $c ]] || c="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release)"
  printf '%s' "$c"
}

usage() {
  printf 'usage: %s [machine] [--with <%s>] [--list]\n' \
    "$(basename "$0")" "$(IFS=,; printf '%s' "${STACKS[*]}")"
}

command -v apt-get >/dev/null 2>&1 || {
  warn "apt-get not found; this script is for Debian-family Linux only"
  exit 2
}

# apt_install <pkg...> -- installs only the ones that are missing.
apt_install() {
  local -a missing=() p
  for p in "$@"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if ((${#missing[@]} == 0)); then
    log "$* already installed"
    return 0
  fi
  log "apt-get install ${missing[*]}"
  sudo apt-get install -y -qq "${missing[@]}"
}

do_gcloud() {
  local keyring=/usr/share/keyrings/cloud.google.gpg
  local list=/etc/apt/sources.list.d/google-cloud-sdk.list
  if [[ ! -f $keyring ]]; then
    log "Adding Google Cloud apt key"
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | sudo gpg --dearmor -o "$keyring"
  fi
  if [[ ! -f $list ]]; then
    log "Adding Google Cloud apt repo"
    echo "deb [signed-by=${keyring}] https://packages.cloud.google.com/apt cloud-sdk main" \
      | sudo tee "$list" >/dev/null
  fi
  sudo apt-get update -qq
  apt_install google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin
  printf '   Next: run "gcloud init" to authenticate.\n'
}

do_docker() {
  local arch codename keyring list
  arch="$(dpkg --print-architecture)"
  codename="$(apt_codename)"
  keyring=/etc/apt/keyrings/docker.asc
  list=/etc/apt/sources.list.d/docker.list

  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f $keyring ]]; then
    log "Adding Docker apt key"
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      | sudo gpg --dearmor -o "$keyring"
    sudo chmod a+r "$keyring"
  fi
  if [[ ! -f $list ]]; then
    log "Adding Docker apt repo (debian/${codename}, ${arch})"
    echo "deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/debian ${codename} stable" \
      | sudo tee "$list" >/dev/null
  fi
  sudo apt-get update -qq
  apt_install docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

  if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
    log "Enabling docker + containerd services"
    sudo systemctl enable --now docker.service containerd.service
  else
    warn "systemd is not running; docker services not enabled (expected in Crostini)"
  fi
}

do_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    warn "mise not found on PATH (~/.local/bin) -- run scripts/bootstrap.sh first"
    return 1
  fi
  local list="${REPO_ROOT}/packages/mise.txt" tool
  [[ -f $list ]] || { warn "no ${list}"; return 1; }
  while IFS= read -r tool; do
    tool="${tool%%#*}"
    tool="${tool//[[:space:]]/}"
    [[ -n $tool ]] || continue
    log "mise: ${tool}"
    mise use -g "${tool}"
  done < "$list"
}

do_prompt() {
  local bin="${HOME}/.local/bin" arch antidote="${HOME}/.antidote/antidote.zsh"
  case "$(dpkg --print-architecture)" in
    amd64) arch=amd64 ;;
    arm64) arch=arm64 ;;
    *) warn "unsupported arch for oh-my-posh"; return 1 ;;
  esac
  mkdir -p "$bin"
  if ! command -v oh-my-posh >/dev/null 2>&1; then
    log "Installing oh-my-posh -> ${bin}"
    curl -fsSL -o "${bin}/oh-my-posh" \
      "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-${arch}"
    chmod +x "${bin}/oh-my-posh"
  else
    log "oh-my-posh already present"
  fi
  if [[ ! -f $antidote ]]; then
    log "Cloning antidote -> ~/.antidote"
    git clone --depth 1 https://github.com/mattmc3/antidote.git "${HOME}/.antidote"
  else
    log "antidote already present"
  fi
  warn "installed oh-my-posh + antidote under ~/. To use them in zsh, enable the"
  warn "modules: scripts/zsh-configure.sh --target fullfat --prompt omp --features brew,plugins"
}

run_stack() {
  case "$1" in
    gcloud) do_gcloud ;;
    docker) do_docker ;;
    mise)   do_mise ;;
    prompt) do_prompt ;;
    *) warn "unknown stack '${1}'"; return 1 ;;
  esac
}

WITH=""; MACHINE=""
while (($#)); do
  case "$1" in
    --list) printf '%s\n' "${STACKS[@]}"; exit 0 ;;
    --with) WITH="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --*) warn "unknown option '$1'"; usage; exit 2 ;;
    *) MACHINE="$1"; shift ;;
  esac
done

[[ -n $MACHINE ]] && log "machine: ${MACHINE}"

SELECTED=()
if [[ -n $WITH ]]; then
  IFS=',' read -r -a SELECTED <<< "$WITH"
elif [[ -t 0 && -t 1 ]]; then
  for s in "${STACKS[@]}"; do
    read -r -p "Install optional stack '${s}'? [y/N] " ans
    [[ $ans =~ ^[Yy]$ ]] && SELECTED+=("$s")
  done
else
  printf 'install-extras: no --with and no terminal; nothing to do.\n'
  printf 'available stacks: %s\n' "$(IFS=,; printf '%s' "${STACKS[*]}")"
  exit 0
fi

if ((${#SELECTED[@]} == 0)); then
  log "no stacks selected"
  exit 0
fi

for s in "${SELECTED[@]}"; do
  run_stack "$s"
done
log "done"
