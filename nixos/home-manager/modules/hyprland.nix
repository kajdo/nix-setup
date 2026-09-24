{ config, pkgs, ... }:

{
  # Graphics driver & GTK theme
  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    GTK_THEME = "Adwaita-dark";
    GTK_ICON_THEME = "Papirus-Dark";
  };

  home.packages = with pkgs; [
    # Hyprland & Wayland tools
    rofi
    hyprprop
    waybar
    wdisplays
    awww
    hyprlock
    hypridle
    dunst # Notification daemon
    libnotify # Notification library
    networkmanagerapplet # GUI applet for network management

    # Screenshot & clipboard tools
    grim
    slurp
    swappy
    wl-clipboard
    wl-clip-persist
    ueberzugpp

    # GTK themes
    gtk3
    adwaita-icon-theme
    papirus-icon-theme
    gnome-themes-extra
  ];

  # Terminal emulator
  programs.kitty = {
    enable = true;
    shellIntegration.enableBashIntegration = false;
  };
  xdg.configFile."kitty/kitty.conf".source = ./../config/kitty/kitty.conf;

  # Notification daemon
  services.dunst = {
    enable = true;
  };
  xdg.configFile."dunst/dunstrc".source = ./../config/dunst/dunstrc;

  # Hyprland compositor config (Lua format, Hyprland >= 0.55;
  # hyprlang hyprland.conf is ignored when hyprland.lua exists and was
  # removed upstream in 0.57)
  xdg.configFile."hypr/hyprland.lua".source = ./../config/hypr/hyprland.lua;

  # hyprlock / hypridle still use the hyprlang .conf format
  xdg.configFile."hypr/hyprlock.conf".source = ./../config/hypr/hyprlock.conf;
  xdg.configFile."hypr/hypridle.conf".source = ./../config/hypr/hypridle.conf;

  # Rofi app launcher
  programs.rofi = {
    enable = true;
    theme = ./../config/rofi/themes/kajdo-mix.rasi;
    settings = {
      show-icons = true;
      icon-theme = "Papirus";
      display-drun = "  ";
      display-window = " ";
      display-combi = "  ";
    };
  };

  # Additional rofi themes, scripts, and powermenu
  xdg.configFile."rofi/themes" = {
    source = ./../config/rofi/themes;
    recursive = true;
  };
  xdg.configFile."rofi/scripts" = {
    source = ./../config/rofi/scripts;
    recursive = true;
  };
  xdg.configFile."rofi/powermenu.sh".source = ./../config/rofi/powermenu.sh;

  # Waybar status bar
  # Using xdg.configFile instead of programs.waybar because config.jsonc has JSON with comments
  xdg.configFile."waybar" = {
    source = ./../config/waybar;
    recursive = true;
  };

  # Makima input remapping configs
  xdg.configFile."makima" = {
    source = ./../config/makima;
    recursive = true;
  };
}
