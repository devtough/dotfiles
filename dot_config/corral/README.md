# corral

What is running in every tmux pane on this machine, and how the agents get back
after a reboot.

`corral` is the tracking layer only. It collects state and answers questions
(`corral list --json`); it deliberately draws nothing. A status-bar glyph, an
fzf picker and a live sidebar are three renderers over the same JSON, and
tmux.conf carries a ready-to-uncomment line for each.

## The pieces

    ~/.local/bin/corral          the CLI: inventory, scan, snapshot, restore
    ~/.local/bin/corral-hook     the fast path agents call on every event
    ~/.config/corral/config.sh   knobs (env > this file > built-in defaults)
    ~/.config/corral/rules.json  title/screen rules for agents without hooks
    ~/.local/state/corral/       records, snapshots, log

Wiring lives in three places, all installed already:

    ~/.claude/settings.json   7 hook events -> corral-hook claude <Event>
    ~/.codex/hooks.json       SessionStart -> corral-hook codex SessionStart
    ~/.config/tmux/tmux.conf   resurrect save/restore hooks, pane-focus-in,
                               pane-exited

`corral doctor` checks all of it and prints the current inventory.

## Where state lives, and why it is split

**tmux pane options** — `@corral_state`, `@corral_since`, `@corral_seen_at`,
`@corral_agent`, `@corral_detail`, `@corral_session`, plus a per-window
`@corral_win_state` aggregate. Volatile, written by the hook on every transition, gone when the
server dies — which is correct, because "working" means nothing after a reboot.
tmux formats read these directly, so a status-bar glyph costs zero processes:

    #{?#{==:#{@corral_win_state},blocked}, ▲,}

**`~/.local/state/corral/panes/pane-<n>.json`** — the durable record: agent,
session id, transcript path, cwd, coordinates, tmux server pid. Written only
when a session starts or ends. It carries the server pid because pane ids (`%7`)
are unique only within one tmux server and start over at `%0` after a restart;
`corral gc` drops records from dead servers so a stale one cannot mislabel a new
pane.

**`~/.local/state/corral/restore/corral_<stamp>.json`** — a snapshot keyed by
`session:window.pane`, written from resurrect's `post-save-all` hook so it and
resurrect's dump describe the same instant. `last` symlinks to the newest.

## States

    ▲ blocked   agent is waiting on you (permission prompt, question)
    ✓ done      turn finished, not looked at yet — clears on pane-focus-in
    ● working   prompt submitted, or tools running
    ○ idle      session alive, nothing in flight
    ·           no agent, or state unknown

A `~` after the state means corral inferred it from the pane rather than
hearing it from the agent (see below); a `!` means the state is stale.

Not every Notification is a blocker. Claude Code fires the same event for "I
need permission to run X" and for "I have been waiting for your input", and
mapping both to blocked pins a finished pane at blocked forever, because
nothing else fires until you type. corral classifies on the message text and
lets the second kind pass through without touching the state.

Ranking is `blocked > done > working > idle`, which is the order `corral list`
sorts in: the loudest thing is always the top row.

Two timestamps, answering different questions. `@corral_since` is when the state
last changed, and it is what the AGE column shows — "working for 40 minutes".
`@corral_seen_at` is when an event last arrived, refreshed at most once a minute
so a chatty turn costs no extra tmux round trips. Staleness keys off the second
one: a `!` means nothing has been heard for `CORRAL_STALE_SECS`, so the state on
screen is probably a lie. Without that split, every genuinely long turn would
look identical to an agent killed mid-tool-call.

## Why restore needs its own records

tmux-resurrect saves the pane tree and each pane's cwd, and continuum replays it
when the server starts. That is enough for a shell and not enough for an agent:
Claude Code rewrites its argv to a bare `claude`, so neither `ps` nor the
resurrect dump records *which conversation* the pane was holding, and three
panes sharing `~` cannot be told apart by `claude --continue`.

So corral records the session id per pane while the agent runs, and after
resurrect finishes it types `claude --resume <id>` into the pane that came back
at the same coordinates. Before it does, it checks that the pane exists (by
exact match — tmux resolves a stale target to the session's *active* pane rather
than failing), that its cwd is the one that was saved, that the transcript file
still exists, and that a shell has actually reached a prompt there. Anything
that fails is skipped with a reason in `~/.local/state/corral/corral.log`.

