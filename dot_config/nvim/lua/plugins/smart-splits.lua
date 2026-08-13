return {
  {
    "mrjones2014/smart-splits.nvim",
    -- lazy.lua sets defaults.lazy = false for custom plugins, so this needs to
    -- be explicit. config/keymaps.lua wraps its `require` in a callback, and
    -- lazy.nvim hooks `require` for lazy plugins, so the first <C-hjkl> or
    -- <A-hjkl> press loads it. Nothing here needs to run before that.
    lazy = true,
    opts = function()
      -- Inside a herdr pane (and NOT inside tmux): route nvim edge-moves to
      -- herdr so <C-hjkl> walks nvim splits, then crosses into herdr panes.
      -- Inside tmux (including tmux-inside-herdr, where HERDR_ENV leaks in),
      -- fall through to smart-splits' native tmux integration.
      if vim.env.HERDR_ENV == "1" and vim.env.TMUX == nil then
        -- Resolve the binary instead of hardcoding a path: the install prefix
        -- differs per machine (/home/evan on omarchy, /Users/evan on the macs),
        -- and nvim may be launched from a Hyprland bind where ~/.local/bin is
        -- not on PATH -- hence the explicit fallback.
        local herdr = vim.fn.exepath("herdr")
        if herdr == "" then
          herdr = vim.fn.expand("~/.local/bin/herdr")
        end
        if vim.fn.executable(herdr) == 1 then
          return {
            multiplexer_integration = false,
            at_edge = function(ctx)
              vim.fn.jobstart(
                { herdr, "pane", "focus", "--direction", ctx.direction, "--current" },
                { detach = true }
              )
            end,
          }
        end
      end
      return {}
    end,
  },
}
