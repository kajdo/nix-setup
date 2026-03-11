{ config, pkgs, ... }:
{
  # Link your nvim configuration
  xdg.configFile."nvim" = {
    source = ./../config/nvim;
    recursive = true;
  };

  # Ensure neovim is installed
  home.packages = with pkgs; [
    neovim

    # LSPs
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    pyright
    nixd
    nodePackages.bash-language-server
    dockerfile-language-server
    nodePackages.yaml-language-server
    nodePackages.vim-language-server
    nodePackages.eslint
    nodePackages.prettier

    # Formatters
    black
    nixpkgs-fmt
    shfmt
    stylua
    prettierd
    biome

    # Tree-sitter parsers
    tree-sitter
    vimPlugins.nvim-treesitter-parsers.python
    vimPlugins.nvim-treesitter-parsers.lua
    vimPlugins.nvim-treesitter-parsers.javascript
    vimPlugins.nvim-treesitter-parsers.typescript
    vimPlugins.nvim-treesitter-parsers.bash
    vimPlugins.nvim-treesitter-parsers.json
    vimPlugins.nvim-treesitter-parsers.yaml
    vimPlugins.nvim-treesitter-parsers.html
    vimPlugins.nvim-treesitter-parsers.css

    # features for nvim / development
    ripgrep
    fd
    mitmproxy
    nodejs
    android-tools
  ];
}
