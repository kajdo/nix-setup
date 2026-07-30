# netconsole: forward ALL kernel printk messages to the always-on Raspberry Pi
# (192.168.1.8) over the wired USB-Ethernet dongle (enp0s20u1).
#
# WHY: this ThinkPad suffers silent hard freezes during Citrix sessions. The
# journal is useless for those wedges because nothing flushes in time. netconsole
# transmits each printk INLINE in the kernel's printk path (immediate UDP send),
# so it can capture the critical last messages journald never writes.
#
# RECEIVER (run on the Pi, one-liner):
#   sudo apt-get install -y socat; \
#   nohup socat -u UDP-RECV:6666,reuseaddr OPEN:$HOME/netconsole.log,append,creat \
#     >/dev/null 2>&1 &
#   watch live with:  tail -f ~/netconsole.log
#
# This service:
#   1. waits for the dongle to have an IPv4 (DHCP may lag at boot),
#   2. loads netconsole + ensures the configfs subdir exists,
#   3. configures a configfs target (bound to enp0s20u1 -> Pi, MAC hardcoded
#      so we never depend on ARP resolving DURING a freeze),
#   4. raises console loglevel to 8 so no message is filtered out,
#   5. emits a proof-of-life marker via /dev/kmsg (shows up on the Pi instantly).
#
# Caveat: loglevel 8 means debug-level kernel noise also flows (journald is
# already capped at 500M, and Hyprland hides the VT, so this is harmless).
# Revert to 4 with:  sudo systemctl stop netconsole-sender

{ config, pkgs, lib, ... }:

let
  # === netconsole target (edit here if the Pi moves) ===
  piIp  = "192.168.1.8";
  piMac = "2c:cf:67:32:e9:f3";   # hardcoded: no ARP dependency during a wedge
  port  = 6666;
  dev   = "enp0s20u1";           # USB-Ethernet dongle (wired, default route)
  targetName = "tp_freeze";      # configfs target name
  targetDir  = "/sys/kernel/config/netconsole/${targetName}";
in
{
  # load the module at boot so /sys/kernel/config/netconsole exists early
  boot.kernelModules = [ "netconsole" ];

  systemd.services.netconsole-sender = {
    description = "netconsole kernel-log forwarder -> Raspberry Pi (freeze capture)";
    documentation = [
      "https://www.kernel.org/doc/html/latest/networking/netconsole.html"
    ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    path = with pkgs; [ kmod iproute2 util-linux gawk coreutils ];

    script = ''
      set -u
      DEV=${dev}
      PI_IP=${piIp}
      PI_MAC=${piMac}
      PORT=${toString port}
      TARGET=${targetDir}

      # 1. wait for the dongle to get an IPv4 (DHCP may lag at boot)
      IP=""
      for i in $(seq 1 30); do
        IP=$(ip -4 -o addr show "$DEV" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
        if [ -n "$IP" ]; then break; fi
        sleep 1
      done
      if [ -z "$IP" ]; then
        echo "netconsole-sender: $DEV has no IPv4 after 30s, aborting" >&2
        exit 1
      fi

      # 2. ensure netconsole module + configfs subdir exist
      modprobe netconsole 2>/dev/null || true
      for i in $(seq 1 10); do
        [ -d /sys/kernel/config/netconsole ] && break
        sleep 0.5
      done
      if [ ! -d /sys/kernel/config/netconsole ]; then
        echo "netconsole-sender: /sys/kernel/config/netconsole missing (configfs not mounted?), aborting" >&2
        exit 1
      fi

      # 3. remove any stale target, then create + configure a fresh one
      if [ -d "$TARGET" ]; then
        echo 0 > "$TARGET/enabled" 2>/dev/null || true
        rmdir "$TARGET" 2>/dev/null || true
      fi
      mkdir -p "$TARGET"
      echo "$DEV"     > "$TARGET/dev_name"
      echo "$IP"      > "$TARGET/local_ip"
      echo "$PORT"    > "$TARGET/local_port"
      echo "$PI_IP"   > "$TARGET/remote_ip"
      echo "$PORT"    > "$TARGET/remote_port"
      echo "$PI_MAC"  > "$TARGET/remote_mac"
      echo 1 > "$TARGET/extended"   # richer per-message headers (facility/level/seq/ts)
      echo 1 > "$TARGET/enabled"

      # 4. raise console loglevel to 8 so ALL kernel messages are forwarded
      dmesg -n 8

      # 5. proof-of-life marker (should appear immediately on the Pi)
      echo "netconsole-sender UP: $(cat /proc/sys/kernel/hostname) $DEV@$IP -> $PI_IP:$PORT ($PI_MAC)" > /dev/kmsg

      # 6. log resolved binding state for diagnosis
      echo "netconsole-sender: forwarding $DEV@$IP -> $PI_IP:$PORT, enabled=$(cat "$TARGET/enabled" 2>/dev/null), local_mac=$(cat "$TARGET/local_mac" 2>/dev/null)"
    '';

    preStop = ''
      set -u
      TARGET=${targetDir}
      echo 0 > "$TARGET/enabled" 2>/dev/null || true
      rmdir "$TARGET" 2>/dev/null || true
      dmesg -n 4 2>/dev/null || true
      echo "netconsole-sender: stopped, loglevel restored to 4"
    '';
  };
}
