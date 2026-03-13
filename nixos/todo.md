# NixOS Configuration Cleanup Tasks

*Generated: 2026-03-13*

---

## Priority 1: Quick Wins (Low Effort, High Impact)

### 1.1 Remove Dead/Commented Code
- [ ] `nixos-modules/system-packages.nix:37` — Remove `# virtualisation.libguestfs.enable = true;`
- [ ] `home-manager/modules/mcfly.nix:12` — Remove `# fzf.enable = true;`

### 1.2 Resolve Package Conflicts

- [ ] **Remove `vim` from system-packages.nix** (line 44)
  - Reason: Using `neovim` from home-manager — no need for both
  
- [ ] **Remove `wget` from system-packages.nix** (line 47)
  - Reason: `wget2` already in home-manager/modules/dev-tools.nix

- [ ] **Remove `pulseaudioFull` from system-packages.nix** (line 52)
  - Reason: Conflicts with `services.pipewire.pulse.enable = true` in audio.nix
  - PipeWire provides PulseAudio compatibility

### 1.3 Move User Session Variables to Home Manager

- [ ] **Move PATH configuration** from `system-packages.nix:80-83` to home-manager
  ```nix
  # Current (system-packages.nix):
  PATH = [
    "/home/kajdo/.local/bin"
    "/home/kajdo/.npm-global/bin"
  ];
  ```
  - Create or update a shell module in home-manager with:
  ```nix
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];
  ```

---

## Priority 2: Medium Effort

### 2.1 Move Packages from System to Home Manager

- [ ] **Move `lua`** to `home-manager/modules/dev-tools.nix`
  - Current: `nixos-modules/system-packages.nix:48`
  - Reason: Development tool, user-specific

- [ ] **Move `toybox`** to new `home-manager/modules/cli-utils.nix` (or create)
  - Current: `nixos-modules/system-packages.nix:47`
  - Reason: CLI utilities, user-specific

- [ ] **Move `unzip`** to new `home-manager/modules/cli-utils.nix`
  - Current: `nixos-modules/system-packages.nix:49`
  - Reason: CLI utility, user-specific

- [ ] **Move `curl`** to `home-manager/modules/dev-tools.nix`
  - Current: `nixos-modules/system-packages.nix:67`
  - Reason: Already have wget2 in dev-tools

- [ ] **Move `appimage-run`** to home-manager
  - Current: `nixos-modules/system-packages.nix:70`
  - Reason: User utility for running appimages

- [ ] **Move `dunst`** to new `home-manager/modules/notifications.nix`
  - Current: `nixos-modules/system-packages.nix:62`
  - Reason: User-level notification daemon

- [ ] **Move `networkmanagerapplet`** to home-manager
  - Current: `nixos-modules/system-packages.nix:50`
  - Reason: GUI applet, user-specific

- [ ] **Move `papirus-icon-theme`** to new `home-manager/modules/theming.nix`
  - Current: `nixos-modules/system-packages.nix:58`
  - Reason: User theming preference

- [ ] **Move `gnome-themes-extra`** to `home-manager/modules/theming.nix`
  - Current: `nixos-modules/system-packages.nix:59`
  - Reason: User theming preference

### 2.2 Move GTK Environment Variables to Home Manager

- [ ] **Move GTK_THEME and GTK_ICON_THEME** from system to home-manager
  - Current: `system-packages.nix:74-77`
  - Create `home-manager/modules/gtk.nix`:
  ```nix
  { config, pkgs, ... }:
  {
    home.sessionVariables = {
      GTK_THEME = "Adwaita";
      GTK_ICON_THEME = "Adwaita";
    };
  }
  ```

### 2.3 Move LIBVA_DRIVER_NAME to Home Manager

- [ ] **Move session variable** from `graphics.nix:18` to home-manager
  - Current: `environment.sessionVariables.LIBVA_DRIVER_NAME = "i965";`
  - Add to `home-manager/modules/wayland.nix` or create graphics module

---

## Priority 3: High Effort (Refactoring)

### 3.1 Split `system-packages.nix` into Focused Modules

The current file mixes 7 concerns. Split into:

- [ ] **Create `nixos-modules/virtualization.nix`**
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

- [ ] **Create `nixos-modules/desktop-services.nix`**
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

- [ ] **Create `nixos-modules/desktop-programs.nix`**
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

- [ ] **Update `configuration.nix` imports**
  - Add new modules to import list

### 3.2 Consolidate Home Manager Modules

**26 of 43 modules are under 10 lines.** Consider consolidating:

- [ ] **Merge Wayland screenshot tools into `wayland.nix`**
  - Files to merge: grim.nix, slurp.nix, swappy.nix, wl-clipboard.nix, wl-clip-persist.nix, ueberzugpp.nix
  - Result: All Wayland tools in one place

- [ ] **Create `cli-utils.nix`** (optional alternative to individual files)
  - Combine: bat, btop, cava, cmatrix, fastfetch, fzf, lsd, ncdu, tree, tty-clock, stow, zoxide
  - Note: Some use `programs.*` options, so verify compatibility

- [ ] **Create `media-apps.nix`** (optional)
  - Combine: glow, moonlight, mpv, obsidian, peazip, portfolio, pyradio

### 3.3 Rename Misleading Files

- [ ] **Rename `user-packages.nix` → `users.nix`**
  - File defines user account, not just packages
  - Update import in `configuration.nix`

- [ ] **Rename `development.nix` → `nix.nix`**
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
| `gtk3` | System theming library |
| `gtk-engine-murrine` | System GTK theme engine |
| `gtk_engines` | System GTK engines |
| `adwaita-icon-theme` | System icon theme |
| `libnotify` | System notification library |
| `mesa` | System GPU drivers |

---

## Summary

| Priority | Tasks | Effort |
|----------|-------|--------|
| 1 - Quick Wins | 7 | ~30 min |
| 2 - Medium | 12 | ~2 hours |
| 3 - High (Refactor) | 10 | ~4 hours |
| 4 - Formatting | 4 | ~30 min |

**Total: 33 tasks**

---

## Notes

- Test after each change: `sudo nixos-rebuild switch --flake .#nixos`
- Keep this file updated as tasks are completed
- Consider committing changes incrementally for easier rollback
