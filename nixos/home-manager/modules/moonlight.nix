{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.moonlight-qt
  ];
}
