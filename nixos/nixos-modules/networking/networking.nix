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

  # Dirty Frag mitigation (CVE-2026-43284, CVE-2026-43500)
  # Blacklist vulnerable IPsec ESP and RxRPC kernel modules until patched kernel is available
  boot.blacklistedKernelModules = [ "esp4" "esp6" "rxrpc" "af_rxrpc" ];

  # Remote access
  services.openssh.enable = true;
  services.tailscale.enable = true;
}
