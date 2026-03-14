{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Python tooling
    python313
    python313Packages.flake8
    pipx

    # Build tools
    gcc
    gnumake
    cargo

    # Lua tooling
    lua
    luajitPackages.luarocks_bootstrap

    # User utilities
    yt-dlp
    scrcpy
    opencode

    # General utilities
    jq
    xdg-utils
    wget2
    curl

    # Git diff viewer
    delta

    # Neovim
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

    # Development tools
    ripgrep
    fd
    mitmproxy
    nodejs
    android-tools
  ];

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Juergen Kajdocsy";
        email = "juergen.kajdocsy@gmail.com";
      };
      init = {
        defaultBranch = "main";
      };
      credential = {
        helper = "store";
      };

      pull = {
        rebase = false;
      };

      core = {
        pager = "delta";
      };

      interactive = {
        diffFilter = "delta --color-only";
      };

      delta = {
        navigate = true;
        dark = true;
        side-by-side = true;
      };

      merge = {
        conflictstyle = "zdiff3";
      };

      fetch = {
        prune = true;
      };
    };
  };

  # Docker TUI
  programs.lazydocker = {
    enable = true;
  };

  # Terminal multiplexer
  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ./../config/tmux/tmux.conf;
  };

  # Neovim configuration
  xdg.configFile."nvim" = {
    source = ./../config/nvim;
    recursive = true;
  };
}
