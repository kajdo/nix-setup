{ config, pkgs, ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Disable WiFi power save — prevents latency spikes during Moonlight streaming
  networking.networkmanager.wifi.powersave = false;

  # Firewall for Chromecast and local services
  networking.firewall = {
    allowedUDPPorts = [ 5353 ];  # Device discovery (mDNS)
    allowedUDPPortRanges = [{ from = 32768; to = 61000; }];  # Streaming
    allowedTCPPorts = [ 8010 ];  # Chromecast server
  };

  # Disable iwlwifi power save at driver level (belt-and-suspenders with NM setting above)
  boot.extraModprobeConfig = ''
    options iwlwifi power_save=0
  '';

  # Dirty Frag mitigation (CVE-2026-43284, CVE-2026-43500)
  # Blacklist vulnerable IPsec ESP and RxRPC kernel modules until patched kernel is available
  boot.blacklistedKernelModules = [ "esp4" "esp6" "rxrpc" "af_rxrpc" ];

  # Remote access
  services.openssh.enable = true;
  services.tailscale.enable = true;
}
