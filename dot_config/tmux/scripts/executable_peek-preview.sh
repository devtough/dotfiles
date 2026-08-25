#!/bin/sh
# fzf preview for the window pickers (prefix j / prefix P).
#
# `tmux capture-pane` always returns a full pane's worth of rows, padding the
# bottom with blanks, so a naive preview opens on the TOP of the screen — which
# for a busy pane is the oldest thing on it. This trims the trailing blank rows
# and hands fzf exactly one preview-window's worth of the newest output, so the
# preview is anchored to the end of the buffer.
#
# usage: peek-preview.sh <session:window> [history-lines]
set -u

target="${1:?usage: peek-preview.sh <session:window> [history-lines]}"
history="${2:-200}"

tmux capture-pane -pe -S "-$history" -t "$target" 2>/dev/null |
    awk '
        { buf[NR] = $0 }
        # remember the last row with something other than whitespace/ANSI on it
        { probe = $0; gsub(/\033\[[0-9;?]*[ -\/]*[@-~]/, "", probe)
          if (probe ~ /[^[:space:]]/) last = NR }
        END { for (i = 1; i <= last; i++) print buf[i] }
    ' |
    tail -n "${FZF_PREVIEW_LINES:-40}"
