{ config, pkgs, ... }:

{
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  
  # IPv6 issue - not sure if ISP issue, but try to fix
  # `ip -6 a` should not have any result after that
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = true;
    "net.ipv6.conf.default.disable_ipv6" = true;
    "net.ipv6.conf.lo.disable_ipv6" = true;
    "net.ipv6.conf.wlp4s0.disable_ipv6" = true;
  };

  # after reboot keyboard and other usb devices "slept after 2-3 seconds"
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];
  
  # set default timeout to 10s - many times reboot waits 90s
  systemd.settings = {
    Manager = {
      DefaultTimeoutStopSec = "10s";
    };
  };
}