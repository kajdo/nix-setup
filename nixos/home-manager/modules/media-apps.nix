{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Image viewer
    feh

    # Markdown reader
    glow

    # Game streaming client
    moonlight-qt

    # Audio mixer
    pulsemixer

    # Radio player
    pyradio

    # Video player
    mpv
  ];

  # mpv configuration
  xdg.configFile."mpv/mpv.conf" = {
    source = ./../config/mpv/mpv.conf;
  };

  # feh configuration
  programs.feh = {
    enable = true;
  };
}
