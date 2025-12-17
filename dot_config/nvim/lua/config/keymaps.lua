-- Have to reload to pick up these changes
-- These will not be lazy loaded, prefered to put
-- plugin specific in lazyvim plugins - should probably
-- do that for the smart-splits?

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jk", "<Esc>")

-- recommended mappings
-- resizing splits
-- these keymaps will also accept a range,
-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
vim.keymap.set("n", "<A-h>", require("smart-splits").resize_left)
vim.keymap.set("n", "<A-j>", require("smart-splits").resize_down)
vim.keymap.set("n", "<A-k>", require("smart-splits").resize_up)
vim.keymap.set("n", "<A-l>", require("smart-splits").resize_right)
-- moving between splits
vim.keymap.set("n", "<C-h>", require("smart-splits").move_cursor_left)
vim.keymap.set("n", "<C-j>", require("smart-splits").move_cursor_down)
vim.keymap.set("n", "<C-k>", require("smart-splits").move_cursor_up)
vim.keymap.set("n", "<C-l>", require("smart-splits").move_cursor_right)
-- swapping buffers between windows
vim.keymap.set("n", "<leader><leader>h", require("smart-splits").swap_buf_left)
vim.keymap.set("n", "<leader><leader>j", require("smart-splits").swap_buf_down)
vim.keymap.set("n", "<leader><leader>k", require("smart-splits").swap_buf_up)
vim.keymap.set("n", "<leader><leader>l", require("smart-splits").swap_buf_right)

-- run the current line in a floating terminal
--vim.keymap.set("n", "<leader>rt", function()
--  local current_line = vim.fn.getline(".")
--  require("lazyvim.util").terminal({ current_line }, { cwd = vim.fn.getcwd() })
--end, { desc = "Run current line in floating terminal" })

local Snacks = require("snacks")

-- Function to run shell command using snacks terminal
local function run_current_line()
  -- Get current line
  local current_line = vim.api.nvim_get_current_line()

  -- Trim whitespace
  current_line = current_line:match("^%s*(.-)%s*$")

  if current_line == "" then
    vim.notify("Current line is empty", vim.log.levels.WARN)
    return
  end

  -- Show notification that command is running
  vim.notify("Running: " .. current_line, vim.log.levels.INFO)

  -- Use snacks terminal to run the command
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
