# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io/). Supports macOS and Linux.

## New System Setup

```bash
chezmoi init --apply https://github.com/YOUR_USERNAME/dotfiles.git
```

## Making Changes

Use Claude Code to validate, apply, and commit changes:

```bash
# 1. Edit source files directly in this repo
# 2. Run /apply-config in Claude Code to:
#    - Review pending chezmoi diff
#    - Validate config syntax
#    - Apply changes to system
#    - Commit to git
```

Manual workflow:
```bash
chezmoi edit ~/.zshrc    # edit managed file
chezmoi diff             # preview changes
chezmoi apply            # apply to system
```

Other useful commands:
```bash
chezmoi add ~/.config/foo    # track a new file
chezmoi update               # pull and apply from remote
```

## What's Included

| Config | Notes |
|--------|-------|
| nvim | LazyVim-based |
| tmux | Ayu Mirage, vim-tmux-navigator |
| zsh | oh-my-zsh, powerlevel10k, direnv |

External plugins managed via `.chezmoiexternal.toml`.

## Multi-OS

Templates (`.tmpl` files) use `.chezmoi.os` for OS-specific config.