Identity comes from hooks and from nothing else. Reading the session id out of
the agent's own process environment looks tempting and is wrong: a process shows
what it *inherited*, so every claude on this machine reports the id of whichever
session started the tmux server. Inferring it from the ambient environment is
worse — an ungated fallback let one `corral scan` stamp all five panes with the
scanning session's id, which would have resumed the same conversation five times
after a reboot. A pane with no hook-reported identity is simply not resumable
until its next SessionStart, and `corral restore` says so rather than guessing.

The one thing that cannot be observed is the flags the agent was started with —
the process title is rewritten, so they are gone by save time. They are declared
once in `config.sh` as `CORRAL_CLAUDE_FLAGS`.

Set `CORRAL_RESTORE` to choose what a restore does: `auto` types the command and
presses Enter, `stage` leaves it on the prompt for you, `off` only logs. Dry-run
any snapshot without touching a pane:

    corral restore --dry-run

## Agents that cannot report for themselves

codex exposes only SessionStart, so it can say who it is but never what it is
doing, and most other agents say nothing at all. `corral scan` closes that gap
by reading the pane, using rules in `rules.json` ported from herdr's detection
set (`~/.local/state/herdr/agent-detection/remote/*.toml` — herdr versions and
updates those, so check there first when an agent changes its UI).

The cheap half of the trick is the OSC title: tmux hands it over as
`#{pane_title}`, so a codex pane costs no `capture-pane` at all. codex puts a
braille spinner in the title while working and "Action Required" in it when it
wants you; claude marks an idle title with `✳` and swaps in a spinner glyph
while a turn runs. Screen rules cover what a title cannot say — approval
prompts, trust dialogs, an empty prompt box.

Hooks always win. `corral scan` skips any pane whose state came from its own
agent unless that agent has gone quiet past `CORRAL_STALE_SECS`, so a scan can
correct a killed agent but never contradict a live one. Every state carries its
provenance in `@corral_source` and in the JSON as `state_source`.

    corral scan --dry-run          # what it would change, and which rule fired
    corral scan --pane %7          # one pane

`corral refresh` runs a scan as part of reconciling, and the `pane-exited` hook
runs `corral refresh`.

## One pane, one voice

A Claude Code subagent, a background job, or a nested session runs *inside* the
pane's agent rather than in the pane. Left alone, their events report the pane
as working while the interactive session sits idle, and their SessionStart
stamps the pane's restore record with the wrong session id — a reboot would then
resume a background job instead of the conversation on screen.

Ownership is decided by process shape: the pane's agent is the pane process
itself, or one of its direct children. A hook whose parent is anything else is
refused, and the verdict is cached under that parent's pid, so it costs one file
read per event.

