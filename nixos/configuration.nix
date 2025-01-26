# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

let
  # Define the individual build packages
  dwmblocks    = pkgs.callPackage ./pkgs/dwmblocks.nix {};
  st           = pkgs.callPackage ./pkgs/st.nix {};
in {
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
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



   services.xserver.displayManager.lightdm.enable = true;
   #services.xserver.desktopManager.lxqt.enable = true;

   services.xserver.windowManager.dwm.enable = true;
   nixpkgs.overlays = [
      (final: prev: {
         dwm = prev.dwm.overrideAttrs (old: {src = ./pkgs/source/dwm-kajdo;}); 
      })
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
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
    #  thunderbird
       btop
       tldr
       fastfetch
       stow
       git
       alacritty
       aider-chat
       starship
       ueberzugpp
       yazi
       yt-dlp
       mcfly
       mcfly-fzf
       fzf
       chatterino2
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
       picom
       xclip
       tailscale
       chatblade
       ncdu
       cmatrix
       cava
       moonlight-qt
    ];
  };

  environment.sessionVariables = {
    PATH = [ "/home/kajdo/.local/bin" ];
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
     wget
     wget2 # better for some downloads
     toybox # pgrep and other fun stuff
     dwmblocks 
     st
     xfce.thunar
     neovim
     unclutter-xfixes
     gcc
     lua
     luajitPackages.luarocks_bootstrap
     unzip
     python39
     pipx
     networkmanagerapplet
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
     # volumecontrol
     volumeicon
     # keyboard shortcut daemon
     sxhkd


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
     # Add more as needed
  ];

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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment? 
}
