-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false

-- Enable spell check.
--
-- Deliberately whole-buffer (no `noplainbuffer`), so string literals and
-- identifiers get checked too, not just comments. `noplainbuffer` would limit
-- checking to treesitter's @spell captures, and most languages only tag
-- comments -- strings and function names would be skipped.
--
-- `camel` is what makes that bearable: it splits CamelCase at each upper-case
-- letter following a lower-case one, so `myVariabl` is caught on "Variabl"
-- while `notAWordHereEither` stays clean because every part is a real word.
--
-- Add project jargon to the dictionary with `zg` (`zw` to un-add); it lands in
-- ~/.local/share/nvim/site/spell/en.utf-8.add.
vim.opt.spell = true
vim.opt.spelloptions = "camel"
