{ config, pkgs, ... }:

{
  home.sessionVariables = {
    GTK_THEME = "Adwaita";
    GTK_ICON_THEME = "Adwaita";
  };
}
