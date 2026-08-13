-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false

-- Spell checking is split by buffer kind:
--
--   prose (markdown/text/gitcommit) -- built-in dictionary spell, switched on
--     per-filetype in autocmds.lua, with harper-ls layered on for grammar.
--   code -- handled entirely by language servers: typos-lsp over the whole
--     buffer, harper-ls in comments. See lua/plugins/spell.lua.
--
-- This used to be whole-buffer everywhere, on the reasoning that identifiers
-- and string literals deserve checking too. They do -- but a general English
-- dictionary is the wrong dictionary for them, so in practice it underlined
-- most of the jargon in any real repo and the only remedy was feeding `zg`
-- forever. typos-lsp instead matches a corpus of known misspellings, which
-- trades away novel typos for near-zero false positives.
--
-- 'spelloptions' stays global because it is inert wherever 'spell' is off, and
-- the prose buffers that do turn it on want `camel` anyway: it splits CamelCase
-- at each upper-case letter following a lower-case one, so `myVariabl` is
-- caught on "Variabl" while `notAWordHereEither` stays clean.
--
-- Add jargon with `zg` (`zw` to un-add); it lands in
-- ~/.local/share/nvim/site/spell/en.utf-8.add.
vim.opt.spell = false
vim.opt.spelloptions = "camel"
