{ config, pkgs, ... }:

{
  # Enable CUPS to print documents
  services.printing.enable = true;

  # Avahi for chromecast / network discovery
  services.avahi.enable = true;

  # USB mount support in Thunar
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;
}
