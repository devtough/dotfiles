return {
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    opts = function()
      -- Inside a herdr pane (and NOT inside tmux): route nvim edge-moves to
      -- herdr so <C-hjkl> walks nvim splits, then crosses into herdr panes.
      -- Inside tmux (including tmux-inside-herdr, where HERDR_ENV leaks in),
      -- fall through to smart-splits' native tmux integration.
      if vim.env.HERDR_ENV == "1" and vim.env.TMUX == nil then
        return {
          multiplexer_integration = false,
          at_edge = function(ctx)
            -- absolute path: nvim may be launched from a Hyprland bind
            -- where ~/.local/bin is not on PATH
            vim.fn.jobstart(
              { "/home/evan/.local/bin/herdr", "pane", "focus", "--direction", ctx.direction, "--current" },
              { detach = true }
            )
          end,
        }
      end
      return {}
    end,
  },
}
