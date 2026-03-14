{ config, pkgs, ... }:

{
  # Printing
  services.printing.enable = true;

  # Network discovery (Chromecast, AirPlay, etc.)
  services.avahi.enable = true;

  # Thunar USB mount support
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;  # Thumbnails
}
