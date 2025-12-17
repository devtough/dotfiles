#!/usr/bin/env bash
# Redpanda profile script for tmux status bar

# Check if rpk is available
if ! command -v rpk &> /dev/null; then
  exit 0
fi

# Get active profile (marked with *)
active=$(rpk profile list 2>/dev/null | grep '\*' | awk '{print $1}' | tr -d '*')

if [ -n "$active" ]; then
  echo "$active"
fi
