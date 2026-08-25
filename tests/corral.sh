#!/usr/bin/env bash
# tests/corral.sh — behavioural tests for corral against a real, throwaway tmux
# server.
#
# corral is almost entirely tmux state and jq, so the useful test is not a unit
# test of a shell function: it is the whole thing driving a tmux server that is
# not yours. Everything corral touches is already redirectable, which is what
# makes this cheap —
#
#   tmux -S $tmpdir/sock      a private server on a socket inside the test's
#                             own temp dir; $TMUX points corral (and the hooks
#                             it runs) at it, so nothing here can see, write to,
#                             or kill your real panes, and no socket is left
#                             behind in the shared /tmp/tmux-$UID.
#   CORRAL_STATE_DIR          records, snapshots and the log land in a temp dir.
#   CORRAL_CONFIG=/dev/null   your ~/.config/corral/config.sh stays out of it.
#   PATH                      the *repo* copies of corral and corral-hook run,
#                             not whatever chezmoi last deployed to ~/.local/bin.
#
# The one thing tmux will not fake for us is an agent process. A pane running a
# shell reads as "the agent exited" by design, so a test that reports state into
# a bare shell pane gets null back and proves nothing. fake_agent() therefore
# gives each pane a real process named the way the real agent names itself:
# claude execs a per-release binary, so its pane_current_command is a version
# string like 2.1.238, and that plus a marked pane title is exactly what
# corral's agent detection keys on.
#
# Run:  tests/corral.sh              all tests
#       tests/corral.sh restore      only tests whose name matches "restore"
#       KEEP=1 tests/corral.sh       leave the temp dir behind for poking at

set -uo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
CORRAL_SRC=$REPO/dot_local/bin/executable_corral
HOOK_SRC=$REPO/dot_local/bin/executable_corral-hook
RULES_SRC=$REPO/dot_config/corral/rules.json

FILTER=${1:-}
PASS=0 FAIL=0 SKIP=0
FAILED_NAMES=()

# --- assertions -------------------------------------------------------------

fail() { printf '    ✘ %s\n' "$*"; TEST_OK=0; }

assert_eq() { # want got label
	if [[ $1 == "$2" ]]; then return 0; fi
	fail "$3: want [$1] got [$2]"
}

assert_contains() { # haystack needle label
	case $1 in *"$2"*) return 0 ;; esac
	fail "$3: [$1] does not contain [$2]"
}

