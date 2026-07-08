# Stale Files Problem

## Background

The Neovim configuration is deployed via Home Manager's `xdg.configFile` mechanism:

```nix
xdg.configFile."nvim" = {
  source = ./../config/nvim;
  recursive = true;
};
```

This creates symlinks in `~/.config/nvim/` pointing to files in the Nix store (e.g. `/nix/store/<hash>-home-manager-files/.config/nvim/init.lua`).

## The Problem

When files are **deleted** from the source directory (`./../config/nvim/`), they **persist** in two places:

### 1. Build source (`/etc/nixos/`)

The deployment script (`lull`) uses `cp -r` to copy the repo state to `/etc/nixos/`:

```bash
sudo cp -r /home/kajdo/git/nix-setup/nixos /etc
```

`cp -r` is **additive** — it overwrites changed files but does **not** delete files that no longer exist in the source. So if `noice.lua` was deleted from the repo, the old copy in `/etc/nixos/home-manager/config/nvim/lua/.../` stays there permanently.

### 2. Deployed target (`~/.config/nvim/`)

`xdg.configFile` with `recursive = true` is also **additive** — it ensures files from the Nix store are present, but does **not** clean up files that are no longer in the store path. Renamed/moved directories (e.g. `lua/custom/plugins/` → `lua/plugins/`) leave behind stale directories with old content.

### 3. Lazy.nvim cache (`~/.local/share/nvim/lazy/`)

Even after files are correctly deployed, lazy.nvim has its own cache of installed plugins. Deleted plugin specs don't trigger automatic cleanup of the corresponding packages. Running `:Lazy clean` is required.

## Impact

- Deleted plugins continue to load (e.g. noice.nvim, vim-dadbod)
- Plugin specs that should be gone are still evaluated
- Confusing diffs between what the repo says and what actually runs
- Requires manual cleanup after every set of file deletions

## The Fix

Add a clean-up step before copying in the `lull` script:

```bash
sudo rm -rf /etc/nixos
sudo cp -r nixos /etc
```

This is safe because the running system is defined by the activated Nix store path (`/run/current-system`), not by the files in `/etc/nixos/`. The directory is only the **source input** for the next rebuild.

For `~/.config/nvim/` — any files there that aren't symlinked to the Nix store are stale and can be removed.

For lazy.nvim — `:Lazy clean` after deployment purges cached plugins whose specs no longer exist.

## Files Affected by This Issue (as of Jul 2026)

These files were deleted from the repo but persisted in deployed configs:

- `lua/custom/plugins/*.lua` (all ~23 old plugin specs)
- `lua/kickstart/` (entire directory)
- `doc/kickstart.txt`
- `LICENSE.md`
- `README.md`
- `todo.md`
- `lazy-lock.json`
- `nix_init_blank.lua`
