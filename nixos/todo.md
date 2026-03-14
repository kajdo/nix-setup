# NixOS Configuration Cleanup Tasks

*Generated: 2026-03-13 • Updated: 2026-03-14*

---

## Priority 1: Quick Wins (Low Effort, High Impact)

### 1.1 Remove Dead/Commented Code
- [x] `nixos-modules/system-packages.nix:37` — Remove `# virtualisation.libguestfs.enable = true;`
- [x] `home-manager/modules/mcfly.nix:12` — Remove `# fzf.enable = true;`

### 1.2 Resolve Package Conflicts

- [x] **Remove `vim` from system-packages.nix** (line 44)
  - Reason: Using `neovim` from home-manager — use `sudoedit` instead of `sudo vim`
  
- [x] **Remove `wget` from system-packages.nix** (line 47)
  - Reason: `wget2` already in home-manager/modules/dev-tools.nix

- [x] **Remove `pulseaudioFull` from system-packages.nix** (line 52)
  - Reason: Conflicts with `services.pipewire.pulse.enable = true` in audio.nix
  - PipeWire provides PulseAudio compatibility

### 1.3 Move User Session Variables to Home Manager

- [x] **Move PATH to home.sessionPath** (added to home.nix)
  - Hyprland now has `env = PATH,$PATH:$HOME/.local/bin` as fallback
  - `home.sessionPath` sets `~/.local/bin` and `~/.npm-global/bin`

---

## Priority 2: Medium Effort

### 2.1 Move Packages from System to Home Manager

- [x] **Move `lua`** to `home-manager/modules/dev-tools.nix`
  - Added to Lua tooling section

- [x] **Keep `toybox` at system level**
  - Reason: Conflicts with gcc-wrapper (readelf) when in home-manager

- [x] **Move `unzip`** to `home-manager/modules/cli-utils.nix`
  - Reason: CLI utility, user-specific

- [x] **Move `curl`** to `home-manager/modules/dev-tools.nix`
  - Added to General utilities section alongside wget2

- [x] **Move `appimage-run`** to home-manager
  - Moved to: `home-manager/modules/cli-utils.nix`
  - Reason: User utility for running appimages

- [x] **Move `dunst`** to `home-manager/modules/wayland.nix`
  - Reason: User-level notification daemon for Wayland

- [x] **Move `networkmanagerapplet`** to home-manager
  - Moved to: `home-manager/modules/wayland.nix`
  - Reason: GUI applet, user-specific, Hyprland-related

- [x] **Move `papirus-icon-theme`** to `home-manager/modules/theming.nix`
  - Reason: User theming preference

- [x] **Move `gnome-themes-extra`** to `home-manager/modules/theming.nix`
  - Reason: User theming preference

### 2.2 Move GTK Environment Variables to Home Manager

- [x] **Move GTK_THEME and GTK_ICON_THEME** from system to home-manager
  - Created `home-manager/modules/theming.nix` with `home.sessionVariables`

### 2.3 Move LIBVA_DRIVER_NAME to Home Manager

- [x] **Move session variable** from `graphics.nix:18` to home-manager
  - Moved to: `home-manager/modules/wayland.nix`
  - Value: `LIBVA_DRIVER_NAME = "iHD"`

---

## Priority 3: High Effort (Refactoring)

### 3.1 Split `system-packages.nix` into Focused Modules

The current file mixes 7 concerns. Split into:

- [x] **Create `nixos-modules/virtualization.nix`**
  - Move: docker, libvirtd, spiceUSBRedirection, virt-manager, libvirtd group membership
  ```nix
  { config, pkgs, ... }:
  {
    virtualisation.docker.enable = true;
    virtualisation.libvirtd.enable = true;
    virtualisation.spiceUSBRedirection.enable = true;
    programs.virt-manager.enable = true;
    users.groups.libvirtd.members = ["kajdo"];
  }
  ```

- [x] **Create `nixos-modules/desktop-services.nix`**
  - Move: printing, avahi, gvfs, udisks2, tumbler
  ```nix
  { config, pkgs, ... }:
  {
    services.printing.enable = true;
    services.avahi.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.tumbler.enable = true;
  }
  ```

- [x] **Create `nixos-modules/desktop-programs.nix`**
  - Move: appimage, localsend, firefox, thunar
  ```nix
  { config, pkgs, ... }:
  {
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;
    programs.localsend.enable = true;
    programs.localsend.openFirewall = true;
    programs.firefox.enable = true;
    programs.thunar.enable = true;
    programs.thunar.plugins = with pkgs; [
      thunar-volman
      thunar-archive-plugin 
    ];
  }
  ```

- [x] **Update `configuration.nix` imports**
  - Add new modules to import list

### 3.2 Consolidate Home Manager Modules

**26 of 43 modules are under 10 lines.** Consider consolidating:

- [x] **Merge Wayland screenshot tools into `wayland.nix`**
  - Files to merge: grim.nix, slurp.nix, swappy.nix, wl-clipboard.nix, wl-clip-persist.nix, ueberzugpp.nix
  - Result: All Wayland tools in one place

- [ ] **Expand `cli-utils.nix`** (optional - file already exists with unzip)
  - Could combine: bat, btop, cava, cmatrix, fastfetch, fzf, lsd, ncdu, tree, tty-clock, stow, zoxide
  - Note: Some use `programs.*` options, so verify compatibility

- [ ] **Create `media-apps.nix`** (optional)
  - Combine: glow, moonlight, mpv, obsidian, peazip, portfolio, pyradio

### 3.3 Rename Misleading Files

- [x] **Rename `user-packages.nix` → `users.nix`**
  - File defines user account, not just packages
  - Update import in `configuration.nix`

- [x] **Rename `development.nix` → `nix.nix`**
  - Contains nix.settings, nixpkgs.config, stateVersion
  - Update import in `configuration.nix`

---

## Priority 4: Formatting & Consistency

### 4.1 Standardize Home Manager Module Format

- [ ] **Standardize import parameters** to `{ config, pkgs, ... }:`
  - Files using `{ pkgs, ... }:`: kitty, libreoffice, mpv, signal, wayland, starship

- [ ] **Standardize blank line after opening brace**
  - Decide on convention and apply consistently

### 4.2 Organize Imports Alphabetically

- [ ] **Verify `home.nix` imports are alphabetically sorted** ✓ (already done)
- [ ] **Group `configuration.nix` imports logically**
  - Suggested order: boot → core (networking, localization) → hardware (graphics, audio, bluetooth, power) → desktop (display, flatpak) → packages (fonts, development) → users

---

## Packages to Keep at System Level

These should remain in `system-packages.nix`:

| Package | Reason |
|---------|--------|
| `evtest` | Requires system access for input testing |
| `toybox` | Conflicts with gcc-wrapper (readelf) when in home-manager |
| `gtk3` | System theming library |
| `gtk-engine-murrine` | System GTK theme engine |
| `gtk_engines` | System GTK engines |
| `adwaita-icon-theme` | System icon theme |
| `libnotify` | System notification library |
| `mesa` | System GPU drivers |

---

## Summary

| Priority | Tasks | Completed | Remaining |
|----------|-------|-----------|-----------|
| 1 - Quick Wins | 7 | 7 | 0 |
| 2 - Medium | 11 | 11 | 0 |
| 3 - High (Refactor) | 10 | 7 | 3 |
| 4 - Formatting | 4 | 1 | 3 |

**Total: 32 tasks, 26 completed, 6 remaining**

---

## Notes

- Test after each change: `sudo nixos-rebuild switch --flake .#nixos`
- Keep this file updated as tasks are completed
- Consider committing changes incrementally for easier rollback
