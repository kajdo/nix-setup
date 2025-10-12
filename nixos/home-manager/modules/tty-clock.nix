{ config, pkgs, ... }: 

{
  home.packages = [
    pkgs.tty-clock
  ];
}
