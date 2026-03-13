{ pkgs, ... }:

{
  xdg.configFile."mpv/mpv.conf" = {
    source = ./../config/mpv/mpv.conf;
  };

  home.packages = with pkgs; [
    mpv
  ];
}
