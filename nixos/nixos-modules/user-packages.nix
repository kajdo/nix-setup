{ config, pkgs, ... }:

{
  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.kajdo = {
    isNormalUser = true;
    description = "kajdo";
    extraGroups = [ "networkmanager" "wheel" "video" "docker" ];
    packages = with pkgs; [
      git
      delta         # git diff viewer
      alacritty     # Works natively on Wayland
      starship
      tmux
      rofi # Use wofi instead for Wayland
      tailscale
      vivaldi
      vivaldi-ffmpeg-codecs
      # moonlight-qt
      libreoffice-qt6-fresh
      makima
      signal-desktop-bin # signal had problems with update to unstable -- installed via flatpak
      hyprprop
      waybar
      wdisplays
    ];
  };
}
