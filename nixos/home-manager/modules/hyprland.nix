{ config, pkgs, ... }:

{
  # Graphics driver & GTK theme
  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
    GTK_THEME = "Adwaita";
    GTK_ICON_THEME = "Adwaita";
  };

  home.packages = with pkgs; [
    # Hyprland & Wayland tools
    rofi
    hyprprop
    waybar
    wdisplays
    swww
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
    gtk-engine-murrine
    gtk_engines
    adwaita-icon-theme
    papirus-icon-theme
    gnome-themes-extra
  ];

  # Terminal emulator
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrainsMono NFM";
      font_size = 11.0;
      background_opacity = "0.9";
      window_padding_width = 8;
      confirm_os_window_close = 0;
    };
  };
  xdg.configFile."kitty/kitty.conf".source = ./../config/kitty/kitty.conf;

  # Notification daemon
  services.dunst = {
    enable = true;
  };
  xdg.configFile."dunst/dunstrc".source = ./../config/dunst/dunstrc;

  # Rofi app launcher
  programs.rofi = {
    enable = true;
    theme = ./../config/rofi/themes/kajdo-mix.rasi;
    extraConfig = {
      show-icons = true;
      icon-theme = "Papirus";
      display-drun = "  ";
      display-window = "﩯 ";
      display-combi = "  ";
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
}
