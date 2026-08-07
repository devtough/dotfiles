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
for f in "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "$HOME/.config/ghostty/config"; do
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

# --- herdr: append the [theme] block if the config doesn't define one --------
herdr_cfg="$HOME/.config/herdr/config.toml"
if [[ -f $herdr_cfg ]]; then
  if grep -qE '^\[theme\]' "$herdr_cfg"; then
    echo "herdr: config already defines [theme] — merge $HERE/herdr-theme-block.toml by hand"
  else
    { printf '\n'; cat "$HERE/herdr-theme-block.toml"; } >>"$herdr_cfg"
    command -v herdr >/dev/null && herdr server reload-config >/dev/null 2>&1
    echo "herdr: theme block appended to config.toml"
  fi
else
  echo "herdr: no config at $herdr_cfg — skipped"
fi

# --- Slack: manual paste ------------------------------------------------------
echo "slack: paste this in Preferences -> Themes -> Import (sidebar only):"
cat "$HERE/slack-theme.txt"; echo
command -v pbcopy >/dev/null && pbcopy <"$HERE/slack-theme.txt" && echo "slack: string copied to clipboard"

echo "done."
