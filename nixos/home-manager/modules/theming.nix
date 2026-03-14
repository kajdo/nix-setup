{ config, pkgs, ... }:

{
  # GTK Theme Settings
  home.sessionVariables = {
    GTK_THEME = "Adwaita";
    GTK_ICON_THEME = "Adwaita";
  };

  # Theme Packages
  home.packages = with pkgs; [
    papirus-icon-theme
    gnome-themes-extra

    # GTK Themes
    gtk3
    gtk-engine-murrine
    gtk_engines
    adwaita-icon-theme
  ];
}
