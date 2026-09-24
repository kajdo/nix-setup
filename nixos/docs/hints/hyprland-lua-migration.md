# Hyprland hyprlang → Lua migration runbook

Goal: switch the compositor config from `~/.config/hypr/hyprland.conf` (hyprlang,
support removed in Hyprland 0.57) to `~/.config/hypr/hyprland.lua` (deployed from
this repo via Home Manager), and verify it live — **without logout/reboot**.

## Why this cannot break the running desktop

- Hyprland decides `.lua` vs `.conf` **once at startup**. Deploying `hyprland.lua`
  does not touch the running session; auto-reload never switches formats.
- The switch happens only when YOU run `hyprctl reload full-reset` (verified to
  exist in both v0.55.4 and v0.56.2).
- On a fundamental Lua syntax error the reload is **refused** and the current
  config keeps running. A config that loads with zero binds gets emergency binds:
  `SUPER+Q` (terminal), `SUPER+R` (launcher), `SUPER+M` (exit Hyprland).
- Rollback is one command pair and needs no logout (Phase F).

## Phase A — prep (once, right before `lull`)

Home Manager refuses to overwrite existing *regular* files. `hyprlock.conf` and
`hypridle.conf` currently exist as real files, so rename them aside (identical
copies now live in the repo; originals also in `~/.config/bak_hypr/`).

Do this **immediately before** running `lull` to keep the gap to a few seconds.

```bash
mv ~/.config/hypr/hyprlock.conf ~/.config/hypr/hyprlock.conf.pre-managed
mv ~/.config/hypr/hypridle.conf ~/.config/hypr/hypridle.conf.pre-managed
```

