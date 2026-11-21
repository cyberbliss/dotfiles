#!/usr/bin/env bash
#
# doctor.sh <machine> - verify a machine against its declared checks.
#
# Reads the ```doctor block from machines/<machine>.md and evaluates each
# directive. Exit codes: 0 = all gating checks pass, 1 = one or more gating
# checks failed, 2 = usage error / unknown machine / missing doctor block.
#
# Directives (prefix with require_ or warn_):
#   os <codename>          /etc/os-release VERSION_CODENAME matches
#   arch <deb-arch>        dpkg --print-architecture matches
#   cmd <name>             command is on PATH
#   pkg <name>             deb package is installed
#   file <path>            path exists (~ is expanded)
#   shell <name>           login shell matches
#   git_identity           git user.name and user.email resolve
#   tmux_clipboard [path]  tmux config sets "set-clipboard on"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# chezmoi/mise live in ~/.local/bin; Linuxbrew machines use
# /home/linuxbrew/.linuxbrew/bin (see machines/*.md).
export PATH="${HOME}/.local/bin:/home/linuxbrew/.linuxbrew/bin:${PATH}"

if [[ -t 1 ]]; then
  C_OK=$'\033[32m'; C_NO=$'\033[31m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_NO=''; C_WARN=''; C_OFF=''
fi

usage() { printf 'usage: %s <machine>\n' "$(basename "$0")" >&2; }

expand() {
  # shellcheck disable=SC2088  # '~' patterns below are intentional literals
  case "$1" in
    '~')    printf '%s' "$HOME" ;;
    '~/'*)  printf '%s/%s' "$HOME" "${1#"~/"}" ;;
    *)      printf '%s' "$1" ;;
  esac
}

MSG=''
evaluate() { # <kind> <arg> -> 0 ok, 1 fail, 2 unknown
  local kind="$1" arg="${2:-}" p sh

  case "$kind" in
    os)
      # Match the Ubuntu base codename too: Linux Mint sets VERSION_CODENAME to
      # the Mint release name (e.g. wilma) but UBUNTU_CODENAME to the base.
      if grep -qE "^(VERSION|UBUNTU)_CODENAME=${arg}$" /etc/os-release; then
        MSG="os codename is ${arg}"
        return 0
      fi
      MSG="expected os codename ${arg}"
      return 1
      ;;
    arch)
      local got_arch; got_arch="$(dpkg --print-architecture)"
      if [[ "$got_arch" == "$arg" ]]; then
        MSG="pkg arch is ${arg}"
        return 0
      fi
      MSG="expected pkg arch ${arg} (got ${got_arch})"
      return 1
      ;;
    cmd)
      if command -v "$arg" >/dev/null 2>&1; then
        MSG="command '${arg}' present"
        return 0
      fi
      MSG="command '${arg}' missing"
      return 1
      ;;
    pkg)
      if dpkg -s "$arg" >/dev/null 2>&1; then
        MSG="package '${arg}' installed"
        return 0
      fi
      MSG="package '${arg}' not installed"
      return 1
      ;;
    file)
      p="$(expand "$arg")"
      if [[ -e "$p" ]]; then
        MSG="file ${arg} present"
        return 0
      fi
      MSG="file ${arg} missing"
      return 1
      ;;
    shell)
      sh="$(getent passwd "$(id -un)" | cut -d: -f7)"
      if [[ "$sh" == *"$arg" ]]; then
        MSG="login shell is ${arg}"
        return 0
      fi
      MSG="login shell is not ${arg} (got ${sh})"
      return 1
      ;;
    git_identity)
      if [[ -n "$(git -C "$REPO_ROOT" config user.name || true)" ]] \
         && [[ -n "$(git -C "$REPO_ROOT" config user.email || true)" ]]; then
        MSG="git identity set"
        return 0
      fi
      MSG="git user.name/user.email not set"
      return 1
      ;;
    tmux_clipboard)
      p="$(expand "${arg:-$HOME/.tmux.conf}")"
      if [[ -f "$p" ]] && grep -Eq '^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+set-clipboard[[:space:]]+on' "$p"; then
        MSG="tmux set-clipboard on configured"
        return 0
      fi
      MSG="tmux set-clipboard on not configured in ${arg:-~/.tmux.conf}"
      return 1
      ;;
    *)
      MSG="unknown check type '${kind}'"
      return 2
      ;;
  esac
}

machine="${1:-}"
if [[ -z "$machine" ]]; then
  usage
  exit 2
fi

machine_file="${REPO_ROOT}/machines/${machine}.md"
if [[ ! -f "$machine_file" ]]; then
  printf 'doctor: unknown machine %q (%s missing)\n' "$machine" "$machine_file" >&2
  exit 2
fi

block="$(awk '
  /^```doctor$/ { inside = 1; next }
  inside && /^```$/ { exit }
  inside { print }
' "$machine_file")"

if [[ -z "$block" ]]; then
  printf 'doctor: no ```doctor block in %s\n' "$machine_file" >&2
  exit 2
fi

printf 'doctor: %s (%s)\n' "$machine" "$machine_file"

pass=0; fail=0; warned=0

while IFS= read -r line; do
  line="${line%$'\r'}"
  # skip blank / comment / whitespace-only lines
  [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue

  type="${line%% *}"
  arg="${line#* }"; [[ "$arg" == "$type" ]] && arg=""
  sev="${type%%_*}"; kind="${type#*_}"

  if [[ "$sev" != "require" && "$sev" != "warn" ]]; then
    printf '  ?? %s\n' "invalid directive: ${line}"
    continue
  fi

  MSG=''
  if evaluate "$kind" "$arg"; then rc=0; else rc=$?; fi

  case "$rc" in
    0)   printf '  %sPASS%s %s\n' "$C_OK" "$C_OFF" "$line"; pass=$((pass + 1)) ;;
    2)   printf '  ?? %s\n' "$MSG" ;;
    *)   if [[ "$sev" == "warn" ]]; then
           printf '  %sWARN%s %s -- %s\n' "$C_WARN" "$C_OFF" "$line" "$MSG"
           warned=$((warned + 1))
         else
           printf '  %sFAIL%s %s -- %s\n' "$C_NO" "$C_OFF" "$line" "$MSG"
           fail=$((fail + 1))
         fi ;;
  esac
done <<< "$block"

printf '\n%s: %d passed, %d failed, %d warnings\n' "$machine" "$pass" "$fail" "$warned"

if (( fail > 0 )); then
  printf 'doctor: FAILED\n'
  exit 1
fi

printf 'doctor: OK\n'
exit 0
