# Home-Manager Dotfiles Migration Plan

**Goal:** Migrate all stowed dotfile configurations to home-manager, eliminating the need for a separate `stow` step when setting up a new machine.

**Source:** `~/git/dotfiles/` (stow packages) — READ ONLY, for reference
**Target:** `~/git/nix-setup/nixos/home-manager/config/` — Files must be COPIED here

> ⚠️ **IMPORTANT:** All config files must be copied into the nix-setup repo to make it standalone. The repo should work on a fresh machine clone without requiring access to the dotfiles repo.

**Current config directory contents:**
```
config/
├── kitty/      ✅ already migrated
├── mpv/        ✅ already migrated
├── nvim/       ✅ already migrated
├── starship/   ✅ already migrated
├── tmux/       ✅ already migrated
├── pyradio/    ✅ migrated 2026-03-15
```

---

## Migration Workflow (Per App)

1. **Copy** config files to `config/<app>/`
2. **Update** Nix modules to reference copied files
3. **Cleanup** — unstow + delete existing config files
4. **Verify** — rebuild with `nixos-rebuild switch` and test

---

## Phase 1: Simple xdg.configFile Migrations

These are low-risk, straightforward migrations that just need config files copied and referenced.

### [x] 1.1 yazi (file manager)
**Status:** ✅ Done — using native home-manager module

### [x] 1.2 pyradio (radio player)
**Status:** ✅ Done — config files migrated to home-manager (2026-03-15)

---

### [ ] 1.3 makima (input remapping)
**Status:** Not managed at all (skipped for now)

**Step 1 — Copy config files:**
```bash
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/config/makima
cp ~/git/dotfiles/makima/.config/makima/* /home/kajdo/git/nix-setup/nixos/home-manager/config/makima/
```

**Files to copy:**
- `Gaming KB  Gaming KB .toml` ⚠️ (has spaces in filename)
- `Logitech USB Receiver.toml`
- `Keyboard passthrough.toml`

**Step 2 — Add to `hyprland.nix`:**
```nix
# Makima input remapping configs
xdg.configFile."makima" = {
  source = ./../config/makima;
  recursive = true;
};
```

**Step 3 — Cleanup:**
```bash
stow -D -d ~/git/dotfiles makima
rm -rf ~/.config/makima
```

**Step 4 — Verify:** Rebuild, then check Makima loads configs (device-specific keybindings work)

---

## Phase 2: GTK Theme Configuration

### [x] 2.1 GTK2/GTK3 unified theming
**Status:** ✅ Done — using native home-manager gtk module (2026-03-15)

---

## Phase 3: Native Home-Manager Module Migrations

These use dedicated `programs.*` or `services.*` modules.

### [x] 3.1 rofi (app launcher)
**Status:** ✅ Done — using native home-manager module with extraConfig (2026-03-15)

**Step 1 — Copy config files:**
```bash
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/config/rofi/themes
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/config/rofi/scripts
cp ~/git/dotfiles/rofi/.config/rofi/themes/*.rasi /home/kajdo/git/nix-setup/nixos/home-manager/config/rofi/themes/
cp ~/git/dotfiles/rofi/.config/rofi/scripts/*.sh /home/kajdo/git/nix-setup/nixos/home-manager/config/rofi/scripts/
cp ~/git/dotfiles/rofi/.config/rofi/config.rasi /home/kajdo/git/nix-setup/nixos/home-manager/config/rofi/
cp ~/git/dotfiles/rofi/.config/rofi/powermenu.sh /home/kajdo/git/nix-setup/nixos/home-manager/config/rofi/
```

**Files to copy:**
- `config.rasi` (converted to Nix extraConfig)
- `powermenu.sh`
- `themes/kajdo-mix.rasi` (active theme) + 31 other themes
- `scripts/local-bin-list.sh`

**Step 2 — Update `hyprland.nix`:**
```nix
programs.rofi = {
  enable = true;
  theme = ./../config/rofi/themes/kajdo-mix.rasi;
  extraConfig = {
    show-icons = true;
    icon-theme = "Papirus";
    display-drun = "  ";
    display-window = "﩯 ";
    display-combi = "  ";
  };
};

# Additional rofi themes, scripts, and powermenu
xdg.configFile."rofi/themes" = {
  source = ./../config/rofi/themes;
  recursive = true;
};
xdg.configFile."rofi/scripts" = {
  source = ./../config/rofi/scripts;
  recursive = true;
};
xdg.configFile."rofi/powermenu.sh".source = ./../config/rofi/powermenu.sh;
```

