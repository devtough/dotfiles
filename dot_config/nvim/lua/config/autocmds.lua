-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Keep spell checking whole-buffer, so string literals and identifiers are
-- checked and not just comments (see the 'spelloptions' note in options.lua).
--
-- Neovim's treesitter highlighter appends `noplainbuffer` to 'spelloptions'
-- every time it attaches to a buffer:
--
--   runtime/lua/vim/treesitter/highlighter.lua:
--     vim.opt_local.spelloptions:append('noplainbuffer')
--
-- 'spelloptions' is buffer-local, so the global value set in options.lua is
-- overridden in every treesitter-highlighted buffer -- which is every code
-- buffer. Reassert it after the highlighter has attached. Scheduling is what
-- puts this after the append rather than before it.
--
-- Harmless in buffers where spell is off ('spelloptions' is inert then), so
-- there is no need to exclude dashboards and other special filetypes.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("spell_plain_buffer", { clear = true }),
  callback = function(ev)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(ev.buf) then
        vim.bo[ev.buf].spelloptions = "camel"
      end
    end)
  end,
})
