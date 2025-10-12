{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.slurp
  ];
}
