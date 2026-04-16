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

    # Android screen/camera streaming (used with v4l2loopback as virtual webcam)
    scrcpy

    # Video4Linux utilities (v4l2-ctl for verifying virtual webcam)
    v4l-utils
  ];

  # mpv configuration
  xdg.configFile."mpv/mpv.conf" = {
    source = ./../config/mpv/mpv.conf;
  };

  # feh configuration
  programs.feh = {
    enable = true;
  };

  # pyradio configuration
  xdg.configFile."pyradio/config".source = ./../config/pyradio/config;
  xdg.configFile."pyradio/stations.csv".source = ./../config/pyradio/stations.csv;
}
