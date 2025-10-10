{ config, pkgs, inputs, ... }:

let
  # Define the individual build packages
  # dwmblocks    = pkgs.callPackage ./pkgs/dwmblocks.nix {};
  # st           = pkgs.callPackage ./pkgs/st.nix {};
in {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.download-buffer-size = 1048576000;

  imports =
    [
      ./hardware-configuration.nix
      # ./modules/thinkpad.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  # IPv6 issue - not sure if ISP issue, but try to fix
  # `ip -6 a` should not have any result after that
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = true;
    "net.ipv6.conf.default.disable_ipv6" = true;
    "net.ipv6.conf.lo.disable_ipv6" = true;
    "net.ipv6.conf.wlp4s0.disable_ipv6" = true;
  };

  # after reboot keyboard and other usb devices "slept after 2-3 seconds"
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = true;

  # enable localsend
  programs.localsend.enable = true;
  programs.localsend.openFirewall = true;

  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "de_AT.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_PAPER = "de_AT.UTF-8";
    LC_TELEPHONE = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  # Enable Hyprland and SDDM
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true; # <-- ADD THIS LINE
  programs.hyprland.enable = true;


  # Battery life - Better scheduling for CPU cycles - thanks System76!!!
  services.system76-scheduler.settings.cfsProfiles.enable = true;

  # Enable TLP (better than gnomes internal power manager)
  services.tlp = {
    enable = true;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
    };
  };

  # Enable powertop
  powerManagement.powertop.enable = true;

  # Enable thermald (only necessary if on Intel CPUs)
  services.thermald.enable = true;


  # docker setup
  virtualisation.docker.enable = true;

  # Configure keymap
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # avahi for chromecast
  services.avahi.enable = true;


  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # set default timeout to 10s - many times reboot waits 90s
  systemd.settings = {
    Manager = {
      DefaultTimeoutStopSec = "10s";
    };
  };


  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # enable appimages to be runable as in other distros
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kajdo = {
    isNormalUser = true;
    description = "kajdo";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
      btop
      tldr
      fastfetch
      stow
      git
      delta         # git diff viewer
      alacritty     # Works natively on Wayland
      starship
      ueberzugpp
      yazi
      mcfly
      mcfly-fzf
      fzf
      chatterino2
      peazip
      vlc
      pyradio
      bat
      tmux
      rofi # Use wofi instead for Wayland
      lsd
      tty-clock
      plocate
      zoxide
      pulsemixer
      tree
      feh
      # picom-pijulius # Remove, Hyprland has a compositor
      tailscale
      ncdu
      cmatrix
      cava
      glow
      vivaldi
      vivaldi-ffmpeg-codecs
      typioca
      chromium
      moonlight-qt
      libreoffice-qt6-fresh
      obsidian
      lazydocker
      nextcloud-client
      portfolio
      galculator
      httpie
      chromedriver
      makima
      signal-desktop-bin # signal had problems with update to unstable -- installed via flatpak
      grim
      slurp
      swappy
      wl-clipboard
      # persistant clipboard
      wl-clip-persist
      waybar
      wdisplays
    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
    config.common.default = "*";
  };
  # dont forget to: `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
  services.flatpak.enable = true;

  environment.sessionVariables = {
    PATH = [
      "/home/kajdo/.local/bin"
      "/home/kajdo/.npm-global/bin"
    ];
    XDG_DATA_DIRS = [ "/var/lib/flatpak/exports/share" "/home/$USER/.local/share/flatpak/exports/share" ];

    # QT_QPA_PLATFORMTHEME = "qt5ct";
    # QT_STYLE_OVERRIDE = "kvantum";
  };

  # Set GTK environment variables
  environment.variables = {
    GTK_THEME = "Adwaita"; # Replace with your desired GTK theme
    GTK_ICON_THEME = "Adwaita"; # Replace with your desired icon theme
  };

  # Font setup
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      noto-fonts-emoji
      nerd-fonts.symbols-only
      noto-fonts-extra
      atkinson-hyperlegible-next
      atkinson-hyperlegible-mono
    ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kajdo";
  services.displayManager.defaultSession = "hyprland";

  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;


  # try to configure intel graphics for encoders
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  };
  hardware.graphics = {  
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      intel-vaapi-driver # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables = { LIBVA_DRIVER_NAME = "iHD"; }; # Force intel-media-drive

  # enable backlight settings
  # light -U 30 --> darker
  # light -A 30 --> brighter
  programs.light.enable = true;

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    vim  
    evtest
    wget
    wget2 # better for some downloads
    toybox # pgrep and other fun stuff
    xfce.thunar
    neovim
    # unclutter-xfixes # Remove
    gcc # to make avante build
    gnumake # to make avante build
    cargo # to make avante build
    # go
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

    # libsForQt5.qt5ct
    # qt6ct
    # catppuccin-kvantum

    # rss reader
    fluent-reader

    # mpv
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
    # nodePackages.dockerfile-language-server-nodejs
    dockerfile-language-server
    nodePackages.yaml-language-server
    nodePackages.vim-language-server
    #nodePackages.json-language-server
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

  # List services that you want to enable:
  services.openssh.enable = true;
  services.tailscale.enable = true;
  networking.firewall = {
    # for chromecast via brave
    allowedUDPPorts = [ 5353 ];  # For device discovery
    allowedUDPPortRanges = [{ from = 32768; to = 61000; }];  # For streaming
    allowedTCPPorts = [ 8010 ];  # For Chromecast server
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?  
}
