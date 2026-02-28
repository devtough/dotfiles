-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jk", "<Esc>")

-- smart-splits: resize splits (Alt+hjkl)
vim.keymap.set("n", "<A-h>", require("smart-splits").resize_left)
vim.keymap.set("n", "<A-j>", require("smart-splits").resize_down)
vim.keymap.set("n", "<A-k>", require("smart-splits").resize_up)
vim.keymap.set("n", "<A-l>", require("smart-splits").resize_right)
-- smart-splits: move between splits/tmux panes (Ctrl+hjkl)
vim.keymap.set("n", "<C-h>", require("smart-splits").move_cursor_left)
vim.keymap.set("n", "<C-j>", require("smart-splits").move_cursor_down)
vim.keymap.set("n", "<C-k>", require("smart-splits").move_cursor_up)
vim.keymap.set("n", "<C-l>", require("smart-splits").move_cursor_right)
-- smart-splits: swap buffers between windows
vim.keymap.set("n", "<leader><leader>h", require("smart-splits").swap_buf_left)
vim.keymap.set("n", "<leader><leader>j", require("smart-splits").swap_buf_down)
vim.keymap.set("n", "<leader><leader>k", require("smart-splits").swap_buf_up)
vim.keymap.set("n", "<leader><leader>l", require("smart-splits").swap_buf_right)

-- run current line in floating terminal
local Snacks = require("snacks")
local function run_current_line()
  local current_line = vim.api.nvim_get_current_line()
  current_line = current_line:match("^%s*(.-)%s*$")
  if current_line == "" then
    vim.notify("Current line is empty", vim.log.levels.WARN)
    return
  end
  vim.notify("Running: " .. current_line, vim.log.levels.INFO)
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
