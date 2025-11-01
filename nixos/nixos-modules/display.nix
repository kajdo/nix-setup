{ config, pkgs, ... }:

{
  # Enable Hyprland and SDDM
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  programs.hyprland.enable = true;

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "kajdo";
  services.displayManager.defaultSession = "hyprland";

  # Configure keymap
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };
}