assert_empty() { # got label
	[[ -z ${1//[[:space:]]/} ]] || fail "$2: expected nothing, got [$1]"
}

# --- the throwaway world ----------------------------------------------------

tm() { tmux -S "$SOCKET" "$@"; }

# corral list --json, filtered. `q '.[0].state'`
q() { corral list --json | jq -r "$1"; }

# Everything about one pane, by pane id. `pq %1 '.state'`
pq() { local p=$1; shift; corral list --json | jq -r --arg p "$p" '.[] | select(.pane_id == $p) | '"$1"; }

# A pane that looks like a running agent to tmux: a real process whose argv[0]
# basename is what the agent calls itself. macOS kills a copied system binary on
# exec unless it is re-signed, so ad-hoc sign it when codesign is around.
fake_bin() { # name -> path
	local name=$1 path=$WORLD/bin/$1
	if [[ ! -x $path ]]; then
		cp "$(command -v sleep)" "$path"
		command -v codesign >/dev/null 2>&1 && codesign -f -s - "$path" >/dev/null 2>&1
	fi
	printf '%s\n' "$path"
}

# fake_agent <cmdname> [pre-command] -> pane id
# Opens a window, optionally prints something to the screen first (for the scan
# rules, which read the screen), then starts the fake agent in the foreground.
# Deliberately not `exec`: a real agent is a child of the pane's shell, so
# killing it drops the pane back to a prompt — which is the only signal corral
# gets that an agent died, and half of these tests turn on it. exec'ing would
# close the pane instead.
fake_agent() {
	local name=$1 pre=${2:-} bin pane
	bin=$(fake_bin "$name")
	tm new-window -P -F '#{pane_id}' >"$WORLD/.pane"
	pane=$(<"$WORLD/.pane")
	tm send-keys -t "$pane" "clear; ${pre:+$pre; }$bin 600" Enter
	# Wait for the exec to actually take, or the pane still reads as a shell.
	local _i
	for _i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
		[[ $(tm display-message -p -t "$pane" '#{pane_current_command}') == "$name" ]] && break
		sleep 0.1
	done
	printf '%s\n' "$pane"
}

setup() {
	WORLD=$(mktemp -d "${TMPDIR:-/tmp}/corral-test.XXXXXX")
	mkdir -p "$WORLD/bin" "$WORLD/state"
	ln -sf "$CORRAL_SRC" "$WORLD/bin/corral"
	ln -sf "$HOOK_SRC" "$WORLD/bin/corral-hook"

	# Build the environment BEFORE starting the server, so the server — and
	# therefore every pane shell it spawns — inherits it. Starting first and
	# calling set-environment after only fixes panes created later: the initial
	# pane keeps the environment the runner had, which silently means its
	# `corral-hook` is the *deployed* one and its state lands in the real
	# ~/.local/state/corral. Two hook tests passed against the wrong binary
	# that way.
	unset CLAUDE_CODE_SESSION_ID CLAUDE_CODE_CHILD_SESSION CODEX_THREAD_ID

	export PATH=$WORLD/bin:$PATH
	export CORRAL_STATE_DIR=$WORLD/state
	export CORRAL_CONFIG=/dev/null
	export CORRAL_RULES=$RULES_SRC
	export CORRAL_RESTORE=auto
	export CORRAL_RESTORE_SETTLE=0
	export CORRAL_RESTORE_STAGGER=0
	export CORRAL_RESTORE_TRIES=3
	export CORRAL_STALE_SECS=1800
	export CORRAL_CLAUDE_FLAGS="--test-flag"
	unset TMUX TMUX_PANE

	SOCKET=$WORLD/tmux.sock
	# -f /dev/null: your tmux.conf has corral wired into it; a test server must
	# start with nothing but tmux's defaults.
	# /bin/sh on new-session as well as default-command: the option only
	# governs panes created after it is set, and the hook tests drive pane %0.
	tmux -S "$SOCKET" -f /dev/null new-session -d -s t -x 120 -y 40 /bin/sh
	# A plain, rc-less /bin/sh in every pane, not $SHELL. An interactive zsh
	# sources ~/.zshrc, which re-prepends ~/.local/bin and puts the *deployed*
	# corral and corral-hook back in front of $WORLD/bin — so pane-side commands
	# would silently exercise the installed copies and write to the real
	# ~/.local/state/corral. Exporting PATH before starting the server is not
	# enough on its own; the rc file runs afterwards and wins.
	tmux -S "$SOCKET" set-option -g default-command /bin/sh 2>/dev/null

	local sockpath serverpid
	sockpath=$(tm display-message -p "#{socket_path}")
	serverpid=$(tm display-message -p "#{pid}")
	export TMUX="$sockpath,$serverpid,0"
	STATE=$WORLD/state
	PANES=$STATE/panes
	SNAPS=$STATE/restore
}

teardown() {
	tmux -S "$SOCKET" kill-server >/dev/null 2>&1
	[[ ${KEEP:-0} == 1 ]] && { printf '    (kept %s)\n' "$WORLD"; return; }
	rm -rf "$WORLD"
}

# --- runner -----------------------------------------------------------------

run_test() {
	local name=$1
	[[ -n $FILTER && $name != *$FILTER* ]] && return 0
	TEST_OK=1
	printf '  %s\n' "$name"
	setup
	"test_$name"
	teardown
	if ((TEST_OK)); then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); FAILED_NAMES+=("$name"); fi
}

# ===========================================================================
# inventory: what corral thinks is in each pane
# ===========================================================================

test_inventory_plain_shell_has_no_agent() {
	local n
	n=$(q 'length')
	assert_eq 1 "$n" "one pane on a fresh server"
	assert_eq null "$(q '.[0].agent')" "a shell pane has no agent"
	assert_eq null "$(q '.[0].state')" "and no state"
	assert_eq 0 "$(q '.[0].rank')" "and rank 0"
}

test_inventory_detects_claude_by_version_command() {
	# claude execs a per-release binary, so ps and tmux see "2.1.238". The
	# marked title is what separates it from any other versioned binary.
	local pane
	pane=$(fake_agent 2.1.238)
	tm select-pane -t "$pane" -T '✻ Refactoring the parser'
	assert_eq claude "$(pq "$pane" .agent)" "version command + marked title is claude"
	assert_eq "Refactoring the parser" "$(pq "$pane" .summary)" "summary strips the marker glyph"
}

test_inventory_version_command_without_marked_title_is_not_an_agent() {
	local pane
	pane=$(fake_agent 2.1.238)
	tm select-pane -t "$pane" -T 'some-versioned-tool'
	assert_eq null "$(pq "$pane" .agent)" "a versioned binary alone is not an agent"
}

test_inventory_detects_codex_by_command_name() {
	local pane
	pane=$(fake_agent codex)
	assert_eq codex "$(pq "$pane" .agent)" "codex is detected by command name"
}

test_inventory_reported_agent_survives_a_shell_pane() {
	# The record is authoritative for identity even when the process is gone;
	# only the *state* is withdrawn.
	corral report --pane %0 --agent claude --state working --session-id sid-1
	assert_eq claude "$(pq %0 .agent)" "identity comes from the record"
	assert_eq true "$(pq %0 .exited)" "a shell in the foreground means the agent left"
	assert_eq null "$(pq %0 .state)" "so its last state is withdrawn, not reported"
	assert_eq 0 "$(pq %0 .rank)" "and it sorts below everything"
}

test_inventory_state_is_kept_while_the_agent_runs() {
	local pane
	pane=$(fake_agent 2.1.238)
	corral report --pane "$pane" --agent claude --state working --detail 'building'
	assert_eq working "$(pq "$pane" .state)" "state survives while the process is up"
	assert_eq false "$(pq "$pane" .exited)" "not exited"
	assert_eq api "$(pq "$pane" .state_source)" "an api write is labelled api"
}

test_inventory_stale_only_counts_silence_not_duration() {
	local pane now
	pane=$(fake_agent 2.1.238)
	now=$(date +%s)
	corral report --pane "$pane" --agent claude --state working
	# A genuinely long turn: started hours ago, but still talking.
	tm set -p -t "$pane" @corral_since "$((now - 7200))"
	assert_eq false "$(pq "$pane" .stale)" "a long turn that keeps reporting is not stale"
	# Killed mid-turn: nothing has arrived in hours.
	tm set -p -t "$pane" @corral_seen_at "$((now - 7200))"
	assert_eq true "$(pq "$pane" .stale)" "silence past CORRAL_STALE_SECS is stale"
}

test_inventory_sorts_loudest_first() {
	local a b c
	a=$(fake_agent codex); b=$(fake_agent gemini); c=$(fake_agent amp)
	corral report --pane "$a" --agent codex --state working
	corral report --pane "$b" --agent gemini --state blocked
	corral report --pane "$c" --agent amp --state idle
	assert_eq "$b" "$(q '.[0].pane_id')" "blocked sorts first"
	assert_eq "$a" "$(q '.[1].pane_id')" "then working"
}

# ===========================================================================
# report: the ingest point, and the identity rules that guard a restore
# ===========================================================================

test_report_without_a_session_id_writes_no_record() {
	local pane
	pane=$(fake_agent 2.1.238)
	corral report --pane "$pane" --agent claude --state working
	assert_eq working "$(pq "$pane" .state)" "state still lands in tmux"
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "but nothing durable is written"
}

test_report_from_a_scan_never_writes_identity() {
	# The regression this guards: an ungated session-id fallback let one
	# `corral scan` stamp every pane on the machine with the scanning session's
	# id, so a reboot would have resumed the same conversation five times.
	local pane
	pane=$(fake_agent 2.1.238)
	corral report --pane "$pane" --agent claude --state working \
		--source scan --session-id scanner-session
	assert_eq scan "$(pq "$pane" .state_source)" "the state is attributed to the scan"
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "a scan writes no restore record"
}

test_report_env_session_id_fallback_is_gated_to_hooks() {
	local pane
	pane=$(fake_agent 2.1.238)
	# No --event: this is some shell that happens to have the variable set.
	CLAUDE_CODE_SESSION_ID=ambient-session \
		corral report --pane "$pane" --agent claude --state working
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "an ambient env id is not identity"
	# With --event it is a hook speaking for its own session, and it counts.
	CLAUDE_CODE_SESSION_ID=hook-session \
		corral report --pane "$pane" --agent claude --state working --event UserPromptSubmit
	assert_eq hook-session "$(pq "$pane" .session_id)" "a hook's env id is identity"
}

test_report_merges_rather_than_overwrites_the_record() {
	local pane p
	pane=$(fake_agent 2.1.238)
	p=$WORLD/payload.json
	printf '{"session_id":"sid-9","transcript_path":"/tmp/t.jsonl","cwd":"/tmp"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state idle --event SessionStart --payload "$p"
	assert_eq /tmp/t.jsonl "$(pq "$pane" .transcript)" "SessionStart carries the transcript"
	# A later event for the same session has no transcript in it; the record
	# must not be blanked, or restore has nothing to validate against.
	printf '{"session_id":"sid-9","message":"Claude needs your permission to run rm"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state blocked --event Notification --payload "$p"
	assert_eq /tmp/t.jsonl "$(pq "$pane" .transcript)" "a later event keeps it"
	assert_eq sid-9 "$(pq "$pane" .session_id)" "and the session id"
}

test_report_new_session_in_the_same_pane_drops_the_old_record() {
	local pane p
	pane=$(fake_agent 2.1.238)
	p=$WORLD/payload.json
	printf '{"session_id":"old","transcript_path":"/tmp/old.jsonl"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state idle --event SessionStart --payload "$p"
	printf '{"session_id":"new"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state idle --event SessionStart --payload "$p"
	assert_eq new "$(pq "$pane" .session_id)" "the new session owns the pane"
	assert_eq null "$(pq "$pane" .transcript)" "the old session's transcript does not carry over"
}

test_report_notification_splits_blockers_from_nudges() {
	# Claude fires Notification both for "I need permission" (a blocker) and
	# for "I have been waiting" (a nudge at an already-idle pane). Mapping both
	# to blocked pinned finished panes at blocked for 19 hours.
	local pane p
	pane=$(fake_agent 2.1.238)
	p=$WORLD/payload.json
	corral report --pane "$pane" --agent claude --state "done"
	printf '{"message":"Claude is waiting for your input"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state blocked --event Notification --payload "$p"
	assert_eq "done" "$(pq "$pane" .state)" "a nudge leaves the state alone"
	assert_contains "$(pq "$pane" .detail)" waiting "but its text still lands"
	printf '{"message":"Claude needs your permission to use Bash"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state blocked --event Notification --payload "$p"
	assert_eq blocked "$(pq "$pane" .state)" "a permission prompt is a blocker"
}

test_report_payload_with_only_a_message_does_not_shift_fields() {
	# The payload's four fields are joined on US, not tab: `read` treats tab as
	# whitespace and would collapse three empty leading fields, landing the
	# message in session_id.
	local pane p
	pane=$(fake_agent 2.1.238)
	p=$WORLD/payload.json
	printf '{"message":"needs your permission"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state blocked --event Notification --payload "$p"
	assert_eq null "$(pq "$pane" .session_id)" "no session id was invented"
	assert_contains "$(pq "$pane" .detail)" permission "the message landed as the detail"
}

test_report_ignores_subagent_events() {
	local pane p
	pane=$(fake_agent 2.1.238)
	p=$WORLD/payload.json
	printf '{"session_id":"sub-1","agent_id":"agent_abc"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state working --event SessionStart --payload "$p"
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "a subagent does not claim the pane"
	assert_eq null "$(pq "$pane" .state)" "nor set its state"
}

test_report_gone_clears_the_pane() {
	local pane p
	pane=$(fake_agent 2.1.238)
	p=$WORLD/payload.json
	printf '{"session_id":"sid-x","transcript_path":"/tmp/x.jsonl"}\n' >"$p"
	corral report --pane "$pane" --agent claude --state idle --event SessionStart --payload "$p"
	corral report --pane "$pane" --agent claude --state gone --event SessionEnd
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "SessionEnd drops the record"
	assert_eq null "$(pq "$pane" .state)" "and the state"
	assert_eq null "$(pq "$pane" .agent)" "and the identity"
}

test_report_rolls_state_up_to_the_window() {
	local pane
	pane=$(fake_agent codex)
	corral report --pane "$pane" --agent codex --state working
	assert_eq working "$(tm display-message -p -t "$pane" '#{@corral_win_state}')" "window shows working"
	corral report --pane "$pane" --agent codex --state blocked
	assert_eq blocked "$(tm display-message -p -t "$pane" '#{@corral_win_state}')" "loudest pane wins the window"
}

test_report_for_an_unknown_pane_is_a_no_op() {
	corral report --pane %99 --agent claude --state working --session-id ghost
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "a pane that does not exist writes nothing"
}

# ===========================================================================
# seen / refresh / gc
# ===========================================================================

test_seen_clears_a_done_badge_only() {
	local pane
	pane=$(fake_agent 2.1.238)
	corral report --pane "$pane" --agent claude --state "done"
	corral seen "$pane"
	assert_eq idle "$(pq "$pane" .state)" "looking at a finished pane clears the badge"
	corral report --pane "$pane" --agent claude --state working
	corral seen "$pane"
	assert_eq working "$(pq "$pane" .state)" "but a working pane is left alone"
}

test_refresh_forgets_a_pane_whose_agent_died() {
	local pane
	pane=$(fake_agent 2.1.238)
	corral report --pane "$pane" --agent claude --state working --session-id sid-dead \
		--event SessionStart
	assert_eq 1 "$(ls -1 "$PANES" | wc -l | tr -d ' ')" "the record exists while it runs"
	# Kill the agent; the pane falls back to its shell, which is the only tell.
	tm send-keys -t "$pane" C-c
	local _i
	for _i in 1 2 3 4 5 6 7 8 9 10; do
		[[ $(tm display-message -p -t "$pane" '#{pane_current_command}') != 2.1.238 ]] && break
		sleep 0.2
	done
	corral refresh
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "refresh drops the record"
	assert_eq null "$(pq "$pane" .agent)" "and the identity"
	assert_eq "" "$(tm display-message -p -t "$pane" '#{@corral_state}')" "and the stale state"
}

test_gc_drops_records_from_a_previous_tmux_server() {
	# Pane ids restart at %0 with each server, so a record from the last one
	# would mislabel a brand new pane.
	mkdir -p "$PANES"
	printf '{"schema":1,"pane_id":"%%0","agent":"claude","session_id":"old","server_pid":1}\n' \
		>"$PANES/pane-0.json"
	corral gc
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "a foreign server_pid is dropped"
}

test_gc_drops_records_for_panes_that_are_gone() {
	local pane
	pane=$(fake_agent 2.1.238)
	corral report --pane "$pane" --agent claude --state idle --session-id sid-g --event SessionStart
	assert_eq 1 "$(ls -1 "$PANES" | wc -l | tr -d ' ')" "record written"
	tm kill-window -t "$pane"
	corral gc
	assert_empty "$(ls -1 "$PANES" 2>/dev/null)" "the record goes with the pane"
}

test_gc_drops_pid_cache_entries_for_dead_processes() {
	mkdir -p "$STATE/pidpane"
	printf '%%0\n' >"$STATE/pidpane/999999"
	printf '%%0\n' >"$STATE/pidpane/$$"
	printf '%%0\n' >"$STATE/pidpane/not-a-pid"
	corral gc
	[[ -e $STATE/pidpane/999999 ]] && fail "dead pid entry should be gone"
	[[ -e $STATE/pidpane/not-a-pid ]] && fail "junk entry should be gone"
	[[ -e $STATE/pidpane/$$ ]] || fail "live pid entry should survive"
}

# ===========================================================================
# scan: reading the pane for agents that cannot report
# ===========================================================================

test_scan_reads_the_title() {
	local pane
	pane=$(fake_agent codex)
	tm select-pane -t "$pane" -T 'Action Required'
	corral scan
	assert_eq blocked "$(pq "$pane" .state)" "codex's title says it wants you"
	assert_eq scan "$(pq "$pane" .state_source)" "attributed to the scan"
}

test_scan_reads_the_screen_when_the_title_cannot_say() {
	local pane
	pane=$(fake_agent codex "printf 'Allow command?\\n'")
	corral scan
	assert_eq blocked "$(pq "$pane" .state)" "an approval prompt on screen is a blocker"
}

test_scan_never_contradicts_a_live_hook() {
	local pane
	pane=$(fake_agent codex)
	tm select-pane -t "$pane" -T 'Action Required'
	corral report --pane "$pane" --agent codex --state working --event PostToolUse --source hook
	corral scan
	assert_eq working "$(pq "$pane" .state)" "a talking agent outranks the screen"
	# ...but a silent one can be corrected.
	tm set -p -t "$pane" @corral_seen_at "$(($(date +%s) - 99999))"
	corral scan
	assert_eq blocked "$(pq "$pane" .state)" "a hook gone quiet past the stale window can be"
}

test_scan_dry_run_changes_nothing() {
	local pane out
	pane=$(fake_agent codex)
	tm select-pane -t "$pane" -T 'Action Required'
	out=$(corral scan --dry-run)
	assert_contains "$out" blocked "the dry run says what it would do"
	assert_eq null "$(pq "$pane" .state)" "and does not do it"
}

test_scan_skips_panes_with_no_agent() {
	tm select-pane -t %0 -T 'Action Required'
	corral scan
	assert_eq null "$(pq %0 .state)" "a shell pane is not scanned"
}

# ===========================================================================
# save / restore
# ===========================================================================

seed_agent_with_identity() { # -> pane id, on stdout
	local pane p
	pane=$(fake_agent 2.1.238)
	tm select-pane -t "$pane" -T '✻ Wiring the tests'
	p=$WORLD/seed.json
	printf '{"session_id":"sid-restore","transcript_path":"%s","cwd":"%s"}\n' \
		"$WORLD/transcript.jsonl" "$PWD" >"$p"
	: >"$WORLD/transcript.jsonl"
	corral report --pane "$pane" --agent claude --state working --event SessionStart --payload "$p"
	printf '%s\n' "$pane"
}

test_save_snapshots_the_resumable_panes() {
	local pane file
	pane=$(seed_agent_with_identity)
	file=$(corral save)
	assert_eq 1 "$(jq '[.panes[] | select(.session_id != null)] | length' "$file")" "one resumable pane"
	assert_eq "$(readlink "$SNAPS/last")" "$file" "last points at it"
	assert_eq sid-restore "$(jq -r '.panes[] | select(.session_id) | .session_id' "$file")" "with its session id"
}

test_restore_dry_run_builds_the_resume_command() {
	local pane out
	pane=$(seed_agent_with_identity)
	corral save >/dev/null
	out=$(corral restore --dry-run)
	assert_contains "$out" "claude --resume sid-restore" "resumes the right conversation"
	assert_contains "$out" "--test-flag" "with the configured flags"
}

test_restore_types_the_command_into_the_pane() {
	local pane out
	pane=$(seed_agent_with_identity)
	corral save >/dev/null
	# Put a shell back in the pane, the way a resurrect restore would.
	tm send-keys -t "$pane" C-c
	local _i
	for _i in 1 2 3 4 5 6 7 8 9 10; do
		[[ $(tm display-message -p -t "$pane" '#{pane_current_command}') != 2.1.238 ]] && break
		sleep 0.2
	done
	# stage: type it, do not press Enter — the assertion can read it off screen
	# and nothing actually launches.
	CORRAL_RESTORE=stage corral restore
	out=$(tm capture-pane -p -t "$pane")
	assert_contains "$out" "claude --resume sid-restore" "the command is sitting on the prompt"
	assert_eq 1 "$(tm display-message -p -t "$pane" '#{@corral_restored}')" "the pane is marked handled"
	# A second pass must not type it twice.
	CORRAL_RESTORE=stage corral restore
	assert_contains "$(cat "$STATE/corral.log")" "already handled" "a second run skips it"
}

test_restore_will_not_fall_back_to_the_active_pane() {
	# tmux resolves a target with a stale window index to the session's active
	# pane rather than failing, which would replay somebody else's conversation
	# into whatever pane happens to be current.
	local out
	mkdir -p "$SNAPS"
	jq -n --arg cwd "$PWD" '{schema:1, saved_at:"x", panes:[
		{target:"t:9.9", agent:"claude", session_id:"sid-ghost", cwd:$cwd,
		 transcript:null, summary:"ghost"}]}' >"$SNAPS/corral_ghost.json"
	ln -sfn "$SNAPS/corral_ghost.json" "$SNAPS/last"
	out=$(corral restore --dry-run)
	assert_empty "$out" "a target that no longer exists is skipped, not guessed"
}

