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

## Keyboard Shortcuts (macOS)

### Hammerspoon - App Focus

| Shortcut | Action |
|----------|--------|
| `ctrl+space` | WezTerm |
| `ctrl+cmd+b` | Arc |
| `ctrl+cmd+c` | VS Code |
| `ctrl+cmd+o` | Obsidian |
| `ctrl+cmd+s` | Slack |
| `ctrl+cmd+n` | Notion |

### Hammerspoon - Window Management

| Shortcut | Action |
|----------|--------|
| `ctrl+cmd+r` | Maximize |
| `ctrl+cmd+1` | Left 1/3 |
| `ctrl+cmd+2` | Center 1/3 |
| `ctrl+cmd+3` | Right 1/3 |
| `ctrl+cmd+q` | Left 2/3 |
| `ctrl+cmd+e` | Right 2/3 |
| `ctrl+cmd+w` | Center 1/2 |
| `ctrl+cmd+`` ` | Minimize all |

### Yabai - Mouse

| Input | Action |
|-------|--------|
| `fn+mouse1` | Move window |
| `fn+mouse2` | Resize window |

---

## OSX Config Review (2025-12-17)

Audit of local dotfiles not yet tracked by chezmoi.

### High Priority - Recommended Additions

| File | Description |
|------|-------------|
| `~/.yabairc` | Yabai window manager config |
| `~/.config/skhd/skhdrc` | Hotkey daemon keybindings |
| `~/.config/aerospace/aerospace.toml` | AeroSpace window manager |
| `~/.config/ghostty/config` | Ghostty terminal (Ayu Mirage theme) |
| `~/.hammerspoon/init.lua` | Hammerspoon automation |
| `~/.config/jj/config.toml` | Jujutsu VCS config |
| `~/.config/git/ignore` | Global gitignore |

### Medium Priority - May Need Templating

| File | Notes |
|------|-------|
| `~/.config/gh/config.yml` | GitHub CLI - check for tokens |
| `~/.config/nix/` | Nix config (flake.nix, flake.lock) |
| `~/.zprofile` | Minimal, Homebrew setup only |

### Lower Priority

| File | Notes |
|------|-------|
| `~/.config/rio/config.toml` | Rio terminal |
| `~/.config/acli/` | Atlassian CLI - likely contains secrets |

### Skip (Sensitive/Auto-generated)

- `~/.aws/`, `~/.azure/`, `~/.kube/`, `~/.ssh/` - credentials
- `~/.zsh_history`, `~/.bash_history` - history files
- `~/.cache/`, `~/.local/share/` - cache data
