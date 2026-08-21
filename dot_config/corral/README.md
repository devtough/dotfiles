# corral

What is running in every tmux pane on this machine, and how the agents get back
after a reboot.

`corral` is the tracking layer only. It collects state and answers questions
(`corral list --json`); it deliberately draws nothing. A status-bar glyph, an
fzf picker and a live sidebar are three renderers over the same JSON, and
tmux.conf carries a ready-to-uncomment line for each.

## The pieces

    ~/.local/bin/corral          the CLI: inventory, snapshot, restore, doctor
    ~/.local/bin/corral-hook     the fast path agents call on every event
    ~/.config/corral/config.sh   knobs (env > this file > built-in defaults)
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

The one thing that cannot be observed is the flags the agent was started with —
the process title is rewritten, so they are gone by save time. They are declared
once in `config.sh` as `CORRAL_CLAUDE_FLAGS`.

Set `CORRAL_RESTORE` to choose what a restore does: `auto` types the command and
presses Enter, `stage` leaves it on the prompt for you, `off` only logs. Dry-run
any snapshot without touching a pane:

    corral restore --dry-run

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
makes one tmux round trip: it reads state and liveness together, and writes only
on a real state change or once a minute to re-stamp liveness. Order 10ms, no
disk, no jq. `SessionStart`, `Notification` and `SessionEnd` are rare and are the
only events that parse the payload or touch a file.
