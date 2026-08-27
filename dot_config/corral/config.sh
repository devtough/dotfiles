# corral configuration — sourced by ~/.local/bin/corral (plain shell assignments).
#
# Everything here has a working default in corral itself; this file exists so a
# machine can disagree with it. Every setting is written as ${VAR:=...} so the
# precedence stays environment > this file > corral's built-in default —
# `CORRAL_RESTORE=stage corral restore` has to win over what is written here.

# Flags handed to a resumed claude. Claude rewrites its process title to a bare
# "claude", so the flags a pane was started with cannot be recovered at save
# time from ps, tmux, or the transcript — they have to be declared once, here.
# These match the `prefix + _` / `prefix + \` splits in tmux.conf.
: "${CORRAL_CLAUDE_FLAGS:=--dangerously-skip-permissions --chrome}"

# What a restore does with the resume command it built:
#   auto  — type it into the restored pane and press Enter
#   stage — type it and leave it on the prompt, waiting for you
#   off   — log what it would have done and touch nothing
: "${CORRAL_RESTORE:=auto}"

# Restored login shells need a moment before they will accept typed input, and
# starting every agent in the same instant is a poor way to come back from a
# reboot.
: "${CORRAL_RESTORE_SETTLE:=3}"
: "${CORRAL_RESTORE_STAGGER:=0.7}"
: "${CORRAL_RESTORE_TRIES:=15}"

# A pane that claims to be working with no hook event for this long gets a "!"
# in `corral list`: the agent was killed, or it is wedged.
: "${CORRAL_STALE_SECS:=1800}"

# Snapshots to keep in ~/.local/state/corral/restore.
: "${CORRAL_SNAPSHOT_KEEP:=20}"

# How often `corral tick` is allowed to do real work. It is called from a status
# bar job, which tmux re-runs every status-interval (5s) -- far too often to be
# reading panes. Below this, tick returns after one stamp-file read.
#
# This is the interval at which an agent that died without saying so, and a
# codex pane that never says anything, get corrected on the status bar. Lower it
# if the bar feels slow to admit an agent has stopped; the cost is one scan
# (~150ms for six panes) per interval.
: "${CORRAL_TICK_SECS:=30}"

# "Engaged" for corral-hook's at-finish check alone: a turn that ends while
# the pane is focused and the client has seen input this recently never
# becomes a done badge -- it finished under your hands. (The refresh sweep
# does not use a window; it clears on any input newer than the badge.) The
# hook does not source this file -- it reads CORRAL_ENGAGED_SECS from its
# environment, so export it where the agents start if you change it.
: "${CORRAL_ENGAGED_SECS:=30}"
