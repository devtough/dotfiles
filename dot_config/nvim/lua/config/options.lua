-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Enable spell check
vim.opt.spell = true

--
-- FOLD START
-- source: https://www.jackfranklin.co.uk/blog/code-folding-in-vim-neovim/
--

----vim.opt.foldcolumn = "0"
--vim.opt.foldmethod = "expr"
--vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
----vim.opt.foldtext = ""
--
--vim.opt.foldnestmax = 3
--vim.opt.foldlevel = 99
--vim.opt.foldlevelstart = 99

-- don't seem to need this
--local function close_all_folds()
--  vim.api.nvim_exec2("%foldc!", { output = false })
--end
--local function open_all_folds()
--  vim.api.nvim_exec2("%foldo!", { output = false })
--end
--
--vim.keymap.set("n", "<leader>zs", close_all_folds, { desc = "[s]hut all folds" })
--vim.keymap.set("n", "<leader>zo", open_all_folds, { desc = "[o]pen all folds" })

--
-- FOLD END
--
