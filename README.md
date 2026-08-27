# dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io/). Supports macOS and Linux.

## New System Setup

```bash
chezmoi init --apply https://github.com/devtough/dotfiles.git
```

You'll be asked for a **machine profile** (see [Machines](#machines)). It's stored
in `~/.config/chezmoi/chezmoi.toml` and never asked again. To answer up front, or
to keep the checkout somewhere other than `~/.local/share/chezmoi`:

```bash
chezmoi init --source=~/Projects/dotfiles --promptChoice profile=sonbox
chezmoi apply
```

## Making Changes

Use Claude Code to validate, apply, and commit changes:

```bash
# 1. Edit source files directly in this repo
# 2. Run /apply-config in Claude Code to:
#    - Review pending chezmoi diff
#    - Validate config syntax
#    - Apply changes to system
#    - Commit to git
```

Manual workflow:
```bash
chezmoi edit ~/.zshrc    # edit managed file
chezmoi diff             # preview changes
chezmoi apply            # apply to system
```

Other useful commands:
```bash
chezmoi add ~/.config/foo    # track a new file
chezmoi update               # pull and apply from remote
```

## Security

This repo uses [gitleaks](https://github.com/gitleaks/gitleaks) via [pre-commit](https://pre-commit.com/) to scan for secrets before commits. If `pre-commit` is installed, hooks are set up automatically on first `chezmoi apply`.

To install pre-commit:
```bash
brew install pre-commit   # macOS
pip install pre-commit    # or via pip
```

## What's Included

| Config | rss-mac | sonbox | omarchy |
|--------|---------|--------|---------|
| tmux | Night Owl, `C-a` prefix, vim-tmux-navigator, fzf popups | same, minus the K8/RPK status segments | omarchy palette, `wl-copy` yank |
| ghostty | unmanaged | Rose Pine, `font-size = 15`, XDG path | Night Owl-era base + omarchy palette via `config-file` include |
| herdr | `C-a` prefix, `theme = terminal` + Rose Pine foam accent, git-sync/agent-ctx/tab-numbers plugins | same | same (accent is hardcoded, not the omarchy palette) |
| shell | zsh — oh-my-zsh + powerlevel10k | zsh — minimal, no framework, fzf `^r` | bash — omarchy defaults |
| git | `gh` at the nix path | `gh` at `/opt/homebrew/bin` | `gh` at `/usr/bin` |
| nvim | LazyVim (Dec 2025 state) | LazyVim v16, snacks picker + explorer | LazyVim |
| `lazy-lock.json` | *not deployed* | tracked | *not deployed* |
| ghostty | *not deployed* | ✓ (`config.tmpl` branches on `.profile`) | ✓ |

External plugins managed via `.chezmoiexternal.toml.tmpl`. The oh-my-zsh /
powerlevel10k externals are pulled on `rss-mac` only; `tpm` is pulled everywhere.

## Machines

Templates branch on two things, and the distinction matters:

- **`.profile`** — *which machine*. Set once at `chezmoi init`, stored in
  `~/.config/chezmoi/chezmoi.toml`. Use it for anything machine-specific:
  install paths, which shell framework, what's deployed at all.
- **`.chezmoi.os`** — *mac vs linux*. Use it only for genuinely OS-level
  differences (`pbcopy` vs `wl-copy`, `default-shell`).

| Profile | Machine |
|---------|---------|
| `rss-mac` | macOS + nix-darwin |
| `sonbox` | macOS, homebrew only — no nix |
| `omarchy` | Arch + omarchy |

`.chezmoi.toml.tmpl` uses `promptChoiceOnce`, so an unrecognized profile fails at
init rather than silently falling through to another machine's branch. Adding a
machine means adding it to that list and to the tables above.

The two macs run different enough shells that the bodies live in
`.chezmoitemplates/zshrc-rss-mac` and `.chezmoitemplates/zshrc-sonbox`;
`dot_zshrc.tmpl` is just a dispatcher. The same pattern carries nvim's two
machine-state files (`lazyvim.json`, `lazy-lock.json`) — everything else in
`.config/nvim/` is shared across all three machines.

### herdr

`~/.config/herdr/config.toml` was hand-maintained and untracked until 2026-08-19;
it is now `dot_config/herdr/config.toml`. Two consequences:

- **`night-owl/install.sh` no longer touches it.** It used to append the
  `[theme]` block, skipping if the file already defined one — which it did
  (`rose-pine`), so the block silently never landed and herdr was the one app on
  the machine not matching the palette. The block is inlined in the tracked file
  now; `night-owl/herdr-theme-block.toml` is kept only as the reference copy.
- **`theme.name = "terminal"`** means herdr renders through the ANSI palette and
  follows the host terminal, the same trick tmux uses. `accent` is the one role
  ANSI can't supply, so it is hardcoded — currently Rose Pine foam `#9ccfd8`,
  matching this machine's ghostty. It will look wrong if herdr ever runs on
  omarchy.

  **sonbox's ghostty is Rose Pine, not Night Owl**, and that is deliberate —
  only tmux on this machine is Night Owl. The config is chezmoi-managed as of
  2026-08-27: `dot_config/ghostty/config.tmpl` branches on `.profile` (sonbox
  gets theme + font-size, everything else is the omarchy config), and only
  rss-mac still ignores `.config/ghostty/`. sonbox's old hand-maintained copy
  at `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` was
  deleted in the move — ghostty reads the XDG path on macOS too, and keeping
  both would have had them competing. `night-owl/install.sh` refuses to touch
  any ghostty config that `chezmoi managed` claims, for the same reason it no
  longer appends to herdr's.

Herdr plugins live in `dot_config/herdr/plugins/`. `plugins.json` next to them is
a generated registry — herdr rescans the plugin directories at **server start**,
so a new plugin does not appear on `herdr server reload-config`.

- **`tab-numbers`** keeps tab labels prefixed with their number.
- **`git-sync`** starts `~/.local/bin/herdr-git-sync --watch`, which reports each
  workspace's ahead/behind state as the `$sync` token used by
  `[ui.sidebar.spaces]`. Nothing started that watcher before this plugin existed,
  so the token rendered blank from 2026-08-13 until 2026-08-19. There is no herdr
  event for "a commit happened", which is why this is a poller and not an event
  hook like tab-numbers.

- **`agent-ctx`** starts `~/.local/bin/herdr-agent-ctx --watch`, which publishes
  a `$ctx` token per agent pane for `[ui.sidebar.agents]`. Sidebar rows can show
  `terminal_title_stripped` directly, but that is only ever the OSC title the
  agent chose to write, so it means different things per agent: Claude Code
  publishes the conversation topic behind a state glyph, codex publishes
  `basename($PWD)` truncated to 24 bytes. `$ctx` normalizes it — real topic when
  there is one, otherwise a label built from context, with `~/Work/tries`
  entries reduced to their slug and the git branch appended where there is one.
  It also strips the U+25D0–U+25D3 busy spinner that herdr *detects* (see the
  `osc_title_working` rule in `claude.toml`) but does not strip, which otherwise
  leaves an animating first character on the row.

  A second token, `$ctxsrc`, records which branch produced `$ctx`. It is never
  rendered; it exists because an OSC title can blink empty while an agent
  redraws, and without it one empty sample would overwrite a real topic with the
  directory fallback.

Do not restart the herdr server from inside a Claude Code pane. The server is
long-lived and every pane shell inherits its environment, so it captures
`CLAUDE_CODE_CHILD_SESSION=1` and every `claude` started in any pane afterward
silently stops writing transcripts. Restart from a plain terminal.

### Updating nvim plugins

`lazy-lock.json` and `lazyvim.json` are written by lazy.nvim and LazyVim, so they
drift from the repo whenever you update plugins, toggle an extra, or dismiss the
NEWS popup. Refresh them with:

```bash
./sync-nvim-state.sh    # copies live state into the right per-profile template
chezmoi diff            # should be empty
```

**Never `chezmoi add` those two paths.** They're dispatchers
(`dot_config/nvim/lazy-lock.json.tmpl`) that select a per-profile body from
`.chezmoitemplates/`; `chezmoi add` would replace the dispatcher with one flat
file and break the other machines. `lazy.nvim`'s periodic update `checker` is
disabled so updates stay deliberate.

### nvim gotchas

Four things in `lazyvim.json` that fail *silently* — no error, just wrong
behavior:

- **Keep `"version"`.** Without it LazyVim runs its v0 migration, which prepends
  `lazyvim.plugins.extras.` to every entry (producing
  `lazyvim.plugins.extras.lazyvim.plugins.extras.…`) and disables all of them.
  Entries are full module names.
- **Keep `"install_version": 8`.** LazyVim resolves defaults with
  `(install_version or 7) < 8`, so omitting the key marks the install as
  *legacy* and hands you fzf-lua + neo-tree instead of snacks.picker +
  snacks.explorer. sonbox is on the snacks stack.
- **`mini-hipatterns` moved from `editor/` to `util/`** in v16. sonbox uses the
  new path; rss-mac's copy still has the old one and will need it changed when
  that machine migrates.
- **`lazy-lock.json` is only deployed on sonbox.** The other two keep floating so
  an old lock can't roll their plugins backwards. To opt one in, refresh that
  machine's template via `sync-nvim-state.sh` there, add a
  `nvim-lazy-lock-<profile>.json` slot plus a branch in the dispatcher, and drop
  its line from `.chezmoiignore.tmpl`.
- **`lazyvim.json` is deployed on all three machines, so each has its own body**
  in `.chezmoitemplates/` and the dispatcher branches on all three profiles by
  name. Deliberately no `else` fallback: sharing one body would mean migrating
  one machine's extras silently changed another's.

Also worth knowing:

- **Spell checking is whole-buffer on purpose** (strings and identifiers, not
  just comments), which needs both `spelloptions=camel` in `options.lua` *and*
  the `spell_plain_buffer` autocmd in `autocmds.lua` — nvim's treesitter
  highlighter appends `noplainbuffer` on every attach, so the global value alone
  is overridden in any code buffer. Add jargon with `zg`.
- **smart-splits keymaps live in `config/keymaps.lua`, not the plugin spec's
  `keys`.** LazyVim maps `<C-hjkl>` and `<A-j>`/`<A-k>` itself on VeryLazy, and
  `keys` stubs registered at startup would be clobbered by it. The `require` is
  wrapped in a callback so the plugin still lazy-loads on first press.
- **The `util.chezmoi` extra hardcodes `~/.local/share/chezmoi`.**
  `lua/plugins/chezmoi.lua.tmpl` overrides it with this repo's real `sourceDir`;
  without that, template highlighting and edit-watch silently do nothing.
