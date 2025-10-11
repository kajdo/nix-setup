{ config, pkgs, ... }:

{
  # enable appimages to be runable as in other distros
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.localsend.enable = true;
  programs.localsend.openFirewall = true;
  programs.firefox.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # avahi for chromecast
  services.avahi.enable = true;

  # docker setup
  virtualisation.docker.enable = true;

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    vim  
    evtest
    wget
    wget2 # better for some downloads
    toybox # pgrep and other fun stuff
    xfce.thunar
    neovim
    gcc # to make avante build
    gnumake # to make avante build
    cargo # to make avante build
    lua
    luajitPackages.luarocks_bootstrap
    unzip
    python313
    python313Packages.flake8
    pipx
    networkmanagerapplet
    # pulseaudio full for various check scripts
    pulseaudioFull
    # GTK Themes
    gtk3
    gtk-engine-murrine # For GTK theme engines
    gtk_engines
    adwaita-icon-theme
    papirus-icon-theme # Popular icon theme
    gnome-themes-extra
    # Notifications
    libnotify
    dunst # Works on Wayland
    # Also ensure OpenGL/Mesa drivers are correctly configured for your Intel GPU
    # You have some of this, but double check they are pulling in all needed parts
    mesa # This ensures all standard Mesa drivers are available

    fluent-reader

    # This tells Nix to build/configure MPV such that yt-dlp is available in its runtime closure.
    (mpv.overrideAttrs (oldAttrs: {
      propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ yt-dlp ];
    }))
    yt-dlp

    # tooltest
    scrcpy
    opencode

    curl      # Likely needed for network communication/authentication
    xdg-utils # Provides xdg-open for browser authentication flow
    jq
    # searching for that emoji issue
    kitty # Works natively on Wayland and lets me configure emoticons correct

    # LSPs
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    pyright
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

    # HYPRLAND Packages
    swww
    hyprlock
    hypridle

    # appimage execution
    appimage-run
  ];

  # Set GTK environment variables
  environment.variables = {
    GTK_THEME = "Adwaita"; # Replace with your desired GTK theme
    GTK_ICON_THEME = "Adwaita"; # Replace with your desired icon theme
  };

  environment.sessionVariables = {
    PATH = [
      "/home/kajdo/.local/bin"
      "/home/kajdo/.npm-global/bin"
    ];
    XDG_DATA_DIRS = [ "/var/lib/flatpak/exports/share" "/home/$USER/.local/share/flatpak/exports/share" ];

    # QT_QPA_PLATFORMTHEME = "qt5ct";
    # QT_STYLE_OVERRIDE = "kvantum";
  };
}