{ config, pkgs, ... }:

{
  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Firewall configuration for chromecast and other services
  networking.firewall = {
    # for chromecast via brave
    allowedUDPPorts = [ 5353 ];  # For device discovery
    allowedUDPPortRanges = [{ from = 32768; to = 61000; }];  # For streaming
    allowedTCPPorts = [ 8010 ];  # For Chromecast server
  };

  services.openssh.enable = true;
  services.tailscale.enable = true;
}