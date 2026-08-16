# gpu-error-capture: persist i915 GPU error-state dumps into the local repo
#
# WHY: 2026-08-16 16:28:57 this machine hit an i915 "GPU HANG ... Resetting rcs0"
# (Broadwell HD 5500) — a ~20s system-wide stall. The error state in
# /sys/class/drm/card0/error contains the full hang analysis dump, but it is
# ephemeral: root-only readable, overwritten by the next hang, lost on reboot.
#
# This module polls the sysfs node every 5 minutes and, whenever a NEW error
# dump appears, saves it plus surrounding kernel-log context into
#   /home/kajdo/git/nix-setup/logs/   (gitignored via the root .gitignore)
#
# Design notes:
# - TIMER, not a systemd .path unit: sysfs binary attributes report size 0 and
#   i915 does not call sysfs_notify() for the error node, so inotify events are
#   not reliable for it. Polling is cheap and never misses a dump, because the
#   error state persists until the NEXT hang (or reboot) overwrites it.
# - Dedupe: the dump is stable between reads; cmp against the newest captured
#   file prevents recapturing the same hang on every tick.

{ config, pkgs, ... }:

let
  # Destination: logs/ dir of this very repo. Machine-specific by design,
  # like the rest of this configuration (hardware-configuration is also local).
  outdir = "/home/kajdo/git/nix-setup/logs";
in
{
  systemd.services."gpu-error-capture" = {
    description = "Capture i915 GPU error state dumps into ~/git/nix-setup/logs";
    path = with pkgs; [ coreutils gnugrep systemd ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -u
      src="/sys/class/drm/card0/error"
      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT

      # Read current error state ("no error state collected" or empty = no hang).
      cat "$src" > "$tmp" 2>/dev/null || exit 0
      if [ "$(wc -c < "$tmp")" -lt 200 ]; then exit 0; fi
      if grep -q "no error state collected" "$tmp"; then exit 0; fi

      # Skip if identical to the newest already-captured dump.
      newest="$(ls -1t "${outdir}"/gpu-error-*.txt 2>/dev/null | head -n1 || true)"
      if [ -n "$newest" ] && cmp -s "$tmp" "$newest"; then exit 0; fi

      # New hang: persist dump + kernel-log context for correlation.
      mkdir -p "${outdir}"
      ts="$(date +%Y%m%d-%H%M%S)"
      # Collision guard: a *different* hang captured within the same second
      # must not overwrite the previous file — bump a -1, -2, ... suffix.
      n=1
      while [ -e "${outdir}/gpu-error-$ts.txt" ]; do
        ts="$(date +%Y%m%d-%H%M%S)-$n"
        n=$((n + 1))
      done
      out="${outdir}/gpu-error-$ts.txt"
      mv "$tmp" "$out"
      chown kajdo:users "$out"
      chmod 644 "$out"
      journalctl -k --since "-30 min" --no-pager \
        > "${outdir}/gpu-context-$ts.log" 2>/dev/null || true
      chown kajdo:users "${outdir}/gpu-context-$ts.log" 2>/dev/null || true
      echo "gpu-error-capture: new GPU error dump captured -> $out"
    '';
  };

  systemd.timers."gpu-error-capture" = {
    description = "Poll i915 GPU error state every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      Persistent = true;
    };
  };
}
