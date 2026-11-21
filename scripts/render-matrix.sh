#!/usr/bin/env bash
#
# render-matrix.sh - prove the OS/arch/machine template paths render correctly.
#
# Uses `chezmoi --override-data` to simulate each machine's .chezmoi.os/.arch and
# data (machine/zshVariant/brew), then asserts, per row:
#   * which target files are managed (i.e. after home/.chezmoiignore)
#   * which zsh variant home/dot_zshrc.tmpl renders to
#   * which package-installer branch is selected
#
# Runs anywhere, makes no changes, and exits non-zero if any row fails. This is
# the "render matrix" from the agent-harness plan (Stage 6).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${HOME}/.local/bin:${PATH}"
CHEZMOI=(chezmoi --source "$REPO_ROOT")

fail=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*" >&2; fail=1; }

# name | os | arch | machine | variant | brew | must-match (; sep) | must-not-match (; sep) | zsh marker | zsh forbid
ROWS=(
  'chromebook|linux|arm64|chromebook|simple|false|\.bashrc;^\.profile$|\.zsh_plugins\.txt;stevejudd-full\.omp\.json|aptupd|antidote load'
  'mint|linux|amd64|mint|client|true|\.zsh_plugins\.txt;stevejudd-full\.omp\.json;^\.profile$|^a^z$|antidote load|aptupd'
  'darwin-arm64(render-only)|darwin|arm64|mac|client|true|\.zsh_plugins\.txt;stevejudd-full\.omp\.json|\.bashrc;\.bash_logout;^\.profile$|antidote load|aptupd'
)

for row in "${ROWS[@]}"; do
  IFS='|' read -r name os arch machine variant brew must mustnot zsh_marker zsh_forbid <<< "$row"
  printf '%s (%s/%s, %s, brew=%s)\n' "$name" "$os" "$arch" "$machine" "$brew"
  ov="{\"chezmoi\":{\"os\":\"${os}\",\"arch\":\"${arch}\"},\"machine\":\"${machine}\",\"zshVariant\":\"${variant}\",\"brew\":${brew}}"

  managed="$("${CHEZMOI[@]}" managed --override-data "$ov")"

  IFS=';' read -ra marks <<< "$must"
  for p in "${marks[@]}"; do
    if grep -Eq "$p" <<< "$managed"; then ok "managed has /${p}/"; else bad "managed missing /${p}/"; fi
  done
  IFS=';' read -ra nonmarks <<< "$mustnot"
  for p in "${nonmarks[@]}"; do
    if grep -Eq "$p" <<< "$managed"; then bad "managed unexpectedly has /${p}/"; else ok "managed excludes /${p}/"; fi
  done

  zsh="$("${CHEZMOI[@]}" execute-template --file home/dot_zshrc.tmpl --override-data "$ov")"
  if grep -q "$zsh_marker" <<< "$zsh"; then ok "zshrc has '${zsh_marker}'"; else bad "zshrc missing '${zsh_marker}'"; fi
  if grep -q "$zsh_forbid" <<< "$zsh"; then bad "zshrc unexpectedly has '${zsh_forbid}'"; else ok "zshrc excludes '${zsh_forbid}'"; fi

  apt="$("${CHEZMOI[@]}" execute-template --file home/run_onchange_install-packages.sh.tmpl --override-data "$ov")"
  if [[ "$os" == linux ]]; then
    if grep -q 'apt-get install' <<< "$apt"; then ok "apt installer selected"; else bad "apt installer not selected"; fi
  else
    if grep -q 'Non-Linux' <<< "$apt"; then ok "apt installer skipped ($os)"; else bad "apt installer not skipped ($os)"; fi
  fi

  brewsh="$("${CHEZMOI[@]}" execute-template --file home/run_onchange_install-brew.sh.tmpl --override-data "$ov")"
  if [[ "$brew" == true ]]; then
    if grep -q 'brew bundle' <<< "$brewsh"; then ok "brew installer selected"; else bad "brew installer not selected"; fi
  else
    if grep -q 'Not a Homebrew machine' <<< "$brewsh"; then ok "brew installer skipped"; else bad "brew installer not skipped"; fi
  fi
  printf '\n'
done

if ((fail)); then
  printf 'render-matrix: FAILED\n'
  exit 1
fi
printf 'render-matrix: OK\n'
