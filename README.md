# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io/). Supports macOS and Linux (Arch/Omarchy).

## Quick Setup

```bash
# Install chezmoi and apply dotfiles
chezmoi init --apply https://github.com/YOUR_USERNAME/dotfiles.git

# Or step-by-step
chezmoi init https://github.com/YOUR_USERNAME/dotfiles.git
chezmoi diff    # preview changes
chezmoi apply   # apply changes
```

## What's Included

| Config | Shared | Notes |
|--------|--------|-------|
| nvim | Yes | LazyVim-based config |
| tmux | Yes | Ayu Mirage theme, vim-tmux-navigator |
| zsh | Yes | oh-my-zsh, powerlevel10k, direnv |
| p10k | Yes | Powerlevel10k prompt config |
| wezterm | macOS only | Ignored on Linux |

## Multi-OS Support

Templates (`.tmpl` files) handle OS differences:
- `.chezmoi.os` = `darwin` (macOS) or `linux`
- macOS-specific: WezTerm PATH/completions
- Linux-specific: add to `.chezmoiignore.tmpl` as needed

## Key Commands

```bash
chezmoi add ~/.config/foo    # track a new file
chezmoi edit ~/.zshrc        # edit managed file
chezmoi diff                 # see pending changes
chezmoi apply                # apply changes to home dir
chezmoi cd                   # cd to source directory
chezmoi update               # pull and apply latest
```

## External Dependencies

Managed via `.chezmoiexternal.toml`:
- oh-my-zsh
- powerlevel10k
- zsh-syntax-highlighting
- zsh-history-substring-search
- tmux plugin manager (tpm)
