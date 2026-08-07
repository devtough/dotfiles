# Night Owl for the Mac

Night Owl theming for the apps chezmoi doesn't (or can't) manage on macOS.
All colors are derived from the omarchy `night-owl` theme's `colors.toml`
(github.com/janhesters/omarchy-night-owl-theme) using the same role-derivation
logic as `~/.config/omarchy/hooks/theme-set` on the Linux box.

This directory is listed in `.chezmoiignore` — nothing here is deployed by
`chezmoi apply`.

## Usage (on the Mac)

```sh
chezmoi update    # pulls + applies: tmux gets Night Owl via tmux.conf.tmpl
bash "$(chezmoi source-path)/night-owl/install.sh" --vault ~/path/to/vault
```

Then:
- **Ghostty**: reload config (cmd+shift+,) — uses the built-in `Night Owl` theme
- **Zen**: flip `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`
  in `about:config`, restart
- **Obsidian**: enable the `night-owl-colors` snippet (Appearance → CSS snippets).
  If the vault syncs from the Linux box, disable `omarchy-colors` first — the
  two snippets fight.
- **herdr**: block is appended to `~/.config/herdr/config.toml`; base colors
  follow Ghostty's ANSI palette, so Ghostty must be on Night Owl
- **Slack**: install.sh copies the sidebar string to the clipboard — paste in
  Preferences → Themes → Import

## Files

| file | target |
|---|---|
| `userChrome.css` | `~/Library/Application Support/zen/Profiles/*/chrome/` |
| `night-owl-colors.css` | `<vault>/.obsidian/snippets/` |
| `herdr-theme-block.toml` | appended to `~/.config/herdr/config.toml` |
| `slack-theme.txt` | manual paste into Slack |

## Derived roles

bg `#011627` · fg `#d6deeb` · accent `#82aaff` · surface `#1d3b53` ·
overlay `#575656` · muted `#687686` · faint `#415262` · on_accent `#011627`
