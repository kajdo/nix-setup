{ pkgs, ... }:

{
  home.packages = with pkgs; [
    rofi
    hyprprop
    waybar
    wdisplays
    swww
    hyprlock
    hypridle
  ];
}
