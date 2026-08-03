# Restic Backup (depot)

Automatic, encrypted backups of `~/Nextcloud/clean_depot` to the remote host
`nvmeberry` over SFTP, via [restic](https://restic.readthedocs.io). Runs as a
systemd **user** timer (as `kajdo`), so it reuses the existing SSH cert auth —
no separate root key needed.

| | |
|---|---|
| **Source** | `~/Nextcloud/clean_depot` |
| **Target** | `sftp:nvmeberry:/home/kajdo/BACKUP/depot` |
| **Schedule** | daily, `Persistent=true` (catches up after suspend/offline) |
| **Retention** | 7 daily · 4 weekly · 6 monthly |
| **Runs as** | user `kajdo` (Home Manager `services.restic`) |
| **Secret** | `~/.config/restic/depot.pwd` (mode 0600, **not** in this repo / Nix store) |

> **Don't lose `~/.config/restic/depot.pwd`.** It is the only key that decrypts
> the backups. Back it up somewhere outside this machine (password manager,
> paper, …). Without it the backups are unrecoverable.

## How it works

- A systemd user unit `restic-backups-depot.service` runs: `init` (if needed) →
  `backup` → `unlock` → `forget --prune` → `check`.
- The matching timer `restic-backups-depot.timer` fires daily.
- The `restic-depot` wrapper (same repo + password as the timer) is on `PATH`
  for all manual commands below.
- `Linger=yes` on the user means the timer fires even when logged out.

## Checking status

```bash
systemctl --user list-timers  restic-backups-depot.timer   # next run
systemctl --user status       restic-backups-depot.service  # last run
journalctl --user -u restic-backups-depot.service -b        # logs
restic-depot snapshots                                        # what's stored
restic-depot stats                                            # sizes
```

## Restoring

### Method A — browse via FUSE mount (grab a few files)

```bash
mkdir -p /tmp/rmnt
restic-depot mount /tmp/rmnt        # blocks this terminal; open another
```

Browse the read-only tree and copy out what you need:

```
/tmp/rmnt/
├── snapshots/<timestamp>/…         # every snapshot
├── snapshots/latest/…              # newest
├── hosts/nixos/…                   # by host
└── ids/<snapshot-id>/…             # by ID
```

```bash
cp /tmp/rmnt/snapshots/latest/home/kajdo/Nextcloud/clean_depot/div/file.txt ~/
fusermount -u /tmp/rmnt && rmdir /tmp/rmnt   # unmount when done
```

### Method B — restore a whole snapshot to a temp dir (safe)

```bash
restic-depot snapshots                                   # pick an ID, or use 'latest'
restic-depot restore latest --target /tmp/restore        # → /tmp/restore/home/kajdo/Nextcloud/clean_depot/…
```

> **Path gotcha:** restic recreates the original absolute path under `--target`.

### Restore a subtree / single file

```bash
restic-depot restore latest --target /tmp/restore \
  --include '/home/kajdo/Nextcloud/clean_depot/div/**'
```

### Restore in place (overwrite — use with care)

```bash
restic-depot restore latest --target / \
  --include '/home/kajdo/Nextcloud/clean_depot/**' --dry-run   # inspect first, then drop --dry-run
```

## Manual operations

| Task | Command |
|------|---------|
| List snapshots | `restic-depot snapshots` (add `--compact`) |
| Repo stats | `restic-depot stats` |
| Find which snapshot has a file | `restic-depot find '*.pdf'` |
| Compare two snapshots | `restic-depot diff <id1> <id2>` |
| Trigger a backup now | `systemctl --user start restic-backups-depot.service` |
| Delete one snapshot | `restic-depot forget <id> --prune` |

## Changing the configuration

Edit `home-manager/modules/backup.nix` (paths, retention, schedule) and rebuild:

```bash
sudo nixos-rebuild switch   # alias: lull   (Home Manager is integrated)
```

To back up an additional directory, either add it to `paths`, or add a second
job under a new name, e.g. `services.restic.backups.docs = { … }` (each job gets
its own `restic-<name>` wrapper and timer).

## Files

- Backup job: `home-manager/modules/backup.nix`
- Linger (unattended user timers): `nixos-modules/core/users.nix`
- Imported in: `home.nix`
- Password (local, untracked): `~/.config/restic/depot.pwd`