test_restore_skips_a_pane_whose_cwd_moved() {
	local pane out
	pane=$(seed_agent_with_identity)
	corral save >/dev/null
	# Rewrite the snapshot's cwd: the pane is no longer where the conversation was.
	jq '(.panes[] | select(.session_id) | .cwd) = "/somewhere/else"' "$SNAPS/last" >"$WORLD/s.json"
	out=$(corral restore --dry-run --snapshot "$WORLD/s.json")
	assert_empty "$out" "a moved pane is not resumed into"
	assert_contains "$(cat "$STATE/corral.log")" "cwd is" "and it says why"
}

test_restore_skips_a_claude_whose_transcript_is_gone() {
	local pane out
	pane=$(seed_agent_with_identity)
	corral save >/dev/null
	rm -f "$WORLD/transcript.jsonl"
	out=$(corral restore --dry-run)
	assert_empty "$out" "--resume would fail on a dropped session"
	assert_contains "$(cat "$STATE/corral.log")" "transcript gone" "and it says why"
}

test_restore_skips_an_agent_with_no_resume_recipe() {
	local out
	mkdir -p "$SNAPS"
	jq -n --arg cwd "$PWD" '{schema:1, saved_at:"x", panes:[
		{target:"t:0.0", agent:"gemini", session_id:"sid-g", cwd:$cwd,
		 transcript:null, summary:"x"}]}' >"$SNAPS/last.json"
	ln -sfn "$SNAPS/last.json" "$SNAPS/last"
	out=$(corral restore --dry-run)
	assert_empty "$out" "no recipe, no resume"
	assert_contains "$(cat "$STATE/corral.log")" "no resume recipe" "and it says why"
}

