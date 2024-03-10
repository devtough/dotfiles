if vim.g.vscode then
  -- settings for using nvim plugin in vscode
  vim.cmd([[source $HOME/.config/nvim/vscode/vscode.vim]])
else
  --bootstrap lazy.nvim, LazyVim and your plugins
  require("config.lazy")
end
