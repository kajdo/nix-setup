{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Python tooling
    (python313.withPackages (p: with p; [
      flake8
      typer
    ]))
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
    bitwarden-cli

    # General utilities
    jq
    xdg-utils
    wget2
    curl

    # Git diff viewer
    delta

    # Git GUI client
    gitnuro

    # Neovim
    neovim

    # LSPs
    typescript-language-server
    vscode-langservers-extracted
    pyright
    nixd
    bash-language-server
    dart
    dockerfile-language-server
    yaml-language-server
    vim-language-server
    eslint
    prettier
    shellcheck

    # Formatters
    black
    nixpkgs-fmt
    shfmt
    stylua
    prettierd
    biome

    tree-sitter

    # Windsurf.nvim language server (auto-patched via flake)
    codeium-lsp

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

  # GitHub CLI
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
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

  # Tree-sitter parsers and queries (non-bundled in nvim 0.12)
  home.file."nvim-treesitter-parsers".source =
    let
      parsers = with pkgs.vimPlugins.nvim-treesitter-parsers; [
        bash css dart diff html json yaml python javascript typescript markdown_inline query nix
      ];
    in
    pkgs.symlinkJoin {
      name = "nvim-treesitter-parsers";
      paths = parsers ++ [ pkgs.vimPlugins.nvim-treesitter ];
    };

  # Neovim configuration
  xdg.configFile."nvim" = {
    source = ./../config/nvim;
    recursive = true;
  };
}
