#!/usr/bin/env bash
# Refresh the per-profile nvim state files tracked in this repo.
#
# lazy-lock.json and lazyvim.json are written by lazy.nvim and LazyVim
# themselves -- after `:Lazy update`, `:LazyExtras`, or just dismissing the NEWS
# popup, the live files drift from their templates and `chezmoi apply` starts
# asking whether to overwrite them.
#
# Do NOT run `chezmoi add` on either path. Both targets are dispatchers
# (dot_config/nvim/lazy-lock.json.tmpl) that pick a per-profile body out of
# .chezmoitemplates/; `chezmoi add` would replace the dispatcher with one flat
# file and silently break the other machines.
set -euo pipefail

source_dir="$(chezmoi source-path)"
profile="$(chezmoi execute-template '{{ .profile }}')"

echo "profile: $profile"

sync_one() {
  local live="$HOME/.config/nvim/$1"
  local tmpl="$source_dir/.chezmoitemplates/nvim-$2-$profile.json"

  if [[ ! -f "$live" ]]; then
    echo "  skip $1 -- not present at $live"
    return
  fi
  if [[ ! -f "$tmpl" ]]; then
    echo "  skip $1 -- no template slot for profile '$profile'"
    echo "        create ${tmpl#"$source_dir"/} first, and give it a branch in the dispatcher"
    return
  fi
  if cmp -s "$live" "$tmpl"; then
    echo "  ok   $1 -- already in sync"
    return
  fi
  cp "$live" "$tmpl"
  echo "  sync $1 -> ${tmpl#"$source_dir"/}"
}

sync_one lazy-lock.json lazy-lock
sync_one lazyvim.json lazyvim

echo
echo "Now review and commit:"
echo "  cd $source_dir && git diff --stat && chezmoi diff"
