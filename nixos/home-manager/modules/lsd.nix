{ config, pkgs, ... }: 
{
  programs.lsd = {
    enable = true;
    enableBashIntegration = true;
  };
}
