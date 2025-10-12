{ config, pkgs, ... }: 
{
  programs.lazydocker = {
    enable = true;
  };
}
