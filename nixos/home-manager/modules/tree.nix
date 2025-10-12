{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.tree
  ];
}
