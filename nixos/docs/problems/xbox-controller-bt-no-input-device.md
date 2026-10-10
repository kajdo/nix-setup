# Xbox Controller over Bluetooth: pairs, but never becomes an input device

## 2026-10-09: Full diagnosis (open — known fix deliberately NOT applied yet)

### Symptom

Xbox Wireless Controller pairs successfully over BLE and shows
`Connected: yes`, but **no input device is created** — nothing in
`/proc/bus/input/devices`, no `/dev/input/event*`, no hidraw, no
`hid-microsoft` module load. The controller keeps half-connecting in a loop
(`Connected: yes/no` flapping) or sits connected but dead.

Bluetooth itself is healthy on this machine (audio devices pair and work).

### Hardware / software facts (collected)

| What | Value |
|---|---|
| Controller | Xbox Wireless Controller, MAC `78:86:2E:81:6A:CF` |
| Model | 1914 (Series X\|S, BLE), USB `v045E p0B13` |
| Controller firmware | **5.9** (modalias `d0509`) — old; 5.13+ improved BLE behavior |
| Battery | 82 % (reads fine over GATT = link encryption works) |
| Adapter | `4C:34:88:2B:DB:84` (Intel; the chronically flaky one, see `docs/hints/pipewire-bluetooth-audio.md` 09-15…09-28 history) |
| BlueZ | **5.87** (`/nix/store/…-bluez-5.87`) |
| Kernel | `CONFIG_HID_MICROSOFT=m`, `CONFIG_JOYSTICK_XPAD=m` (+FF, +LEDs), `uhid` loaded — all fine |
| `/etc/bluetooth/main.conf` | only `ControllerMode=dual`, `AutoEnable=true` — **no `Privacy=` line** (BlueZ default applies) |
| bluetoothd cmdline | plain `bluetoothd -f /etc/bluetooth/main.conf`, no `--experimental` |

### Diagnosis chain — ruled in / out

- **Pairing/key exchange: WORKS.** `Paired: yes`, `Bonded: yes`, `Trusted: yes`,
  LTKs exchanged, battery service reads over encrypted GATT succeed.
- **Encryption: WORKS** (battery read at 82 % requires an encrypted link;
  the pre-bond "Encryption required" errors stopped after bonding).
- **HOG attach: FAILS.** bluetoothd retries every ~3 s:

  ```
  profiles/input/hog-lib.c:info_read_cb() HID Information read failed:
      Request attribute has encountered an unlikely error
  profiles/input/hog-lib.c:report_reference_cb() Read Report Reference descriptor failed:
      Request attribute has encountered an unlikely error
  ```

  "Unlikely error" = **ATT error 0x0E**: the controller accepts the BLE
  connection but refuses GATT reads, so BlueZ can never build the HID device
  (no Report Map → no uhid node → no input device).
- **ServicesResolved flaps** `yes → no` right after pairing — GATT discovery
  starts and dies.
- **Not** a kernel/driver problem: uhid is loaded, hid-microsoft is available,
  it simply never gets a device.
- **Not** a stale-bond problem: fresh `remove` + re-pair reproduced identical
  behavior twice.

### Root cause (hypothesis, high confidence)

Known **BlueZ 5.8x BLE privacy regression**: with LE address privacy active
(rotating RPA / `Privacy=device`), GATT discovery on BLE HID devices fails
with exactly ATT 0x0E → no input device. Documented for BlueZ 5.84+ builds
with Xbox controllers; upstream fix claimed for 5.85 but the report pattern
extends to newer builds (we run 5.87).

References:

- https://github.com/ublue-os/bazzite/issues/3789 (Xbox controllers "never
  appear as input devices", BlueZ 5.84 privacy issue)
- https://bitorbiter.de/en/archive/359 (analysis + `Privacy=off` workaround;
  same hog-lib error lines, same one-line fix)
- Related symptom class (older BlueZ/kernel, same error):
  https://github.com/bluez/bluez/issues/155,
  https://github.com/atar-axis/xpadneo/issues/558

Open nuance, to verify when applying the fix: our `main.conf` does **not**
set `Privacy=device` explicitly. If `Privacy=off` fixes it, that implies
5.87 enables privacy by default (or the adapter resolves IRKs badly).
Either way the explicit-off setting is the harmless, testable lever.

### The known fix (NOT applied — deliberately skipped 2026-10-09)

