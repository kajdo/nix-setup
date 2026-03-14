{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Markdown reader
    glow

    # Game streaming client
    moonlight-qt

    # Note-taking app
    obsidian

    # Archive manager
    peazip

    # Finance tracking
    portfolio

    # Radio player
    pyradio

    # Video player
    mpv
  ];

  # mpv configuration
  xdg.configFile."mpv/mpv.conf" = {
    source = ./../config/mpv/mpv.conf;
  };
}
