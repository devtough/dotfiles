return {
  "norcalli/nvim-colorizer.lua",
  -- optionally, override the default options:
  config = function()
    require("colorizer").setup({
      "*",
    })
  end,
}
