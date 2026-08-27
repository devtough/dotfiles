#!/bin/zsh
# wk-menu.sh <client_name> -- the whichkey board for the tmux prefix.
#
# Runs inside a display-popup opened by `bind -T prefix Any` (see
# whichkey.conf). Renders every prefix binding as a three-column grid, reads
# ONE key, closes, and REPLAYS `C-a <key>` at the client with send-keys -K.
# The replay is the whole trick: the real prefix bind in tmux.conf runs with
# full client/pane context, so this script holds only keys and labels --
# never commands -- and cannot drift in behavior, only in coverage.
#
# Ctrl-held forgiveness: chording fast often lands a key with ctrl still
# down. Ctrl bytes are mapped back to their letter before lookup, EXCEPT
# C-p/C-v/C-s, which are real distinct binds of their own.
#
# Esc, q, C-a, or any key not on the board closes it and does nothing.

CLIENT=$1
[ -z "$CLIENT" ] && exit 1

# Night Owl
KEY=$'\e[1m\e[38;2;130;170;255m'   # accent  #82aaff, bold
LBL=$'\e[38;2;214;222;235m'        # fg      #d6deeb
HDR=$'\e[1m\e[38;2;197;228;120m'   # yellow  #c5e478, bold
DIM=$'\e[38;2;104;118;134m'        # gray    #687686
R=$'\e[0m'

# key<TAB>label, one column per group. Coverage is hand-curated; behavior is
# not (see replay note above).
panes=(
  '-	split below'
  '|	split right'
  '_	claude below'
  '\	claude right'
  'z	zoom'
  'x	kill pane'
  'C-v	copy mode'
  'y	copy cwd'
)
windows=(
  'c	new window'
  'l	last window'
  'n	next window'
  'p	prev window'
  'j	jump (fzf)'
  'P	peek (fzf)'
  'w	tree'
  ',	rename'
  'N	AI-name window'
  'S	AI-name session'
)
sessions=(
  'a	agents (corral)'
  'C-p	claude scratch'
  'd	detach'
  'C-s	save layout'
  ':	command prompt'
)

typeset -A VALID
for item in "${panes[@]}" "${windows[@]}" "${sessions[@]}"; do
  VALID[${item%%	*}]=1
done

cell() { # key label -> one padded grid cell
  local k=$1 l=$2
  print -rn -- "  ${KEY}${(l:3:)k}${R}  ${LBL}${(r:17:)l}${R}"
}

print
print -rn -- "  ${HDR}${(r:22:):-panes}${R}"
print -rn -- "  ${HDR}${(r:22:):-windows}${R}"
print -r  -- "  ${HDR}sessions & agents${R}"
rows=${#windows}
for (( i=1; i<=rows; i++ )); do
  for group in panes windows sessions; do
    item=${${(P)group}[i]}
    if [ -n "$item" ]; then
      cell "${item%%	*}" "${item#*	}"
    else
      print -rn -- "${(r:24:):- }"
    fi
  done
  print
done
print
print -r -- "  ${DIM}esc close · ctrl-held ok${R}"

stty -isig -ixon 2>/dev/null
read -sk1 k || exit 0

code=$(printf '%d' "'$k")
case $code in
  27|0) exit 0 ;;              # Esc (or read oddity): close
  1)  exit 0 ;;                # C-a: toggle closed
  16) key="C-p" ;;             # real ctrl binds stay themselves
  22) key="C-v" ;;
  19) key="C-s" ;;
  *)
    if (( code >= 2 && code <= 26 )); then
      letters=(a b c d e f g h i j k l m n o p q r s t u v w x y z)
      key=${letters[$code]}    # ctrl-held slop -> plain letter
    else
      key=$k
    fi
    ;;
esac
[ "$key" = "q" ] && exit 0
[ -z "${VALID[$key]}" ] && exit 0

# Replay after the popup has closed; run-shell -b lives on the server, so it
# survives this script's exit.
tmux run-shell -b "sleep 0.15; tmux send-keys -K -c '${CLIENT}' -- C-a '${key}'"
exit 0
