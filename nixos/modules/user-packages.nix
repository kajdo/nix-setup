{ config, pkgs, ... }:

{
  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.kajdo = {
    isNormalUser = true;
    description = "kajdo";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
      btop
      hyprprop
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
}
