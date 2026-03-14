{ config, pkgs, ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Firewall for Chromecast and local services
  networking.firewall = {
    allowedUDPPorts = [ 5353 ];  # Device discovery (mDNS)
    allowedUDPPortRanges = [{ from = 32768; to = 61000; }];  # Streaming
    allowedTCPPorts = [ 8010 ];  # Chromecast server
  };

  # Remote access
  services.openssh.enable = true;
  services.tailscale.enable = true;
}
