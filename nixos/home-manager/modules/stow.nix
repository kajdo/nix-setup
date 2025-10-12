{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.stow
  ];
}