In `nixos-modules/hardware/bluetooth.nix`:

```nix
hardware.bluetooth.settings = {
  General.Privacy = "off";
};
```

Then `lull`, then **remove + re-pair** the controller (a bond made under
privacy stays broken — re-pairing is mandatory):

```bash
bluetoothctl remove 78:86:2E:81:6A:CF
sudo systemctl restart bluetooth   # or just lull/rebuild
# → controller into pairing mode (hold top pair button until fast blink),
#   then pair (procedure below)
```

**Trade-off:** adapter uses its static public address instead of rotating
BLE addresses → slightly more trackable. Non-issue for a stationary desktop
per the Bazzite write-up.

**Check afterwards** that GATT discovery actually completed (it never did
during the incident):

```bash
bluetoothctl info 78:86:2E:81:6A:CF | grep ServicesResolved   # must stay: yes
grep -A6 -i xbox /proc/bus/input/devices                      # input node must exist
```

### Re-pair procedure that worked (keep this!)

One-shot `bluetoothctl pair <MAC>` **always fails** with
`No agent available for request type 2` — no pairing agent is registered
outside an interactive session. This paced session is what produced a
successful bond (twice):

```bash
(sleep 1; echo "agent on"; sleep 1; echo "default-agent"; sleep 1; echo "scan on";
 # wait until the controller actually shows up in the scan:
 for i in $(seq 1 20); do bluetoothctl devices | grep -q '78:86:2E:81:6A:CF' && break; sleep 3; done
 echo "pair 78:86:2E:81:6A:CF"; sleep 20   # let the pairing handshake finish!
 echo "scan off"; echo "trust 78:86:2E:81:6A:CF"; sleep 3) | timeout 95 bluetoothctl
```

Gotchas learned the hard way:

- Pairing needs the controller in **pairing mode** (fast blink), and the
  Xbox pairing window is only ~30 s.
- Do **not** fire `connect` right after `pair` in the same session without
  a gap — it interrupts the handshake.
- After a successful bond, leave the connection alone; a forced
  `disconnect`/`connect` cycle left `ServicesResolved` permanently `no`
  on the pre-fix stack.
- Xbox button power-cycle (controller-initiated reconnect) is the correct
  reconnect method for a trusted bond — PC-initiated `connect` gave
  half-dead GATT links on the pre-fix stack.

### Current state (2026-10-09, end of session)

- Controller pairing **removed entirely** from BlueZ
  (`bluetoothctl remove 78:86:2E:81:6A:CF`) — it kept auto-connecting
  on power-on (dead link, no input device), so the bond was wiped to stop
  the noise. When picking this up: re-pair from scratch via the procedure
  below. Note: the controller itself may still remember the PC and attempt
  to connect; pairing it to another device (phone/console) or re-pairing
  after the fix replaces the stale bond.
- Working around the issue via **USB cable**: `xpad` driver auto-loads
  (`CONFIG_JOYSTICK_XPAD=m` incl. rumble/LEDs), works instantly, charges.
- Repo and `/etc/nixos` clean — no config changes were kept.

### If `Privacy=off` does NOT fix it — escalation ladder

1. **Confirm privacy actually off at runtime**: debug-run bluetoothd
   (`sudo bluetoothd -n -d`, needs root terminal) and watch the connect
   attempt — check whether the adapter advertises RPA.
2. **Controller firmware update to ≥ 5.13** (ideally latest, ~5.22) via
   Xbox Accessories app on Windows/console. Multiple reports of BLE
   reliability fixes in newer fw. Then remove + re-pair.
3. **Rule out the flaky Intel adapter** (see pipewire-bluetooth-audio
   incidents): test the controller against a different BT adapter
   (cheap USB dongle) or a phone.
4. Check upstream BlueZ/kernel tracker for the privacy regression fix
   landing; then revert `Privacy=off` to regain address rotation.
5. Last resort: stay on USB (works, zero config).

### Pickup checklist for the next session

- [ ] Apply `General.Privacy = "off"` in `nixos-modules/hardware/bluetooth.nix`, run `lull`
- [ ] Re-pair via the paced procedure above (device was removed, no bond exists)
- [ ] Verify `ServicesResolved: yes` stays, input device appears in `/proc/bus/input/devices`
- [ ] If fixed: consider documenting `Privacy=off` trade-off here and revisit when BlueZ gets the upstream fix
- [ ] If not fixed: escalation ladder above
