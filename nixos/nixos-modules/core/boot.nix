{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # IPv6 disable - ISP issue workaround
  # `ip -6 a` should not have any result after that
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = true;
    "net.ipv6.conf.default.disable_ipv6" = true;
    "net.ipv6.conf.lo.disable_ipv6" = true;
    "net.ipv6.conf.wlp4s0.disable_ipv6" = true;
  };

  # Fix USB devices sleeping after 2-3 seconds
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  # Reduce default timeout from 90s to 10s
  systemd.settings = {
    Manager = {
      DefaultTimeoutStopSec = "10s";
    };
  };
}