**Why this cannot affect the running session:** configs are read per process,
never by the running compositor. Hyprland only watches **its own** config
(`hyprland.conf` — that's why gap edits apply live) — it never reads
hypridle.conf/hyprlock.conf. hypridle read its config once at daemon start
and has no file watcher at all (verified in its source). hyprlock reads its
config only when it *launches*; the one caveat: if you press `SUPER+L` in the
few-seconds gap while no config exists, hyprlock exits with "Config path
error" and simply does not lock (no lock screen, session unaffected —
verified in hyprlock's main.cpp). After `lull` the symlink restores identical
behavior. (`hyprland.lua` does not exist yet → no conflict. Do NOT touch
`~/.config/hypr/hyprland.conf` — it stays as the fallback.)

## Phase B — deploy

Run `lull` as usual. It includes the journald/GTK2/gomuks fixes plus:

- `~/.config/hypr/hyprland.lua`   (new, symlink → Nix store)
- `~/.config/hypr/hyprlock.conf`  (symlink, content identical to before)
- `~/.config/hypr/hypridle.conf`  (symlink, dpms commands updated for Lua era)

If `nixos-rebuild` fails for unrelated reasons: nothing changes on the desktop,
stay calm, report the error.

## Phase C — verify deployment (read-only)

```bash
ls -la ~/.config/hypr/
```

Expect `hyprland.lua`, `hyprlock.conf`, `hypridle.conf` as symlinks pointing
into `/etc/profiles/per-user/kajdo/...`. `hyprland.conf` still present as a
regular file. Desktop is still running the OLD config at this point.

## Phase D — the switch (live, no logout)

```bash
hyprctl reload full-reset
```

Hyprland re-reads everything from `hyprland.lua` on the spot. Open windows,
waybar, dunst, etc. keep running. Ideally: no visible change at all.

Note: `hyprland.start` autostart does NOT re-fire on `full-reset` (the
compositor did not restart) — waybar & co. keep running from session start, and
the autostart will fire normally on the next real Hyprland start.

Then check for config errors:

```bash
hyprctl configerrors
```

Expect empty output.

Optional but recommended right after a successful switch: restart the hypridle
daemon so it picks up the new config (it still holds the old one in memory):

```bash
pkill hypridle; nohup hypridle >/dev/null 2>&1 &
```

## Phase E — test checklist (~3 min)

- [ ] `SUPER+T` / `ALT+T` / `SUPER+Return` / `F12` → kitty opens
- [ ] `ALT+SHIFT+T` → scratchpad kitty (floating, right side, ~20%x50%)
- [ ] `SUPER+Q` → closes focused window
- [ ] `SUPER+R` → rofi launcher; `SUPER+SHIFT+R` → wofi
- [ ] `SUPER+E` → thunar
- [ ] `SUPER+1..9,0` and `ALT+1..0` → workspace switch; `SUPER+I/U` → relative
- [ ] `SUPER+SHIFT+2` → moves window to ws 2 AND follows it
- [ ] `ALT+comma` → focus jumps to the other monitor
- [ ] `ALT+B` → special workspace "magic" toggles
- [ ] `SUPER+J` / `SUPER+K` → cycle windows (master layout)
- [ ] `SUPER+H` shrinks / `ALT+L` grows the master area
- [ ] `ALT+F` fullscreen; `SUPER+M` maximize
- [ ] Mouse: `SUPER+LMB` drags, `SUPER+RMB` resizes
- [ ] Touchpad: `ALT+SHIFT+M` disables → `ALT+SHIFT+N` re-enables
- [ ] Touchpad: 3- and 4-finger horizontal swipe switches workspaces
- [ ] Look: gradient border on active window, gaps 5/15, rounding 10, blur
- [ ] (when ready) `SUPER+L` → hyprlock shows the usual screen, password unlocks

## Phase F — rollback (exact, no logout needed)

If anything is broken and you just want the old behavior back:

```bash
rm ~/.config/hypr/hyprland.lua && hyprctl reload full-reset
```

- `rm` deletes only the Home-Manager **symlink**; the real file stays in the
  Nix store and in this repo — nothing is lost.
- `full-reset` finds no `.lua` → falls back to `hyprland.conf` → old config is
  live again in the same session.

To re-try the Lua config afterwards: run `lull` (recreates the symlink), then
repeat Phase D.

## Phase G — emergency (frozen session — not expected)

`CTRL+ALT+F3` → TTY login → `rm ~/.config/hypr/hyprland.lua` → `sudo reboot`
→ session comes up on `hyprland.conf`.

## Phase H — after some days of confidence (align again before doing it!)

Delete the fallback files:

```bash
rm ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak-* \
   ~/.config/hypr/bak_hyprland.conf \
   ~/.config/hypr/hyprlock.conf.pre-managed ~/.config/hypr/hypridle.conf.pre-managed
```

(Keep `~/.config/bak_hypr/` as long as you want.)

## Troubleshooting: portals dead after a switch (known NixOS flake)

Symptom: `xdg-desktop-portal.service` fails with `Dependency failed`, journal
says `Current graphical user session is inactive`. Mid-switch user-unit churn
stops `graphical-session.target`, and nothing re-raises it until the next
login (only the session bridge pulls it up). The Hyprland/GTK backends keep
running fine — only the main portal refuses to start (`Requisite=`).

Fix (no sudo, works mid-session):

```bash
systemctl --user start nixos-fake-graphical-session.target
systemctl --user start xdg-desktop-portal.service
```

(The bridge target `BindsTo=graphical-session.target`, which is the
designed-in way to raise it; it refuses direct manual starts.)

## Known transitional caveats

1. **Idle monitor-off ("monitors off after 5 min")** keeps working through the
   whole migration: the running hypridle daemon holds the old config (old dpms
   syntax) while the compositor is still legacy — old syntax works. After the
   Lua switch, the old-syntax commands in the daemon's memory are rejected
   until hypridle restarts — hence the optional `pkill hypridle; nohup hypridle
   ... &` one-liner in Phase D (or it self-heals at the next logout/reboot).
2. **Waybar workspace ("tag") clicks are dead under the Lua config — expected,
   no local fix.** Waybar 0.15.0 hardcodes the legacy IPC form
   (`dispatch workspace N`), which the Lua parser rejects
   (`hyprctl dispatch workspace 3` → `')' expected near '3'`). Keyboard
   `mod+1..9` is unaffected (binds never leave Hyprland). Fixed upstream in
   [Waybar#5013](https://github.com/Alexays/Waybar/pull/5013) + [#5231](https://github.com/Alexays/Waybar/issues/5231)
   — released with Waybar 0.16. Self-heals once nixpkgs ships it; verify with
   `waybar --version` ≥ 0.16 and a click. (Scrub this note then.)
3. Bonus: Lua LSP autocompletion stubs for editing `hyprland.lua` in nvim live
   at `/run/current-system/sw/share/hypr/stubs/`.
