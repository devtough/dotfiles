# corral

What is running in every tmux pane on this machine, and how the agents get back
after a reboot.

`corral` is the tracking layer. It collects state and answers questions
(`corral list --json`), and it draws exactly one thing: the rollup, a single
status-bar segment for every agent on the machine. Everything else — a
per-window glyph, an fzf picker, a live sidebar — is a renderer over the same
JSON, and tmux.conf carries a ready-to-uncomment line for each.

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
                               pane-exited, and the rollup segment

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
    ✓ done      turn finished, not looked at yet — cleared by being seen
    ● working   prompt submitted, or tools running
    ■ idle      session alive, nothing in flight
    ·           no agent, or state unknown

"Seen" is any of three things: focusing the pane (`pane-focus-in`), the pane
being on screen at the moment the turn ends (the hook writes idle instead of
done — a finish you watched happen was never unread), or the refresh sweep
noticing a done pane is visible, which catches the cases with no hook to fire:
switching into the window onto a sibling pane, or attaching the session.

A `~` after the state means corral inferred it from the pane rather than
hearing it from the agent (see below); a `!` means the state is stale, which
only ever applies to `working` (see "Blocked is never stale").

Not every Notification is a blocker. Claude Code fires the same event for "I
need permission to run X" and for "I have been waiting for your input", and
mapping both to blocked pins a finished pane at blocked forever, because
nothing else fires until you type. corral classifies on the message text and
lets the second kind pass through without touching the state.

Ranking is `blocked > done > working > idle`, which is the order `corral list`
sorts in: the loudest thing is always the top row, and the order the rollup
renders its counts in.

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

## The rollup

One segment on the status bar — leftmost on the right side, before CPU/RAM —
for every agent on the machine:

    ✓0   ▲1   ●2  ■6
    └──────┘  └─────┘
     queue     ambient (■ is the total: every agent pane, idle included)

A fixed strip, always visible, zeros and all. `⚠n` (stale) joins the ambient
side only when non-zero.

Server-wide, not per-window, because the point of it is that you do not have to
be in the right window — or the right session — to know an agent wants you. It
counts panes, not agents by name: claude and codex land in the same buckets,
because what you act on is "something is blocked", not "a codex is blocked".

Two kinds of information live here, and they are not drawn alike.

**The work queue — `✓ done` and `▲ blocked` — is what you act on.** Blocked is an
agent stalled on you. Done is a turn that finished and has not been read: it
clears on `pane-focus-in`, so the count is a genuine unread queue rather than a
snapshot. At zero these sit dim like everything else; the moment they count
something they become filled blocks — dark text on solid colour. A block is
loud in a way a coloured glyph on the bar background simply is not, and that
flip from dim zero to filled block is what the strip wants you to notice.

**The ambient counts — `● working`, `■ total`, and `⚠ stale` — answer "is
anything running", not "what should I do next".** They stay flat so they cannot
compete with the queue; `●` brightens a step when non-zero, `■` is dim at any
value.

Three things it deliberately does.

**Keeps a fixed shape.** Always `✓ ▲ ● ■`, in that order, all four visible even
at zero. An earlier design showed nothing at all when nothing needed you, and
named the waiting target instead of counting when one or two things waited —
both dropped: a segment that is sometimes absent and sometimes a different
shape cannot be tracked at a glance, and the change you would have missed is
exactly the one it exists to show. Change is the signal now — a slot ticking
0 → 1 — and "where" is the picker's job (`prefix + a`).

**Counts idle in one place only.** `■` is every agent pane on the server, idle
included — "how many agents do I have open", not "what needs me". Idle appears
nowhere else: it is the resting state of every pane that is not doing anything,
so any per-state idle count would be the largest and least meaningful number on
the bar.

**Splits stale out of working.** A pane whose agent was killed keeps its last
state, and folding those into `●` is how an indicator earns a permanent phantom
"1" that trains you to ignore it. `⚠` is a different action anyway: not "wait",
but "go look at that pane". It stays on the ambient side, though — nothing is
waiting on you — just louder than working. It is also the one slot that appears
only when non-zero: it is an anomaly flag, not a routine count, and a permanent
`⚠0` would wear out the one glyph that must always mean "go look".

### Blocked is never stale

Staleness applies to `working` alone. Being silent is what blocked *is*: the
agent fired one Notification and has nothing further to send until you answer
it. Ageing that into "stale" meant the longest-waiting, most urgent pane on the
machine quietly reclassified itself as probably-dead at the `CORRAL_STALE_SECS`
mark and dropped out of the queue — exactly backwards. A blocked pane whose
agent really did die is caught by `corral scan` reading the screen, or by
`corral refresh` seeing a shell back in the foreground; neither needs a timer.

### Where, not just what

The rollup tells you something needs you. Two surfaces answer where, and they
cover different ground:

    window list       #{E:@corral_win_glyph} puts the same ▲/✓/● glyph on each
                      window. Pure format, no polling — every state write
                      already rolls the loudest pane in a window up into
                      @corral_win_state. Only covers the session you are in.

    the picker        popup over `corral list --agents`, which is already
                      sorted blocked > done > working > idle, so the loudest
                      pane is under the cursor when it opens. Previews the pane
                      before you jump. Crosses sessions, which the window list
                      cannot. Opened by `prefix + a`, or by clicking the strip
                      itself — the #[range=user|corral] markers around the
                      strip are what let the status-line mouse binding tell a
                      click on the strip from a click on CPU/RAM. Rows carry
                      the same glyphs as the strip (■ marks idle).

The window glyph has no `⚠`: `@corral_win_state` is written by the hook's fast
path, which has no clock to age states against. A window reading `●` may be
stale, and the rollup is where that gets told apart. One occasionally-optimistic
glyph beats teaching the hot path to do arithmetic on every transition.

### Push, and the tick that corrects it

The segment is a plain `#{@corral_rollup}` format, not a `#(corral status)` job.
Reading a tmux option costs no process on redraw and updates the instant the
option is written, for every attached client at once — and `corral-hook` writes
it on the exact transition, so the bar changes as the agent changes rather than
up to a `status-interval` later. Every writer of pane state pushes it, through
the same `refresh_window_state` that rolls state up to the window.

Push alone drifts, and it drifts in exactly the two cases most worth showing. An
agent killed mid-turn stops sending events rather than sending a last one, and
codex exposes only `SessionStart`, so it can say who it is but never what it is
doing. Both are read off the pane by `corral scan` — which nothing ever called
on a schedule. `pane-exited` did, which is to say only when some *other* pane
happened to die, so a dead codex pane could sit on the bar claiming to work for
a day. It did.

The status bar is that schedule:

    set -ag status-right "#(~/.local/bin/corral tick)"

tmux re-runs that every `status-interval` (5s), which is far too often to be
reading panes, so `corral tick` throttles itself to `CORRAL_TICK_SECS` (30s) and
returns after one stamp-file read the rest of the time. Past the interval it
runs the full `corral refresh` — reconcile, scan, gc — and re-derives the rollup
from the inventory, staleness included. It prints nothing, on purpose: anything
it printed would be printed *into the status bar*.

So the two halves answer different questions. Push says "this agent just
changed"; tick says "this agent has stopped saying anything, and that is itself
the news."

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

    tests/corral.sh              # ~35s, 60 tests
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
