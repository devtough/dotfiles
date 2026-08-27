#!/bin/sh
# The corral agents picker: every agent on the server, loudest first, with a
# live preview of the pane. Enter switches to it. One script because two
# things open it -- `prefix + a`, and a mouse click on the rollup strip (the
# #[range=user|corral] markers corral wraps the strip in are what make the
# click resolvable to "that was the strip").
#
# Rows come out of `corral list --agents` in the strip order -- done, blocked,
# working, stale, then idle sorted most-recently-active first -- with the
# strip colours on the glyphs (--ansi is what renders them). The row under
# the cursor when the popup opens is the top of that order. Field 2 is the target (session:window.pane): what the preview
# reads and what switch-client takes. --header-lines=1 keeps corral's column
# header out of the selectable rows. The preview goes through peek-preview.sh
# for the same reason the window pickers do: it trims the blank rows
# capture-pane pads with, so `follow` anchors to real output and the scroll
# indicator in the preview's top-right corner reads as a true offset into the
# history (e.g. 39/60) instead of a 1/N parked at the top.
set -u

target=$("$HOME/.local/bin/corral" list --agents |
    fzf --ansi --reverse --header-lines=1 \
        --preview "$HOME/.config/tmux/scripts/peek-preview.sh {2}" \
        --preview-window=down:60%,follow |
    awk '{print $2}')
[ -n "${target:-}" ] && exec tmux switch-client -t "$target"
exit 0
