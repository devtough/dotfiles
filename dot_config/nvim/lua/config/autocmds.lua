-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Built-in spell is prose-only (see the note in options.lua); code buffers are
-- covered by typos-lsp and harper-ls instead. 'spell' is window-local, so this
-- has to be set per-filetype rather than globally.
--
-- Note what is deliberately NOT here any more. Neovim's treesitter highlighter
-- appends `noplainbuffer` to 'spelloptions' every time it attaches:
--
--   runtime/lua/vim/treesitter/highlighter.lua:
--     vim.opt_local.spelloptions:append('noplainbuffer')
--
-- which narrows checking to treesitter's @spell captures. This file used to
-- reassert `camel` on a vim.schedule to undo that, because most language
-- grammars only tag comments as @spell and whole-buffer checking was the point.
-- Now that code buffers are out of scope, letting `noplainbuffer` stand is
-- actively better: in markdown it is what keeps fenced code blocks and inline
-- code from being spell-checked. Restore the scheduled reassert here if
-- built-in spell ever goes back to covering code.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("spell_prose", { clear = true }),
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.spell = true
  end,
})
