# netconsole: forward ALL kernel printk messages to the always-on Raspberry Pi
# (192.168.1.8) over the wired USB-Ethernet dongle (enp0s20u1).
#
# WHY: this ThinkPad suffers silent hard freezes during Citrix sessions. The
# journal is useless for those wedges because nothing flushes in time. netconsole
# transmits each printk INLINE in the kernel's printk path (immediate UDP send),
# so it can capture the critical last messages journald never writes.
#
# RECEIVER (on the Pi): the old nohup-socat one-liner died silently on 2026-07-30
# and the 2026-08-16 GPU HANG was lost. Use the systemd unit documented in
#   docs/hints/netconsole-receiver-pi.md
#   watch live with:  tail -f ~/netconsole.log
#
# This service:
#   1. waits for the dongle to have an IPv4 (DHCP may lag at boot),
#   2. skips cleanly (exit 0) on a FOREIGN network — this laptop travels, and
#      netconsole frames are MAC-addressed to the Pi, so they can never be
#      delivered from another LAN anyway (and must not leak kernel logs there),
#   3. loads netconsole + ensures the configfs subdir exists,
#   4. configures a configfs target (bound to enp0s20u1 -> Pi, MAC hardcoded
#      so we never depend on ARP resolving DURING a freeze),
#   5. raises console loglevel to 8 so no message is filtered out,
#   6. emits a proof-of-life marker via /dev/kmsg (shows up on the Pi instantly).
#
# Self-heal: netconsole-heal.timer (every 5 min) re-runs the sender when the
# machine is back on the home subnet but the target is NOT enabled (booted
# away and returned without a reboot; DHCP slower than the 30 s wait; dongle
# replug after a failed auto-resume). Without it, a failed boot away from home
# would leave netconsole dead until the next reboot.
#
# Caveat: loglevel 8 means debug-level kernel noise also flows (journald is
# already capped at 500M, and Hyprland hides the VT, so this is harmless).
# Revert to 4 with:  sudo systemctl stop netconsole-sender

{ config, pkgs, lib, ... }:

let
  # === netconsole target (edit here if the Pi moves) ===
  piIp = "192.168.1.8";
  piMac = "2c:cf:67:32:e9:f3"; # hardcoded: no ARP dependency during a wedge
  port = 6666;
  dev = "enp0s20u1"; # USB-Ethernet dongle (wired, default route)
  targetName = "tp_freeze"; # configfs target name
  targetDir = "/sys/kernel/config/netconsole/${targetName}";
  homeSubnet = "192.168.1."; # sender guard + heal check only arm on this LAN
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

      # 1.5 foreign-network guard: frames are MAC-addressed to the Pi and can
      # never be delivered from another LAN; enabling netconsole there would
      # pointlessly (and insecurely) spray kernel logs into a foreign network.
      # Skip cleanly — the heal timer re-arms us once we are home again.
      case "$IP" in
        ${homeSubnet}*) ;;
        *)
          echo "netconsole-sender: foreign network ($IP on $DEV), netconsole skipped" >&2
          exit 0
          ;;
      esac

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

  # ---- self-heal ------------------------------------------------------------
  # netconsole-sender is Type=oneshot and only runs at boot. This check (every
  # 5 min) restarts it when we are on the home subnet but the configfs target
  # is not enabled. Covers: booted away -> returned home (no reboot), DHCP
  # slower than the sender's 30 s wait, dongle replug after netconsole's
  # one-shot auto-resume gave up (STATE_DEACTIVATED -> DISABLED is permanent).
  # When away from home or already armed it is a no-op (exit 0, no marker spam,
  # no teardown of a working target).
  systemd.services.netconsole-heal = {
    description = "Re-arm netconsole when back on the home network";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig.Type = "oneshot";

    path = with pkgs; [ iproute2 gawk coreutils systemd ];

    script = ''
      set -u
      DEV=${dev}
      TARGET=${targetDir}

      # Only act on the home subnet.
      IP=$(ip -4 -o addr show "$DEV" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
      case "$IP" in
        ${homeSubnet}*) ;;
        *) exit 0 ;;
      esac

      # Target already live -> nothing to heal. (A stale local_ip after a DHCP
      # change is cosmetic: frames are MAC-addressed and still delivered.)
      if [ -d "$TARGET" ] && [ "$(cat "$TARGET/enabled" 2>/dev/null)" = "1" ]; then
        exit 0
      fi

      # Don't race a sender that is still starting (its 30 s DHCP wait).
      if [ "$(systemctl show -p ActiveState --value netconsole-sender.service)" = "activating" ]; then
        exit 0
      fi

      echo "netconsole-heal: home network ($IP) but target not enabled -> restarting netconsole-sender"
      systemctl restart netconsole-sender.service || true
    '';
  };

  systemd.timers.netconsole-heal = {
    description = "Periodically re-arm netconsole on the home network";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
    };
  };
}
