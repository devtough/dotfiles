#!/usr/bin/env bash
# AWS profile script for tmux status bar
# Reads from the currently active pane's cached AWS_PROFILE

# Get the active pane's ID
pane_id=$(tmux display-message -p '#{pane_id}' 2>/dev/null | tr -d '%')

# Check for pane-specific cache file
cache_file="/tmp/tmux-aws-${pane_id}"
if [ -f "$cache_file" ]; then
  aws_profile=$(cat "$cache_file")
fi

# Output with label, show "none" if not set
if [ -n "$aws_profile" ]; then
  echo "$aws_profile"
else
  echo "none"
fi