**Note:** Cannot use `xdg.configFile."rofi/config.rasi"` when `programs.rofi.enable = true` (causes conflict). Must use `programs.rofi.theme` and `extraConfig` options instead.

**Step 3 — Cleanup:**
```bash
stow -D -d ~/git/dotfiles rofi
rm -rf ~/.config/rofi
```

**Step 4 — Verify:** ✅ Rebuild successful, rofi uses kajdo-mix.rasi theme with original settings

---

### [x] 3.2 waybar (status bar)
**Status:** ✅ Done — config migrated to home-manager (2026-03-15)

**Step 1 — Copy config files:**
```bash
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/config/waybar
cp ~/git/dotfiles/waybar/.config/waybar/* /home/kajdo/git/nix-setup/nixos/home-manager/config/waybar/
```

**Files to copy:**
- `config.jsonc`
- `style.css`
- `bluetooth.sh`
- `network.sh`

**Step 2 — Update `hyprland.nix`:**
```nix
# Use xdg.configFile (simpler, works with jsonc comments)
xdg.configFile."waybar" = {
  source = ./../config/waybar;
  recursive = true;
};
```

**Note:** `config.jsonc` has JSON with comments — using xdg.configFile instead of programs.waybar

**Step 3 — Cleanup:**
```bash
stow -D -d ~/git/dotfiles waybar
rm -rf ~/.config/waybar
```

**Step 4 — Verify:** ✅ Rebuild successful, waybar displays with correct modules and styling

---

### [x] 3.3 dunst (notification daemon)
**Status:** ✅ Done — config migrated to home-manager (2026-03-15)

**Step 1 — Copy config files:**
```bash
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/config/dunst
cp ~/git/dotfiles/dunst/.config/dunst/dunstrc /home/kajdo/git/nix-setup/nixos/home-manager/config/dunst/
```

**Files to copy:**
- `dunstrc`

**Step 2 — Update `hyprland.nix`:**
```nix
services.dunst = {
  enable = true;
};

xdg.configFile."dunst/dunstrc".source = ./../config/dunst/dunstrc;
```

**Step 3 — Cleanup:**
```bash
stow -D -d ~/git/dotfiles dunst
rm -rf ~/.config/dunst
```

**Step 4 — Verify:** Rebuild, notifications appear with correct styling

---

### [ ] 3.4 bash (shell)
**Status:** Not managed, but `.bashrc` and `.bash_aliases` exist in dotfiles

**Step 1 — Copy config files:**
```bash
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/config/bash
cp ~/git/dotfiles/bash/.bashrc /home/kajdo/git/nix-setup/nixos/home-manager/config/bash/
cp ~/git/dotfiles/bash/.bash_aliases /home/kajdo/git/nix-setup/nixos/home-manager/config/bash/
cp ~/git/dotfiles/bash/.bash_profile /home/kajdo/git/nix-setup/nixos/home-manager/config/bash/
```

**Files to copy:**
- `.bashrc`
- `.bash_aliases`
- `.bash_profile`

**Step 2 — Create `home-manager/modules/shell.nix`:**
```nix
{ config, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    
    # TODO: Extract aliases from .bash_aliases into this attrset
    shellAliases = {
      ll = "ls -la";
      # ... extract more
    };
    
    bashrcExtra = builtins.readFile ./../config/bash/.bashrc;
    profileExtra = builtins.readFile ./../config/bash/.bash_profile;
  };
}
```

**Note:** Requires careful extraction of aliases — may need to split .bashrc content

**Step 3 — Cleanup:**
```bash
stow -D -d ~/git/dotfiles bash
rm ~/.bashrc ~/.bash_aliases ~/.bash_profile
```

**⚠️ WARNING:** Bash config removal can break your shell session. Consider:
- Running cleanup in a fresh terminal after rebuild
- Or keeping backup copies and removing manually after verifying new config works

**Step 4 — Verify:** Rebuild, shell has correct aliases, PATH, functions

---

## Phase 4: Script Migrations (Optional)

These are utility scripts that could be migrated but may be lower priority.

### [ ] 4.1 git_scripts → home.file
**Status:** Currently stowed

**Step 1 — Copy scripts:**
```bash
mkdir -p /home/kajdo/git/nix-setup/nixos/home-manager/scripts
cp ~/git/dotfiles/git_scripts/.local/bin/* /home/kajdo/git/nix-setup/nixos/home-manager/scripts/
```

