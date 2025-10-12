{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.pulsemixer
  ];
}
