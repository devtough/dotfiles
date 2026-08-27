#!/usr/bin/env bash
# Detach the herdr-git-sync watcher so herdr's plugin startup does not block on
# a script that never exits.
#
# Re-running this is safe: herdr-git-sync holds a per-session pidfile in $TMPDIR
# and refuses to start a second watcher for the same session, so a config reload
# or a second invocation cannot stack pollers.
set -uo pipefail

bin="${HOME}/.local/bin/herdr-git-sync"
[ -x "$bin" ] || { echo "git-sync: $bin is not executable" >&2; exit 1; }

nohup "$bin" --watch >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0
