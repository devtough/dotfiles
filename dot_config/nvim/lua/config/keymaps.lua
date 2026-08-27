-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jk", "<Esc>")

-- smart-splits.
--
-- These live here rather than in the plugin spec's `keys` on purpose: LazyVim
-- maps <C-hjkl> (window nav) and <A-j>/<A-k> (move line) itself on VeryLazy,
-- and this file is sourced *after* that, so the overrides below win. `keys`
-- stubs are registered at startup and would be clobbered by LazyVim's defaults.
--
-- The require is wrapped so it happens on first keypress instead of while this
-- file is sourced. lazy.nvim hooks `require` for lazy plugins, so this is what
-- lets smart-splits load on demand rather than at startup.
local function ss(fn)
  return function()
    require("smart-splits")[fn]()
  end
end

-- resize splits (Alt+hjkl) -- overrides LazyVim's <A-j>/<A-k> move-line maps
vim.keymap.set("n", "<A-h>", ss("resize_left"), { desc = "Resize Split Left" })
vim.keymap.set("n", "<A-j>", ss("resize_down"), { desc = "Resize Split Down" })
vim.keymap.set("n", "<A-k>", ss("resize_up"), { desc = "Resize Split Up" })
vim.keymap.set("n", "<A-l>", ss("resize_right"), { desc = "Resize Split Right" })
-- move between splits/tmux panes (Ctrl+hjkl)
vim.keymap.set("n", "<C-h>", ss("move_cursor_left"), { desc = "Go to Left Window" })
vim.keymap.set("n", "<C-j>", ss("move_cursor_down"), { desc = "Go to Lower Window" })
vim.keymap.set("n", "<C-k>", ss("move_cursor_up"), { desc = "Go to Upper Window" })
vim.keymap.set("n", "<C-l>", ss("move_cursor_right"), { desc = "Go to Right Window" })
-- ...and from insert mode too. <C-h> in insert mode is Vi's legacy alias for
-- backspace; that is deliberately given up here (ghostty sends DEL for the
-- Backspace key, and nvim sees the two as distinct, so Backspace is unaffected).
--
-- stopinsert first, on purpose: crossing into another window or herdr pane
-- while still in insert mode means the next thing typed lands in a buffer you
-- were not looking at. Normal mode on arrival is the safe landing.
local function ss_insert(fn)
  return function()
    vim.cmd("stopinsert")
    require("smart-splits")[fn]()
  end
end

vim.keymap.set("i", "<C-h>", ss_insert("move_cursor_left"), { desc = "Go to Left Window" })
vim.keymap.set("i", "<C-j>", ss_insert("move_cursor_down"), { desc = "Go to Lower Window" })
vim.keymap.set("i", "<C-k>", ss_insert("move_cursor_up"), { desc = "Go to Upper Window" })
vim.keymap.set("i", "<C-l>", ss_insert("move_cursor_right"), { desc = "Go to Right Window" })

-- swap buffers between windows
vim.keymap.set("n", "<leader><leader>h", ss("swap_buf_left"), { desc = "Swap Buffer Left" })
vim.keymap.set("n", "<leader><leader>j", ss("swap_buf_down"), { desc = "Swap Buffer Down" })
vim.keymap.set("n", "<leader><leader>k", ss("swap_buf_up"), { desc = "Swap Buffer Up" })
vim.keymap.set("n", "<leader><leader>l", ss("swap_buf_right"), { desc = "Swap Buffer Right" })

-- run current line in floating terminal
local function run_current_line()
  local current_line = vim.api.nvim_get_current_line()
  current_line = current_line:match("^%s*(.-)%s*$")
  if current_line == "" then
    vim.notify("Current line is empty", vim.log.levels.WARN)
    return
  end
  vim.notify("Running: " .. current_line, vim.log.levels.INFO)
  -- `Snacks` is a global set by snacks.nvim; referencing it inside the callback
  -- avoids a load-order dependency at file scope.
  Snacks.terminal({
    cmd = current_line,
    title = "Shell Command: " .. current_line,
    title_pos = "center",
    width = 0.8,
    height = 0.6,
    border = "rounded",
    backdrop = false,
    enter = true,
    keys = {
      q = "close",
      ["<esc>"] = "close",
      ["<c-c>"] = "close",
    },
  })
end
vim.keymap.set("n", "<leader>rt", run_current_line, { desc = "Run current line in floating terminal" })
