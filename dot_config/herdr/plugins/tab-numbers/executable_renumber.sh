#!/bin/sh
# Keep every tab label prefixed with its number.
#
# MODE=position -> number by order in the tab bar (matches prefix+1..9)
# MODE=number   -> use Herdr's stable per-workspace tab number (has gaps)
set -eu

MODE="${HERDR_TABNUM_MODE:-position}"

HERDR=herdr
command -v "$HERDR" >/dev/null 2>&1 || HERDR="$HOME/.local/bin/herdr"

renumber_workspace() {
	"$HERDR" tab list --workspace "$1" | jq -r --arg mode "$MODE" '
		.result.tabs
		| to_entries[]
		| (if $mode == "number" then .value.number else .key + 1 end) as $n
		| (.value.label | sub("^[0-9]+ *"; "")) as $base
		| (if $base == "" then "\($n)" else "\($n) \($base)" end) as $want
		| select($want != .value.label)
		| [.value.tab_id, $want]
		| @tsv
	' | while IFS="$(printf '\t')" read -r tab_id want; do
		"$HERDR" tab rename "$tab_id" "$want" >/dev/null 2>&1 || true
	done
}

"$HERDR" workspace list |
	jq -r '.result.workspaces[].workspace_id' |
	while read -r ws; do
		renumber_workspace "$ws"
	done