test_restore_off_does_nothing() {
	local pane
	pane=$(seed_agent_with_identity)
	corral save >/dev/null
	tm send-keys -t "$pane" C-c
	sleep 0.5
	CORRAL_RESTORE=off corral restore
	assert_contains "$(cat "$STATE/corral.log")" "CORRAL_RESTORE=off" "off is honoured"
	assert_empty "$(tm capture-pane -p -t "$pane" | grep -c 'claude --resume' | grep -v '^0$')" "nothing was typed"
}

# ===========================================================================
# corral-hook: who is allowed to speak for a pane
# ===========================================================================

# Run a command inside a pane and wait for the pane options to settle.
in_pane() { # pane command...
	local pane=$1; shift
	tm send-keys -t "$pane" "$*" Enter
	sleep 0.6
}

test_hook_maps_events_to_states() {
	local pane
	pane=$(fake_agent 2.1.238)
	# The hook has to run as a direct child of the pane's own process, so drive
	# it from pane %0, whose shell *is* the pane process.
	in_pane %0 'corral-hook claude UserPromptSubmit </dev/null'
	assert_eq working "$(tm display-message -p -t %0 '#{@corral_state}')" "UserPromptSubmit is working"
	assert_eq hook "$(tm display-message -p -t %0 '#{@corral_source}')" "and is attributed to the hook"
	in_pane %0 'corral-hook claude Stop </dev/null'
	assert_eq "done" "$(tm display-message -p -t %0 '#{@corral_state}')" "Stop is done"
}

