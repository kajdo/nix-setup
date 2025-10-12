-- init.lua

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
  -- Add eldritch.nvim theme
  {
    "eldritch-theme/eldritch.nvim",
    config = function()
      require("eldritch").setup({
        transparent = true, -- Enable this to disable setting the background color
        terminal_colors = true, -- Configure terminal colors
        styles = {
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
          sidebars = "dark", -- Style for sidebars
          floats = "dark", -- Style for floating windows
        },
        sidebars = { "qf", "help" }, -- Set a darker background on sidebar-like windows
        hide_inactive_statusline = false, -- Hide inactive statuslines
        dim_inactive = false, -- Dims inactive windows
        -- on_colors = function(colors)
        --   -- You can customize colors here if needed
        -- end,
        -- on_highlights = function(highlights, colors)
        --   -- You can customize highlights here if needed
        -- end,
      })
      vim.opt.termguicolors = true
      vim.cmd("syntax enable") -- Enable syntax highlighting
      vim.cmd.colorscheme("eldritch") -- Set the colorscheme

      -- Add transparency to Telescope
      vim.cmd([[
        highlight TelescopeNormal ctermbg=NONE guibg=NONE
        highlight TelescopePromptNormal ctermbg=NONE guibg=NONE
        highlight TelescopeResultsNormal ctermbg=NONE guibg=NONE
      ]])
    end,
  },  
  -- Add nvim-treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate", -- Run `:TSUpdate` to install/update parsers
    config = function()
      require("nvim-treesitter.configs").setup({
        -- Enable syntax highlighting
        highlight = {
          enable = true,
        },
        -- Enable code folding
        fold = {
          enable = true,
        },
        -- Ensure all installed parsers are used
        ensure_installed = {
          "python",
          "lua",
          "javascript",
          "typescript",
          "bash",
          "json",
          "yaml",
          "html",
          "css",
          -- Add more as needed
        },
        -- Automatically install missing parsers
        auto_install = false,
      })
    end,
  },
  -- Add plenary.nvim
  {
    "nvim-lua/plenary.nvim",
    lazy = false, -- Load immediately (not lazy-loaded)
  },
  -- Your plugins here
  {
    "neovim/nvim-lspconfig",
    config = function()
      local lspconfig = require("lspconfig")

      -- Configure LSPs
      lspconfig.ts_ls.setup({
        cmd = { "typescript-language-server", "--stdio" },
      })

      lspconfig.pyright.setup({
        cmd = { "pyright-langserver", "--stdio" },
      })

      lspconfig.bashls.setup({
        cmd = { "bash-language-server", "start" },
      })

      lspconfig.dockerls.setup({
        cmd = { "docker-langserver", "--stdio" },
      })

      lspconfig.yamlls.setup({
        cmd = { "yaml-language-server", "--stdio" },
      })

      lspconfig.vimls.setup({
        cmd = { "vim-language-server", "--stdio" },
      })

      lspconfig.eslint.setup({
        cmd = { "vscode-eslint-language-server", "--stdio" },
      })

      -- Add more LSPs as needed
    end,
  },
  {
    "jose-elias-alvarez/null-ls.nvim",
    config = function()
      local null_ls = require("null-ls")

      null_ls.setup({
        sources = {
          -- Formatters
          null_ls.builtins.formatting.black.with({
            command = "black",
          }),
          null_ls.builtins.formatting.nixpkgs_fmt.with({
            command = "nixpkgs-fmt",
          }),
          null_ls.builtins.formatting.shfmt.with({
            command = "shfmt",
          }),
          null_ls.builtins.formatting.stylua.with({
            command = "stylua",
          }),
          null_ls.builtins.formatting.prettierd.with({
            command = "prettierd",
          }),

          -- Add more formatters as needed
        },
      })
    end,
  },
  -- Add more plugins as needed
})

-- Additional Neovim configuration
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

