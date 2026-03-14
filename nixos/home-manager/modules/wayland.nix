{ config, pkgs, ... }:

{
  # Graphics driver for Intel GPU
  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  home.packages = with pkgs; [
    rofi
    hyprprop
    waybar
    wdisplays
    swww
    hyprlock
    hypridle
    dunst # Notification daemon
    networkmanagerapplet # GUI applet for network management

    # Screenshot & clipboard tools
    grim
    slurp
    swappy
    wl-clipboard
    wl-clip-persist
    ueberzugpp
  ];
}
