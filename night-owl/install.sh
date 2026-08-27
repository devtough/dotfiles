#!/bin/bash
# Night Owl installer for the Mac — run once from the repo checkout:
#   bash "$(chezmoi source-path)/night-owl/install.sh" [--vault /path/to/vault]
#
# tmux is NOT handled here: chezmoi manages it — `chezmoi apply` renders the
# Night Owl block in ~/.config/tmux/tmux.conf directly.
#
# Idempotent: safe to re-run; each step skips or overwrites its own file only.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

VAULT=""
[[ "${1:-}" == "--vault" ]] && VAULT="${2:-}"

# --- Ghostty: built-in theme, just point the config at it --------------------
ghostty_cfg=""
# config.ghostty is checked FIRST and is the one in use on sonbox. Ghostty 1.3
# reads it, verified via `ghostty +show-config` (font-size 15 vs the default
# 13). The old list only had bare "config", matched nothing, and fell through to
# creating ~/.config/ghostty/config -- a file that would have competed with the
# real one instead of theming it.
for f in "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty" \
         "$HOME/Library/Application Support/com.mitchellh.ghostty/config" \
         "$HOME/.config/ghostty/config"; do
  [[ -f $f ]] && { ghostty_cfg=$f; break; }
done
if [[ -n $ghostty_cfg ]]; then
  if grep -qE '^\s*theme\s*=' "$ghostty_cfg"; then
    sed -i '' -E 's/^\s*theme\s*=.*/theme = Night Owl/' "$ghostty_cfg"
    echo "ghostty: theme line updated in $ghostty_cfg"
  else
    printf '\ntheme = Night Owl\n' >>"$ghostty_cfg"
    echo "ghostty: theme = Night Owl appended to $ghostty_cfg"
  fi
  echo "ghostty: reload with cmd+shift+, (or restart)"
else
  mkdir -p "$HOME/.config/ghostty"
  printf 'theme = Night Owl\n' >"$HOME/.config/ghostty/config"
  echo "ghostty: no config found, created ~/.config/ghostty/config"
fi

# --- Zen: userChrome.css into every profile ----------------------------------
found=0
for prof in "$HOME/Library/Application Support/zen/Profiles"/*/; do
  [[ -d $prof ]] || continue
  mkdir -p "$prof/chrome"
  cp "$HERE/userChrome.css" "$prof/chrome/userChrome.css"
  echo "zen: installed userChrome.css -> $prof"
  found=1
done
if (( found )); then
  echo "zen: set toolkit.legacyUserProfileCustomizations.stylesheets=true in about:config, then restart Zen"
else
  echo "zen: no profiles found under ~/Library/Application Support/zen/Profiles — is Zen installed?"
fi

# --- Obsidian: snippet into the vault (if given) ------------------------------
if [[ -n $VAULT ]]; then
  if [[ -d $VAULT/.obsidian ]]; then
    mkdir -p "$VAULT/.obsidian/snippets"
    cp "$HERE/night-owl-colors.css" "$VAULT/.obsidian/snippets/night-owl-colors.css"
    echo "obsidian: snippet installed -> enable 'night-owl-colors' in Appearance -> CSS snippets"
    echo "obsidian: if this vault syncs from the Linux box, DISABLE the omarchy-colors snippet there"
  else
    echo "obsidian: $VAULT has no .obsidian directory — skipped"
  fi
else
  echo "obsidian: no --vault given — copy night-owl-colors.css into <vault>/.obsidian/snippets/ yourself"
fi

# --- herdr: nothing to do; chezmoi owns the config now -----------------------
# The [theme] block used to be appended here. ~/.config/herdr/config.toml is a
# chezmoi-managed file as of 2026-08-19 (dot_config/herdr/config.toml), with the
# contents of herdr-theme-block.toml inlined, so appending would fight `chezmoi
# apply`. herdr-theme-block.toml is kept as the reference copy of that block.
echo "herdr: managed by chezmoi — run 'chezmoi apply', not this script"

# --- Slack: manual paste ------------------------------------------------------
echo "slack: paste this in Preferences -> Themes -> Import (sidebar only):"
cat "$HERE/slack-theme.txt"; echo
command -v pbcopy >/dev/null && pbcopy <"$HERE/slack-theme.txt" && echo "slack: string copied to clipboard"

echo "done."
