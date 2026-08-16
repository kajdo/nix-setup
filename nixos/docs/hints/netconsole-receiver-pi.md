# netconsole receiver on the Raspberry Pi (nvmeberry, 192.168.1.8)

## Why

`netconsole-sender` (see `nixos-modules/services/netconsole.nix`) forwards every
kernel printk inline via UDP to the Pi — the local journal is useless during
real wedges. But the receiver was a fragile `nohup socat` one-liner: it died
silently on **2026-07-30 12:57** (no process, nothing listening on UDP 6666).
The **2026-08-16 16:28:57 GPU HANG** was therefore forwarded into the void.

Target state: receiver runs as a **systemd system unit with `Restart=always`**
on the Pi → survives reboots, crashes and logouts.

## 1. Receiver unit (survives reboots) — on the Pi

Create `/etc/systemd/system/netconsole-receiver.service`:

```ini
[Unit]
Description=netconsole UDP receiver (ThinkPad kernel-log capture)
After=network-online.target
Wants=network-online.target

[Service]
User=kajdo
Group=kajdo
ExecStart=/usr/bin/socat -u UDP-RECV:6666,reuseaddr OPEN:/home/kajdo/netconsole.log,append,creat
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Enable + verify:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now netconsole-receiver
ss -uln | grep 6666        # must show a LISTEN entry
```

socat is already installed (`/usr/bin/socat`, Debian 12).

## 2. Log rotation — on the Pi

`/etc/logrotate.d/netconsole`:

```
/home/kajdo/netconsole.log {
    weekly
    rotate 8
    compress
    missingok
    notifempty
}
```

## 3. End-to-end verification — from the ThinkPad

```bash
sudo systemctl restart netconsole-sender    # re-emits the UP marker via /dev/kmsg
ssh kajdo@192.168.1.8 'tail -3 ~/netconsole.log'   # marker must appear instantly
```

Live watch during a freeze: `ssh kajdo@192.168.1.8 'tail -f ~/netconsole.log'`

## 4. Option B: watchdog from the ThinkPad (belt + suspenders, NOT applied)

The unit above already covers ~all failure modes. If you want the ThinkPad to
also self-heal the receiver, add on the Pi a targeted passwordless rule,
`/etc/sudoers.d/netconsole-receiver`:

```
kajdo ALL=(root) NOPASSWD: /usr/bin/systemctl start netconsole-receiver.service, /usr/bin/systemctl restart netconsole-receiver.service
```

Then run this (manually, from a timer, or as a small NixOS module) every
~10 min on the ThinkPad:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=4 kajdo@192.168.1.8 \
  'ss -uln | grep -q ":6666" || sudo -n systemctl restart netconsole-receiver.service'
```

Caveats:

- A systemd-run watchdog needs ssh auth that works without an interactive
  agent (unencrypted key or key with no passphrase for `kajdo@pi`). The
  current interactive setup works fine for manual use.
- Keep the sudo rule narrowed to exactly the two commands above — nothing else.
