{ config, pkgs, ... }:

{
  # Enable AppImages to be runnable as in other distros
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Local file sharing
  programs.localsend.enable = true;
  programs.localsend.openFirewall = true;

  # Firefox
  programs.firefox.enable = true;

  # Thunar file manager
  programs.thunar.enable = true;
  programs.thunar.plugins = with pkgs; [
    thunar-volman
    thunar-archive-plugin
  ];
}
