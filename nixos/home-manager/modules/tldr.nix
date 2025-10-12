{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.tldr
  ];

  services.tldr-update = {
    enable = true;
    period = "weekly";
  };
}
