{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  # IPv6 disable - ISP issue workaround (upstream IPv6 path is dead).
  # `all` + `default` propagate to EVERY interface automatically, so we do NOT
  # enumerate specific NICs — the old `lo`/`wlp4s0` lines were redundant and
  # fragile (they missed `enp0s20u1`, silently relying on `all` to cover the
  # gap). Verify with: `ip -6 addr` shows no global addresses.
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = true;
    "net.ipv6.conf.default.disable_ipv6" = true;

    # --- Kernel oops / lockup handling ---
    # NOTE: panic_on_oops / hardlockup_panic / softlockup_panic are set to 0
    # (2026-07). At 1, they turned a transient oops during `nixos-rebuild
    # switch` (new kernel modules loaded into a still-running OLD kernel — e.g.
    # restarting libvirtd/kvm across a nixpkgs bump) into a hard panic +
    # 10s auto-reboot, crashing the running session and risking a boot loop.
    # At 0, such an oops only kills the offending process and the system limps
    # on. They are SET to 0 (not removed) so a `switch` disables them live —
    # no reboot needed. The safe path for nixpkgs bumps remains
    # `nixos-rebuild boot` + reboot.
    #
    # To re-enable GPU-lockup capture (auto-reboot on a frozen GPU), set these
    # three back to 1:
    "kernel.nmi_watchdog" = 1; # ARM the NMI hardlockup detector (logs, no panic)
    "kernel.hardlockup_panic" = 0; # disabled — hard lockup logs only, no panic
    "kernel.softlockup_panic" = 0; # disabled — soft lockup logs only, no panic
    "kernel.panic_on_oops" = 0; # disabled — oops kills process, system limps on
    "kernel.panic" = 10; # reboot 10s after a REAL panic (safety net)
  };

  # Fix USB devices sleeping after 2-3 seconds
  boot.kernelParams = [
    "usbcore.autosuspend=-1"

    # Work around the silent hard lockups on this Broadwell i915 (HD 5500).
    # Panel Self Refresh (PSR) hangs are a common cause of total silent
    # freezes on Broadwell; disabling it is the standard mitigation.
    #
    # Safe-category param: disables a feature, does NOT change panic behavior
    # (so it cannot cause the boot loop that the panic amplifiers did in
    # commits 3ee1ec9/2c360e2). Applied via `switch` is fine.
    #
    # Single-variable test (2026-07-20): if freezes persist, PSR wasn't the
    # cause — next candidates are i915.enable_dc=0 then intel_idle.max_cstate=2.
    "i915.enable_psr=0"
  ];

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