test_hook_ignores_events_it_does_not_map() {
	in_pane %0 'corral-hook claude SubagentStop </dev/null'
	assert_eq "" "$(tm display-message -p -t %0 '#{@corral_state}')" "SubagentStop is deliberately unmapped"
}

test_hook_accepts_a_direct_child_of_the_pane_process() {
	# The branch every real agent takes. The pane runs a shell; claude is a
	# child of it, so the hook's $PPID is not the pane process itself and
	# ownership has to be settled by walking one link up. Simulated with an
	# intermediate
	# sh, which sits exactly where claude sits; the trailing `true` stops the
	# shell from exec'ing the hook and collapsing the extra level away.
	in_pane %0 'sh -c '\''corral-hook claude UserPromptSubmit </dev/null; true'\'
	assert_eq working "$(tm display-message -p -t %0 '#{@corral_state}')" "a direct child speaks for the pane"
}

test_hook_refuses_to_speak_for_a_pane_it_does_not_own() {
	# A nested agent is a grandchild of the pane process. Its events would
	# otherwise report the pane as working while the session on screen is idle.
	in_pane %0 'sh -c '\''sh -c "corral-hook claude UserPromptSubmit </dev/null"; true'\'
	assert_eq "" "$(tm display-message -p -t %0 '#{@corral_state}')" "a grandchild stays quiet"
}

