-- not using this with wezterm
return {
  {
    "christoomey/vim-tmux-navigator",
    enabled = false,
    -- these are the vim-tmux-navigator defaults
    -- but we need to overwrite the lazy vim defaults
    keys = {
      { "<C-k>", "<cmd>TmuxNavigateUp<cr><esc>", desc = "Navigate Up" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr><esc>", desc = "Navigate Down" },
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr><esc>", desc = "Navigate Left" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr><esc>", desc = "Navigate Right" },
      { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr><esc>", desc = "Navigate Previous" },
    },
  },
}
