{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.glow
  ];
}
