{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.swappy
  ];
}
