#!/bin/sh
# fzf preview for the window pickers (prefix j / prefix P).
#
# `tmux capture-pane` always returns a full pane's worth of rows, padding the
# bottom with blanks. Those blanks are the whole problem: fzf's `follow` flag
# anchors the preview to the last line it is given, so without this trim it
# would faithfully anchor to the bottom of the padding and show a screenful of
# nothing. Cut back to the last row with real content and let follow do the
# scrolling.
#
# This deliberately does NOT tail to one screenful. It used to, using
# FZF_PREVIEW_LINES, and that was wrong twice over: fzf reports one more usable
# line than it actually has (a 22-line preview window given 22 lines still
# scrolls), so the preview came up one line short of the bottom and drew a
# "1/22" scroll indicator that reads exactly like the top of a long buffer. And
# capping the output at a screenful threw away the history that makes the
# preview worth scrolling. Hand over everything and let fzf position it.
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
    '
