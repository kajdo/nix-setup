{ config, pkgs, ... }:

{
  # XDG Portal for Wayland apps
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
    config.common.default = "*";
  };

  # Flatpak support
  # First run: flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;

  environment.sessionVariables = {
    XDG_DATA_DIRS = [
      "/var/lib/flatpak/exports/share"
      "/home/$USER/.local/share/flatpak/exports/share"
    ];
  };

  # AppImage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Local file sharing
  programs.localsend.enable = true;
  programs.localsend.openFirewall = true;

  # Thunar file manager
  programs.thunar.enable = true;
  programs.thunar.plugins = with pkgs; [
    thunar-volman
    thunar-archive-plugin
  ];
}