**Files:**
- `show_git_url`
- `merge_feature`
- `rollback_git`
- `create_feature`
- `git_list_orphants`

**Step 2 — Add to a module:**
```nix
home.file.".local/bin/show_git_url".source = ./../scripts/show_git_url;
home.file.".local/bin/merge_feature".source = ./../scripts/merge_feature;
# etc.
```

**Step 3 — Cleanup:**
```bash
stow -D -d ~/git/dotfiles git_scripts
rm ~/.local/bin/show_git_url ~/.local/bin/merge_feature ~/.local/bin/rollback_git ~/.local/bin/create_feature ~/.local/bin/git_list_orphants
```

**Step 4 — Verify:** Rebuild, scripts work from `~/.local/bin/`

**Priority:** Low — these work fine stowed

---

### [ ] 4.2 nix-scripts → home.file
**Status:** Currently stowed

**Files:**
- `nix-deepclean`
- `find_codium`
- `lush`
- `lull`
- `strip_emojis.py`

**Priority:** Low

---

### [ ] 4.3 x-desktop-scripts → home.file
**Status:** Currently stowed

**Files:**
- `brightness_down`, `volume_down`
- `scratch_kitty`
- `set_random_wallpaper.sh`
- `sus`

**Priority:** Low — X11 specific, you're on Wayland now

---

## Phase 5: Final Cleanup & Verification

### [ ] 5.1 Final machine setup test
On a fresh machine (or VM):
```bash
git clone <nix-setup-repo>
cd nix-setup/nixos
sudo nixos-rebuild switch --flake .#hostname
# Verify all configs present WITHOUT stow step
```

### [ ] 5.2 Update documentation
- Update README with new setup process
- Document which configs are managed where
- Remove or archive dotfiles repo reference

---

## Migration Order (Recommended)

| Order | App | Effort | Status |
|-------|-----|--------|--------|
| 1 | **yazi** | Low | ✅ Done |
| 2 | **pyradio** | Low | ✅ Done |
| 3 | **makima** | Low | ⬜ Skipped |
| 4 | **GTK** | Medium | ✅ Done |
| 5 | **rofi** | Medium | ✅ Done |
| 6 | **waybar** | Medium | ✅ Done |
| 7 | **dunst** | Low | ✅ Done |
| 8 | **bash** | High | ⬜ Pending |
| — | **scripts** | Optional | ⬜ Low priority |

---

## Notes

- **Copy first, then modify:** Always copy files to `config/` before updating Nix modules
- **Cleanup BEFORE rebuild:** Unstow and delete existing configs before verifying with rebuild
- **Git commit per app:** One commit per migration for easy rollback
- **Backups:** Dotfiles repo is the backup — don't delete until verified
- **Rollback:** `sudo nixos-rebuild switch --rollback` if something breaks
- **Spaces in filenames:** Makima configs have spaces — test git handles them correctly

---

## Progress Tracking

| Phase | Task | Status | Date |
|-------|------|--------|------|
| 1.1 | yazi | ✅ Done | |
| 1.2 | pyradio | ✅ Done | 2026-03-15 |
| 1.3 | makima | ⬜ Skipped | |
| 2.1 | GTK theming | ✅ Done | 2026-03-15 |
| 3.1 | rofi | ✅ Done | 2026-03-15 |
| 3.2 | waybar | ✅ Done | 2026-03-15 |
| 3.3 | dunst | ✅ Done | 2026-03-15 |
| 3.4 | bash | ⬜ Pending | |
| 4.x | scripts (optional) | ⬜ Pending | |
| 5.x | final cleanup | ⬜ Pending | |

Status legend: ⬜ Not started | ✅ Done | ❌ Blocked

---

## Directory Structure After Migration

```
nixos/home-manager/
├── config/
│   ├── kitty/          ✅ existing
│   ├── mpv/            ✅ existing
│   ├── nvim/           ✅ existing
│   ├── starship/       ✅ existing
│   ├── tmux/           ✅ existing
│   ├── pyradio/        ✅ done
│   ├── makima/         ⬜ pending
│   ├── rofi/           ✅ done
│   ├── waybar/         ✅ done
│   ├── dunst/          ✅ done
│   └── bash/           ⬜ pending
├── modules/
│   ├── cli-utils.nix
│   ├── desktop-apps.nix
│   ├── dev-tools.nix
│   ├── hyprland.nix
│   ├── media-apps.nix
│   ├── gtk-theming.nix ✅ done
│   └── shell.nix       ⬜ pending
└── home.nix
```