test_hook_hot_path_only_writes_on_a_transition() {
	local since1 since2
	in_pane %0 'corral-hook claude PreToolUse </dev/null'
	since1=$(tm display-message -p -t %0 '#{@corral_since}')
	sleep 1.2
	in_pane %0 'corral-hook claude PostToolUse </dev/null'
	since2=$(tm display-message -p -t %0 '#{@corral_since}')
	assert_eq "$since1" "$since2" "the same state does not restamp @corral_since"
	in_pane %0 'corral-hook claude Stop </dev/null'
	[[ $(tm display-message -p -t %0 '#{@corral_since}') != "$since1" ]] ||
		fail "a real transition should restamp @corral_since"
}

# ===========================================================================

TESTS=(
	inventory_plain_shell_has_no_agent
	inventory_detects_claude_by_version_command
	inventory_version_command_without_marked_title_is_not_an_agent
	inventory_detects_codex_by_command_name
	inventory_reported_agent_survives_a_shell_pane
	inventory_state_is_kept_while_the_agent_runs
	inventory_stale_only_counts_silence_not_duration
	inventory_sorts_loudest_first
	report_without_a_session_id_writes_no_record
	report_from_a_scan_never_writes_identity
	report_env_session_id_fallback_is_gated_to_hooks
	report_merges_rather_than_overwrites_the_record
	report_new_session_in_the_same_pane_drops_the_old_record
	report_notification_splits_blockers_from_nudges
	report_payload_with_only_a_message_does_not_shift_fields
	report_ignores_subagent_events
	report_gone_clears_the_pane
	report_rolls_state_up_to_the_window
	report_for_an_unknown_pane_is_a_no_op
	seen_clears_a_done_badge_only
	refresh_forgets_a_pane_whose_agent_died
	gc_drops_records_from_a_previous_tmux_server
	gc_drops_records_for_panes_that_are_gone
	gc_drops_pid_cache_entries_for_dead_processes
	scan_reads_the_title
	scan_reads_the_screen_when_the_title_cannot_say
	scan_never_contradicts_a_live_hook
	scan_dry_run_changes_nothing
	scan_skips_panes_with_no_agent
	save_snapshots_the_resumable_panes
	restore_dry_run_builds_the_resume_command
	restore_types_the_command_into_the_pane
	restore_will_not_fall_back_to_the_active_pane
	restore_skips_a_pane_whose_cwd_moved
	restore_skips_a_claude_whose_transcript_is_gone
	restore_skips_an_agent_with_no_resume_recipe
	restore_off_does_nothing
	hook_maps_events_to_states
	hook_ignores_events_it_does_not_map
	hook_accepts_a_direct_child_of_the_pane_process
	hook_refuses_to_speak_for_a_pane_it_does_not_own
	hook_hot_path_only_writes_on_a_transition
)

command -v tmux >/dev/null || { echo "corral tests need tmux"; exit 2; }
command -v jq >/dev/null || { echo "corral tests need jq"; exit 2; }

printf 'corral tests (tmux %s)\n\n' "$(tmux -V | awk '{print $2}')"
for t in "${TESTS[@]}"; do run_test "$t"; done

printf '\n%d passed, %d failed' "$PASS" "$FAIL"
((SKIP)) && printf ', %d skipped' "$SKIP"
printf '\n'
if ((FAIL)); then
	printf 'failed: %s\n' "${FAILED_NAMES[*]}"
	exit 1
fi
