{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.ncdu
  ];
}
