{ config, pkgs, ... }:

{
  # Display Manager
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Window Manager
  programs.hyprland.enable = true;

  # Auto-login
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kajdo";
  services.displayManager.defaultSession = "hyprland";

  # Keyboard layout
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };
}
