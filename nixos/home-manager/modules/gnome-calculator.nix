{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.gnome-calculator
  ];
}
