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

    # --- Capture a hard GPU/system lockup instead of dying silently ---
    "kernel.nmi_watchdog"     = 1;   # ARM the NMI hardlockup detector (was 0/disarmed!)
    "kernel.hardlockup_panic" = 1;   # NMI-detected hard lockup -> panic
    "kernel.softlockup_panic" = 1;   # CPU stuck in kernel >20s -> panic
    "kernel.panic_on_oops"    = 1;   # kernel oops -> panic (instead of limping on)
    "kernel.panic"            = 10;  # reboot 10s after any panic
  };

  # Fix USB devices sleeping after 2-3 seconds
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];

  # Swap file (8GB) to prevent OOM freezes
  swapDevices = [
    { device = "/var/lib/swapfile"; size = 8192; }
  ];

  # Reduce default timeout from 90s to 10s
  systemd.settings = {
    Manager = {
      DefaultTimeoutStopSec = "10s";
    };
  };
}
