#!/usr/bin/env bash
# Detach the herdr-agent-ctx watcher so plugin startup isn't blocked by a loop
# that never returns. herdr-agent-ctx holds a per-session pidfile, so re-running
# this cannot stack pollers.
set -uo pipefail

bin="${HOME}/.local/bin/herdr-agent-ctx"
[ -x "$bin" ] || { echo "agent-ctx: $bin is not executable" >&2; exit 1; }

nohup "$bin" --watch >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0
