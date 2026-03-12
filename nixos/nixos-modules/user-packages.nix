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
      starship
      tmux
      rofi
      tailscale
      libreoffice-qt6-fresh
      makima
      signal-desktop-bin
      hyprprop
      waybar
      wdisplays
    ];
  };
}
