{ config, pkgs, ... }:

{
  gtk = {
    enable = true;

    # GTK2 configuration (generates ~/.gtkrc-2.0)
    gtk2 = {
      enable = true;
      force = true; # Overwrite existing ~/.gtkrc-2.0

      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };

      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };

      font = {
        name = "Sans Bold 10";
      };

      extraConfig = ''
        gtk-cursor-theme-size=0
        gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
        gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
        gtk-button-images=0
        gtk-menu-images=0
        gtk-enable-event-sounds=1
        gtk-enable-input-feedback-sounds=1
        gtk-xft-antialias=1
        gtk-xft-hinting=1
        gtk-xft-hintstyle="hintmedium"
        gtk-xft-rgba="none"
      '';
    };

    # GTK3 configuration (generates ~/.config/gtk-3.0/settings.ini)
    gtk3 = {
      extraConfig = {
        gtk-theme-name = "Adwaita-dark";
        gtk-icon-theme-name = "Papirus-Dark";
        gtk-font-name = "Sans 10";
        gtk-cursor-theme-size = 0;
        gtk-toolbar-style = "GTK_TOOLBAR_BOTH_HORIZ";
        gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
        gtk-button-images = 0;
        gtk-menu-images = 0;
        gtk-enable-event-sounds = 1;
        gtk-enable-input-feedback-sounds = 1;
        gtk-xft-antialias = 1;
        gtk-xft-hinting = 1;
        gtk-xft-hintstyle = "hintmedium";
        gtk-xft-rgba = "none";
      };
    };

    # Shared theme settings (fallback for gtk2/gtk3 if not explicitly set)
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };
}
