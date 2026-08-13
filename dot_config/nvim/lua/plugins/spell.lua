-- Spell checking for code, as two language servers with different jobs.
--
-- typos-lsp matches a corpus of *known* misspellings rather than a dictionary,
-- so it can run over identifiers and strings without drowning you in false
-- positives. The trade is false negatives: it never flags a wrong word it has
-- not seen before.
--
-- harper-ls is a real dictionary plus grammar rules, and is tree-sitter aware --
-- in a code buffer it checks comments only and leaves identifiers alone. It
-- parses markdown and friends in full.
--
-- Installed through Mason rather than brew so this travels to the sonbox and
-- omarchy profiles too. Built-in spell handles prose; see config/options.lua.
return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "typos-lsp", "harper-ls" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        typos_lsp = {
          -- Explicit list rather than "*": harper-ls owns the prose filetypes,
          -- and attaching both there means two diagnostics on the same word.
          filetypes = {
            "c",
            "cpp",
            "css",
            "dockerfile",
            "go",
            "html",
            "java",
            "javascript",
            "javascriptreact",
            "json",
            "jsonc",
            "lua",
            "make",
            "python",
            "ruby",
            "rust",
            "sh",
            "sql",
            "terraform",
            "toml",
            "typescript",
            "typescriptreact",
            "yaml",
            "zsh",
          },
          init_options = { diagnosticSeverity = "Warning" },
        },
        harper_ls = {
          filetypes = {
            "markdown",
            "text",
            "gitcommit",
            "lua",
            "python",
            "typescript",
            "typescriptreact",
            "javascript",
            "sh",
            "bash",
            "yaml",
            "json",
            "dockerfile",
          },
          settings = {
            ["harper-ls"] = {
              linters = {
                SpellCheck = true,
                -- Both fire constantly on comment fragments, which are not
                -- sentences and are not trying to be.
                SentenceCapitalization = false,
                LongSentences = false,
              },
              isolateEnglish = true,
              dialect = "American",
            },
          },
        },
      },
    },
  },
}
