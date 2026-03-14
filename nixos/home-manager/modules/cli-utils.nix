{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    unzip
    appimage-run # Run AppImages without installation
  ];
}
