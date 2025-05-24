# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

let
  # Define the individual build packages
  dwmblocks    = pkgs.callPackage ./pkgs/dwmblocks.nix {};
  # st           = pkgs.callPackage ./pkgs/st.nix {};
in {
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # increase download buffer
  nix.settings.download-buffer-size = 1048576000;
  # nix.settings.experimental-features = [ "nix-command" ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # ./modules/thinkpad.nix
      # ./modules/makima.nix
    ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable network manager applet
  # programs.nm-applet.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Vienna";

  # Select internationalisation properties.
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

   # Enable the X11 windowing system.
   services.xserver.enable = true;
   services.xserver.resolutions = [ { x = 1920; y = 1080; } ];
   services.libinput.touchpad.naturalScrolling = true;
   services.xserver.videoDrivers = [ "modesetting" ];

  # Enable makima for having the keyboard overwrite done
  # services.makima.enable = true;

  # Battery life improvement
  # Better scheduling for CPU cycles - thanks System76!!!
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

  # Disable GNOMEs power management
  services.power-profiles-daemon.enable = false;

  # Enable powertop
  powerManagement.powertop.enable = true;

  # Enable thermald (only necessary if on Intel CPUs)
  services.thermald.enable = true;


  # docker setup
  virtualisation.docker.enable = true;

   services.xserver.displayManager.lightdm.enable = true;
   #services.xserver.desktopManager.lxqt.enable = true;

  services.xserver.windowManager.dwm.enable = true;
  nixpkgs.overlays = [
    # Your existing DWM overlay (first element in the list)
    (final: prev: let
       vscodeOverrideAttrs = import ./pkgs/vscode-custom.nix { pkgs = prev; lib = prev.lib; };
    in {
       dwm = prev.dwm.overrideAttrs (old: {src = ./pkgs/source/dwm-kajdo;});
       vscodium = prev.vscodium.overrideAttrs (vscodeOverrideAttrs);
# If you had other overrides in THIS specific overlay function, they'd go here
    }) # <--- End of the first overlay function definition
  ];


  services.xserver.displayManager.sessionCommands = ''
    ${dwmblocks}/bin/dwmblocks &
  '';

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # avahi for chromecast
  services.avahi.enable = true;

  # Enable sound with pipewire.
  # hardware.pulseaudio.enable = false;

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  # services.blueman.enable = true; # service to configure bluetooth

  # set default timeout to 10s - many times reboot waits 90s
  # not sure what causes the issue, but occured when started to
  # mess around with bluetooth and bluetooth blocks script
  # maybe it shouldn't run every second #TODO
  systemd.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';


  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.kajdo = {
    isNormalUser = true;
    description = "kajdo";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
    #  thunderbird
       btop
       tldr
       fastfetch
       stow
       git
       delta        # git diff viewer
       alacritty
       starship
       ueberzugpp
       yazi
       yt-dlp
       mcfly
       mcfly-fzf
       fzf
       # chatterino2
       peazip
       mpv
       vlc
       pyradio
       bat
       xorg.xrandr
       arandr
       tmux
       rofi
       dmenu
       lsd
       tty-clock
       plocate
       flameshot
       zoxide
       pulsemixer
       tree
       feh
       # picom
       # try to install patched picom
       picom-pijulius
       xclip
       tailscale
       chatblade
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

    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
  services.flatpak.enable = true;
  # dont forget to: `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`

  environment.sessionVariables = {
    PATH = [ "/home/kajdo/.local/bin" ];
    XDG_DATA_DIRS = [ "/var/lib/flatpak/exports/share" "/home/$USER/.local/share/flatpak/exports/share" ];
    # MAKIMA_CONFIG = [ "/home/kajdo/.config/makima" ];
  };

  # # Set GTK environment variables
  # environment.variables = {
  #   GTK_THEME = "Adwaita"; # Replace with your desired GTK theme
  #   GTK_ICON_THEME = "Adwaita"; # Replace with your desired icon theme
  # };

  # Font setup
  fonts = {
    packages = with pkgs; [
      # fira-code-nerdfont  # Keep Fira Code if you still want it
      nerd-fonts.fira-code
      noto-fonts-emoji
    ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kajdo";

  # Install firefox.
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
  # services.actkbd = {
  #   enable = true;
  #   bindings = [
  #     { keys = [ 233 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -A 10"; }
  #     { keys = [ 232 ]; events = [ "key" ]; command = "/run/current-system/sw/bin/light -U 10"; }
  #   ];
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim 
    aider-chat
    evtest
    wget
    wget2 # better for some downloads
    toybox # pgrep and other fun stuff
    dwmblocks 
    # st
    xfce.thunar
    neovim
    unclutter-xfixes
    gcc # to make avante build
    gnumake # to make avante build
    cargo # to make avante build
    go
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
    # adwaita-icon-theme
    papirus-icon-theme # Popular icon theme
    gnome-themes-extra
    # Notifications
    libnotify
    dunst
    # keyboard shortcut daemon
    sxhkd
    # clipboard manager to keep clipboard if alacritty is killed
    clipit
    # lockscreen
    betterlockscreen

    # codeium is specia    # === Add Dependencies for Supermaven ===
    curl     # Likely needed for network communication/authentication
    xdg-utils # Provides xdg-open for browser authentication flow
    # some dev helpers
    jq

    # --- because nix-shell didn't install the unstable version of awscli
    awscli2

    # LSPs
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    pyright
    nodePackages.bash-language-server
    nodePackages.dockerfile-language-server-nodejs
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
    # Add more as needed

    # zed-editor experiment -- does not allow for a minimalistic
    # no window decoration / top bar visualization, therefore skipped for now
    # zed-editor

    # another vscode experiment kajdo
    vscodium

  ];

  # environment.variables = {
  #   # Point to your manual installation
  #   CODEIUM_CHROMIUM = "$HOME/.codeium/codeium_chromium";
  # };
  
  # Open required ports

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # enable the tailscale service
  services.tailscale.enable = true;

  # enable sxhkd for shortcut management
  # services.sxhkd.enable = true;
  # services.sxhkd.extraPath = "/run/current-system/sw/bin/";

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall = {
    # for chromecast via brave
    allowedUDPPorts = [ 5353 ];  # For device discovery
    allowedUDPPortRanges = [{ from = 32768; to = 61000; }];  # For streaming
    # allowedTCPPorts = [ 8010 42100 50001];  # For Chromecast server, codeium1 und codeum2
    allowedTCPPorts = [ 8010 ];  # For Chromecast server
      # networking.firewall.allowedTCPPorts = [ 42100 50001 ];

  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment? 
}