The tempting shortcut — trusting `CLAUDE_CODE_CHILD_SESSION` in the environment —
was tried here and is wrong. That marker is inherited: tmux on this machine was
started from inside a Claude session, so every agent launched by the `prefix + \`
split binding carries it, and honouring it silenced all five real sessions at
once while leaving genuine background jobs indistinguishable from them. Process
shape cannot be inherited by accident.

Two things process shape cannot see are still checked on the payload: a
subagent's event carries `agent_id`, and codex hands a child its parent's thread
in `CODEX_THREAD_ID` — the same guard herdr's codex integration uses.

## Adding a writer

Anything that can learn a pane's state can report it, and nothing else needs to
change:

    corral report --pane %7 --agent codex --state working --detail "editing"

That is the extension point for agents with no hooks — a poller that reads
`tmux capture-pane -p` and matches patterns (herdr keeps rules for ~20 agents in
`~/.local/state/herdr/agent-detection/`) plugs in here without touching the
readers.

## Coexisting with herdr

herdr wires its own `SessionStart` hook into the same `~/.claude/settings.json`.
`corral install-hooks` appends and never rewrites, is idempotent, and backs the
file up first, so both integrations run side by side.

## Cost

The hot path (`PreToolUse`/`PostToolUse`/`UserPromptSubmit`) is `/bin/sh` and
makes one tmux round trip: it reads state, liveness and the pane's session id
together, and writes only on a real state change or once a minute to re-stamp
liveness. Order 10ms, no disk, no jq. `SessionStart`, `Notification` and
`SessionEnd` are rare and parse the payload every time.

The one exception on the hot path is identity, and it is worth the exception.
Every Claude Code event carries `session_id`, `transcript_path` and `cwd` — not
just `SessionStart` — so when that third field comes back empty the hook hands
the payload to `corral report` and the pane registers itself. It costs one fork
that the old `cat >/dev/null` was paying anyway, it happens at most once per
session per pane, and without it a pane could only ever acquire an identity in
the instant its agent started. An agent already running when the hooks were
installed, or while they were broken, stayed unresumable for the rest of its
life however much work it did. Now any event at all is enough. (`codex` still
is not: it exposes only `SessionStart`, so a codex pane that missed it has to
be restarted.)

## Tests

`tests/corral.sh` in the dotfiles repo, no dependencies beyond tmux and jq:

    tests/corral.sh              # ~25s, 46 tests
    tests/corral.sh restore      # only tests whose name matches
    KEEP=1 tests/corral.sh       # leave each test's temp world behind

Everything corral touches is redirectable, which is what makes an end-to-end
test cheap. Each test gets a tmux server of its own on a socket inside its own
temp dir (`tmux -S "$WORLD/tmux.sock" -f /dev/null`), `$TMUX` pointed at it so
corral and the hooks it spawns find it without a flag, `CORRAL_STATE_DIR` in the
same temp dir, `CORRAL_CONFIG=/dev/null`, and `$PATH` in front of `~/.local/bin`
so the *repo* copies run rather than whatever chezmoi last deployed. Your panes,
records and snapshots are never in scope, and nothing is left in
`/tmp/tmux-$UID`.

Two things the harness has to get right or the tests quietly prove nothing:

* **A fake agent must be a real process, named the way the agent names itself.**
  claude execs a per-release binary, so its `pane_current_command` is a version
  string like `2.1.238`, and that plus a marked pane title is exactly what the
  detection in `inventory` keys on. `fake_agent` copies `sleep` under that name
  (ad-hoc re-signing it, or macOS kills the copy on exec). Report state into a
  pane that is running a bare shell instead and `exited` fires by design, so
  every read comes back `null`.
* **The fake agent runs as a child of the pane's shell, never `exec`'d.** A dead
  agent is supposed to leave a prompt behind — that is corral's only signal that
  it died, and `refresh`, the restore tests and `exited` all turn on it. `exec`
  closes the pane instead, which is a different event entirely.
* **Every pane runs a plain `/bin/sh`, and the environment is built before the
  server starts.** Redirecting `$PATH` in the runner is not enough: an
  interactive zsh sources `~/.zshrc`, which re-prepends `~/.local/bin` and puts
  the *deployed* corral back in front of the repo copy, so pane-side commands
  quietly test the installed binaries and write to the real
  `~/.local/state/corral`. `tmux set-environment` does not save you either — it
  only reaches panes created after the call, and the hook tests drive pane %0.
  Two hook tests passed against the wrong binary before this was pinned down.

The suite also unsets `CLAUDE_CODE_SESSION_ID`, `CLAUDE_CODE_CHILD_SESSION` and
`CODEX_THREAD_ID` before each test: it usually runs from inside an agent pane,
and those are precisely the inherited variables corral is written not to trust.
Left set, the runner's own session id ends up in a fixture's restore record.

What is worth having tests for is the decisions that were reversed at least
once: that a `scan` never writes identity, that the `CLAUDE_CODE_SESSION_ID`
fallback is gated to hook events, that a `Notification` about a permission
prompt is a blocker but one about waiting is not, that a grandchild process does
not get to speak for a pane, that `stale` counts silence rather than duration,
and that `restore` skips a target it cannot resolve exactly instead of letting
tmux fall back to the active pane.

The first thing the suite caught was a live one. `corral-hook` settled pane
ownership with `pgrep -P "$pane_pid" | grep -qx "$PPID"`, and on macOS `pgrep`
omits its own ancestors from the results — `$PPID` is the parent of the shell
that just ran the pgrep, so it was never in the list and the match could never
succeed. Only the `$PPID = $pane_pid` branch worked, which no real agent takes:
a pane runs a shell and the agent is its child. Every agent on this machine was
being disowned, the refusal cached under its pid for the life of the process,
and the result looked like corral working — `corral list` was full, because
`scan` was reading the screen — while no pane had an identity and
`corral restore --dry-run` printed nothing. The check now asks who `$PPID`'s
parent is, which is the same question and one `ps` call.
