#!/usr/bin/env bash
# Syncs AWS_PROFILE to tmux pane-specific cache for status bar display
# Source this in your .zshrc AFTER the direnv hook

_tmux_sync_aws_profile() {
  # Only run inside tmux
  if [ -n "$TMUX_PANE" ]; then
    local cache_file="/tmp/tmux-aws-${TMUX_PANE//%/}"
    if [ -n "$AWS_PROFILE" ]; then
      echo "$AWS_PROFILE" > "$cache_file"
    else
      rm -f "$cache_file" 2>/dev/null
    fi
  fi
}

# Hook into directory changes
autoload -U add-zsh-hook 2>/dev/null && add-zsh-hook chpwd _tmux_sync_aws_profile

# Also hook into precmd to catch direnv changes that happen after cd
_tmux_sync_aws_profile_precmd() {
  _tmux_sync_aws_profile
}
autoload -U add-zsh-hook 2>/dev/null && add-zsh-hook precmd _tmux_sync_aws_profile_precmd

# Run once on shell startup
_tmux_sync_aws_profile
